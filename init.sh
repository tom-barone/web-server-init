set -ex

DOKKU_VERSION=v0.35.15

# Environment variable checks
for var in HOSTNAME DOMAIN EMAIL GMAIL_USERNAME GMAIL_PASSWORD MONITORING_USERNAME MONITORING_PASSWORD; do
	if [ -z "${!var}" ]; then
		echo "$var environment variable must be set"
		exit 1
	fi
done

sudo hostnamectl set-hostname "$HOSTNAME"
sudo cat "127.0.0.1 $HOSTNAME" | sudo tee -a /etc/hosts
sudo apt update

## SSH

# Backup the sshd_config
sudo cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.$(date +%Y%m%d%H%M%S).bak"
# Turn off password authentication for SSH
sudo sed -i 's/.*PasswordAuthentication yes.*/PasswordAuthentication no/g' /etc/ssh/sshd_config
# Don't allow root to login via SSH
# sudo sed -i 's/.*PermitRootLogin.*/PermitRootLogin no/g' /etc/ssh/sshd_config
sudo service ssh restart

## Fail2Ban

sudo apt install fail2ban whois -y
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
# Enable the SSH jail
sudo sed -i 's/^\[sshd\]/\[sshd\]\nenabled = true/g' /etc/fail2ban/jail.local
# Set ban length to 48 hours
sudo sed -i 's/^bantime  = 10m/bantime = 48h/g' /etc/fail2ban/jail.local
sudo service fail2ban restart
# Check status with
# $ sudo fail2ban-client status sshd
# $ sudo tail -n 100 /var/log/auth.log
# $ sudo tail -n 100 /var/log/fail2ban.log
# Unban IP with
# sudo fail2ban-client set sshd unbanip <ip-address>

## Unattended Upgrades

sudo apt install -y unattended-upgrades apt-listchanges
sudo echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | sudo debconf-set-selections
sudo dpkg-reconfigure -f noninteractive unattended-upgrades
sudo systemctl enable unattended-upgrades
sudo systemctl start unattended-upgrades
# Check recent upgrades with
# $ sudo tail -n 100 /var/log/dpkg.log
# Confirm the next upgrade with
# $ sudo unattended-upgrades --dry-run --debug
# Check the settings are set
# $ sudo cat /etc/apt/apt.conf.d/20auto-upgrades

## Dokku

# https://dokku.com/docs/getting-started/installation/
wget -NP . "https://dokku.com/install/$DOKKU_VERSION/bootstrap.sh"
sudo "DOKKU_TAG=$DOKKU_VERSION" bash bootstrap.sh
# Test we can run a container
docker run hello-world
sudo cat "$HOME/.ssh/authorized_keys" | sudo dokku ssh-keys:add admin
dokku domains:set-global "$DOMAIN"
# Dokku plugins
sudo dokku plugin:install https://github.com/dokku/dokku-postgres.git
sudo dokku plugin:install https://github.com/dokku/dokku-redis
sudo dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
sudo dokku plugin:install https://github.com/dokku/dokku-http-auth.git
sudo dokku plugin:install https://github.com/dokku/dokku-graphite.git --name graphite
sudo dokku plugin:install https://github.com/dokku/dokku-cron-restart.git
dokku letsencrypt:set --global email "$EMAIL"
dokku letsencrypt:cron-job --add
# Tell logrotate to act as the dokku user.
sudo tee /etc/logrotate.d/dokku <<EOF
/var/log/dokku/*.log {
				su root dokku
				daily
				missingok
				rotate 7
				compress
				delaycompress
				notifempty
				copytruncate
}
EOF
# Setup log rotation for apps that put their logs in /var/log/dokku/apps
sudo tee /etc/logrotate.d/dokku-apps <<EOF
/var/log/dokku/apps/*.log {
				su root dokku
				daily
				missingok
				rotate 14
				compress
				delaycompress
				notifempty
				copytruncate
}
EOF
# Create a user and SSH key for Github to use when deploying
sudo adduser --disabled-password --gecos "" github
sudo usermod -aG sudo github
sudo -i -u github bash <<EOF
cd ~
rm -f ~/.ssh/github_deploy_key*
ssh-keygen -t ed25519 -C "Github Deploy Key" -f ~/.ssh/github_deploy_key -N "" -q
cat ~/.ssh/github_deploy_key.pub >> ~/.ssh/authorized_keys
EOF
sudo dokku ssh-keys:add github /home/github/.ssh/github_deploy_key.pub
# Start the vector logging service
dokku logs:vector-start

## Some utility tools

# LSHW to see hardware specs [https://ezix.org/project/wiki/HardwareLiSter]
sudo apt -y install lshw
# BTM to view processes [https://github.com/ClementTsang/bottom]
curl -LO https://github.com/ClementTsang/bottom/releases/download/0.10.2/bottom_0.10.2-1_amd64.deb
sudo dpkg -i bottom_0.10.2-1_amd64.deb
rm bottom_0.10.2-1_amd64.deb
# iftop to see how much traffic is going through the network interfaces
sudo apt -y install iftop

## Logcheck

sudo apt install -y logcheck
# The default logcheck should send emails to root, which we've aliased to our email address
sudo cp /etc/logcheck/logcheck.conf /etc/logcheck/logcheck.conf.bak
# Print recent logs to stdout with and don't update the pointer
# $ sudo -u logcheck logcheck -o -t
# Send email to root user (and therefore us) with:
# $ sudo -u logcheck logcheck
# To add some random logs that will flag, you can do
# $ sudo -k && sudo doesnotexist
# 	- and fail the password prompt

## Postfix

# Install Postfix and SASL
sudo apt install -y libsasl2-modules postfix
# Choose:
# - Internet Site
# - System mail name: <default>
# Add the Gmail credentials
sudo tee /etc/postfix/sasl/sasl_passwd <<EOF
[smtp.gmail.com]:587 $GMAIL_USERNAME:$GMAIL_PASSWORD
EOF
sudo postmap /etc/postfix/sasl/sasl_passwd
sudo chown root:root /etc/postfix/sasl/sasl_passwd /etc/postfix/sasl/sasl_passwd.db
sudo chmod 0600 /etc/postfix/sasl/sasl_passwd /etc/postfix/sasl/sasl_passwd.db
sudo cp /etc/postfix/main.cf /etc/postfix/main.cf.bak
sudo sed -i "s/^myhostname.*/myhostname = $HOSTNAME/g" /etc/postfix/main.cf
sudo sed -i 's/^relayhost = $/relayhost = [smtp.gmail.com]:587/g' /etc/postfix/main.cf
# Disable smtp_tls_security_level=may
sudo sed -i 's/^smtp_tls_security_level=may/#smtp_tls_security_level=may/g' /etc/postfix/main.cf
# NOTE: You might need to set inet_protocols = ipv4 if the machine doesn't support ipv6
# 			Can happen if running a server from a home network for example.
sudo tee -a /etc/postfix/main.cf <<EOF
# Enable SASL authentication
smtp_sasl_auth_enable = yes
# Disallow methods that allow anonymous authentication
smtp_sasl_security_options = noanonymous
# Location of sasl_passwd
smtp_sasl_password_maps = hash:/etc/postfix/sasl/sasl_passwd
# Enable STARTTLS encryption
smtp_tls_security_level = encrypt
# Location of CA certificates
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
EOF
sudo apt install -y mailutils
# Comment out any existing root alias
sudo sed -i 's/^root.*/#root/g' /etc/aliases
# Set email address forwarding for root emails
sudo tee -a /etc/aliases <<EOF
root: $EMAIL
EOF
sudo postconf -e "alias_maps = hash:/etc/aliases"
sudo newaliases
sudo systemctl restart postfix
# Test we can send mail from postfix
# $ sudo sendmail <TO_ADDRESS>
# $ From: <FROM_ADDRESS>
# $ Subject: Test mail
# $ This is a test email
# $ .
# Test we can send mail to the root user
# $ sudo sendmail root
# $ From: <FROM_ADDRESS>
# $ Subject: Test root mail
# $ This is a test email to the root user
# $ .

# Graphite / Statsd / Grafana
# By default this will retain metrics for the last 7 days
dokku graphite:create graphite --custom-env "GF_SECURITY_ADMIN_USER=$MONITORING_USERNAME;GF_SECURITY_ADMIN_PASSWORD=$MONITORING_PASSWORD;GF_SMTP_ENABLED=true;GF_SMTP_HOST=smtp.gmail.com:587;GF_SMTP_USER=$GMAIL_USERNAME;GF_SMTP_PASSWORD=$GMAIL_PASSWORD;GF_SMTP_FROM_NAME=GrafanaAlerts"
dokku graphite:expose graphite 8125 8126 8084 8081 2003
dokku apps:create "monitoring.$DOMAIN"
dokku config:set --no-restart "monitoring.$DOMAIN" SERVICE_NAME=graphite SERVICE_TYPE=graphite SERVICE_PORT=80
dokku graphite:link graphite "monitoring.$DOMAIN"
dokku git:from-image "monitoring.$DOMAIN" dokku/service-proxy:latest
dokku letsencrypt:enable "monitoring.$DOMAIN"
# Print the storage schema / retention policy for carbon
dokku graphite:enter graphite cat /opt/graphite/conf/storage-schemas.conf
#
# If there's an issue with starting / stopping / restarting the graphite or graphite.ambassador images
# you can try removing the docker images and starting again
#
# $ docker ps -a
# $ docker rm <container_id>
#
## Test we can push to graphite with
# echo "foo.bar 1 `date +%s`" | nc localhost 2003
## Make sure grafana datasource for graphite is set to http://localhost:81
sudo apt-get install -y collectd
sudo tee /etc/collectd/collectd.conf.d/graphite.conf <<EOF
LoadPlugin write_graphite
<Plugin write_graphite>
  <Node "local">
    Host "localhost"
    Port "2003"
    Prefix "collectd-"
  </Node>
</Plugin>
EOF
sudo systemctl restart collectd

# cAdvisor
dokku apps:create cadvisor
dokku graphite:link graphite cadvisor
dokku docker-options:add cadvisor deploy "--privileged"
dokku docker-options:add cadvisor deploy "--device=/dev/kmsg"
dokku config:set --no-restart cadvisor DOKKU_DOCKERFILE_START_CMD="--storage_driver=statsd --storage_driver_host=dokku-graphite-graphite:8125 --port 8082"
dokku storage:mount cadvisor /:/rootfs:ro
dokku storage:mount cadvisor /var/run:/var/run:ro
dokku storage:mount cadvisor /sys:/sys:ro
dokku storage:mount cadvisor /var/lib/docker:/var/lib/docker:ro
dokku storage:mount cadvisor /dev/disk:/dev/disk:ro
docker image pull gcr.io/cadvisor/cadvisor:v0.49.1
dokku git:from-image cadvisor gcr.io/cadvisor/cadvisor:v0.49.1
# When a Dokku app is deployed, cadvisor loses track of the container metrics and needs to be restarted
# This cron job will restart cadvisor every day at 3am, which is a bit of a hack to correct this
# A better solution is to have cadvisor restart automatically when a new container is deployed
dokku cron-restart:set cadvisor schedule '0 3 * * *'
