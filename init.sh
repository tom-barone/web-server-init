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
dokku graphite:create graphite --custom-env "GF_SECURITY_ADMIN_USER=$MONITORING_USERNAME;GF_SECURITY_ADMIN_PASSWORD=$MONITORING_PASSWORD"
dokku apps:create "monitoring.$DOMAIN"
dokku config:set --no-restart "monitoring.$DOMAIN" SERVICE_NAME=graphite SERVICE_TYPE=graphite SERVICE_PORT=80
dokku graphite:link graphite "monitoring.$DOMAIN"
dokku git:from-image "monitoring.$DOMAIN" dokku/service-proxy:latest
dokku letsencrypt:enable "monitoring.$DOMAIN"
## Test we can push to graphite with
# dokku graphite:expose graphite 8125 8126 8080 8081 2003
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

# cAdvisor
dokku apps:create cadvisor
dokku graphite:link graphite cadvisor
dokku docker-options:add cadvisor deploy "--privileged"
dokku docker-options:add cadvisor deploy "--device=/dev/kmsg"
dokku config:set --no-restart cadvisor DOKKU_DOCKERFILE_START_CMD="--storage_driver=statsd --storage_driver_host=dokku-graphite-graphite:8125"
dokku storage:mount cadvisor /:/rootfs:ro
dokku storage:mount cadvisor /var/run:/var/run:ro
dokku storage:mount cadvisor /sys:/sys:ro
dokku storage:mount cadvisor /var/lib/docker:/var/lib/docker:ro
dokku storage:mount cadvisor /dev/disk:/dev/disk:ro
docker image pull gcr.io/cadvisor/cadvisor:v0.49.1
dokku git:from-image cadvisor gcr.io/cadvisor/cadvisor:v0.49.1

#sudo docker run \
#  --name=cadvisor \
#  --network=host \
#  --volume=/:/rootfs:ro \
#  --volume=/var/run:/var/run:ro \
#  --volume=/sys:/sys:ro \
#  --volume=/var/lib/docker/:/var/lib/docker:ro \
#  --volume=/dev/disk/:/dev/disk:ro \
#  --detach=true \
#  --name=cadvisor \
#  --privileged \
#  --device=/dev/kmsg \
#  gcr.io/cadvisor/cadvisor:v0.49.1 \
#  --port 8082 \
#  --storage_driver=statsd \
#  --storage_driver_host=0.0.0.0:8125

## Prometheus
## TODO: Rename prometheus1 to prometheus
## Make sure prometheus.$DOMAIN points to the server
#dokku network:create prometheus-bridge
## This is needed to fix https://github.com/dokku/dokku-http-auth/issues/15
#cd /home && sudo chmod +x dokku && cd -
#dokku apps:create "prometheus1.$DOMAIN"
#dokku ports:add "prometheus1.$DOMAIN" http:80:9090
#dokku network:set "prometheus1.$DOMAIN" attach-post-deploy prometheus-bridge
#sudo mkdir -p /var/lib/dokku/data/storage/prometheus/{config,data}
#sudo touch /var/lib/dokku/data/storage/prometheus/config/{alert.rules,prometheus.yml}
#dokku storage:mount "prometheus1.$DOMAIN" /var/lib/dokku/data/storage/prometheus/config:/etc/prometheus
#dokku storage:mount "prometheus1.$DOMAIN" /var/lib/dokku/data/storage/prometheus/data:/prometheus
#dokku config:set --no-restart "prometheus1.$DOMAIN" DOKKU_DOCKERFILE_START_CMD="--config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus --web.console.libraries=/usr/share/prometheus/console_libraries --web.console.templates=/usr/share/prometheus/consoles --web.enable-lifecycle --storage.tsdb.no-lockfile"
#sudo tee /var/lib/dokku/data/storage/prometheus/config/prometheus.yml <<EOF
#global:
#  scrape_interval: 15s
#scrape_configs:
#  - job_name: "prometheus"
#    scrape_interval: 15s
#    static_configs:
#      - targets:
#          - "localhost:9090"
#  - job_name: node-exporter
#    scrape_interval: 15s
#    scheme: https
#    basic_auth:
#      username: $MONITORING_USERNAME
#      password: $MONITORING_PASSWORD
#    relabel_configs: []
#    metric_relabel_configs: []
#    static_configs:
#      - targets:
#          - "node-exporter1.$DOMAIN"
#  - job_name: cadvisor
#    scrape_interval: 15s
#    scheme: http
#    static_configs:
#      - targets:
#          - cadvisor.$DOMAIN.web:8080
#EOF
#sudo chown -R nobody:nogroup /var/lib/dokku/data/storage/prometheus
#docker pull prom/prometheus:latest
#docker tag prom/prometheus:latest dokku/prometheus:latest
#dokku git:from-image "prometheus1.$DOMAIN" dokku/prometheus:latest
#dokku letsencrypt:enable "prometheus1.$DOMAIN"
## Need to enable / disable / enable - workaround for https://github.com/dokku/dokku-http-auth/issues/24
#dokku http-auth:enable "prometheus1.$DOMAIN" "$MONITORING_USERNAME" "$MONITORING_PASSWORD"
#dokku http-auth:disable "prometheus1.$DOMAIN"
#dokku http-auth:enable "prometheus1.$DOMAIN" "$MONITORING_USERNAME" "$MONITORING_PASSWORD"

## Node Exporter
## TODO: Rename node-exporter1 to node-exporter
#dokku apps:create "node-exporter1.$DOMAIN"
#dokku ports:add "node-exporter1.$DOMAIN" http:80:9100
##dokku config:set --no-restart "node-exporter1.$DOMAIN" DOKKU_DOCKERFILE_START_CMD="--collector.textfile.directory=/data --path.procfs=/host/proc --path.sysfs=/host/sys"
#dokku config:set --no-restart "node-exporter1.$DOMAIN" DOKKU_DOCKERFILE_START_CMD="--collector.textfile.directory=/data --path.rootfs=/host"
#dokku docker-options:add "node-exporter1.$DOMAIN" deploy,run "--net=host"
#dokku docker-options:add "node-exporter1.$DOMAIN" deploy,run "--pid=host"
#dokku checks:disable "node-exporter1.$DOMAIN"
#sudo mkdir -p /var/lib/dokku/data/storage/node-exporter
#sudo chown nobody:nogroup /var/lib/dokku/data/storage/node-exporter
##dokku storage:mount "node-exporter1.$DOMAIN" /proc:/host/proc:ro
##dokku storage:mount "node-exporter1.$DOMAIN" /:/rootfs:ro
##dokku storage:mount "node-exporter1.$DOMAIN" /sys:/host/sys:ro
#dokku storage:mount "node-exporter1.$DOMAIN" /:/host:ro,rslave
#dokku storage:mount "node-exporter1.$DOMAIN" /var/lib/dokku/data/storage/node-exporter:/data
#docker image pull quay.io/prometheus/node-exporter:latest
#docker image tag quay.io/prometheus/node-exporter:latest dokku/node-exporter:latest
#dokku git:from-image "node-exporter1.$DOMAIN" dokku/node-exporter:latest
#dokku letsencrypt:enable "node-exporter1.$DOMAIN"
## Need to enable / disable / enable - workaround for https://github.com/dokku/dokku-http-auth/issues/24
#dokku http-auth:enable "node-exporter1.$DOMAIN" "$MONITORING_USERNAME" "$MONITORING_PASSWORD"
#dokku http-auth:disable "node-exporter1.$DOMAIN"
#dokku http-auth:enable "node-exporter1.$DOMAIN" "$MONITORING_USERNAME" "$MONITORING_PASSWORD"

## cAdvisor
#dokku apps:create "cadvisor.$DOMAIN"
#dokku ports:add "cadvisor.$DOMAIN" http:80:8080
#dokku config:set --no-restart "cadvisor.$DOMAIN" DOKKU_DOCKERFILE_START_CMD="--docker_only --housekeeping_interval=10s --max_housekeeping_interval=60s"
#dokku network:set "cadvisor.$DOMAIN" attach-post-deploy prometheus-bridge
#dokku storage:mount "cadvisor.$DOMAIN" /:/rootfs:ro
#dokku storage:mount "cadvisor.$DOMAIN" /sys:/sys:ro
#dokku storage:mount "cadvisor.$DOMAIN" /var/lib/docker:/var/lib/docker:ro
#dokku storage:mount "cadvisor.$DOMAIN" /var/run:/var/run:rw
#docker image pull gcr.io/cadvisor/cadvisor:latest
#docker image tag gcr.io/cadvisor/cadvisor:latest dokku/cadvisor:latest
#dokku git:from-image "cadvisor.$DOMAIN" dokku/cadvisor:latest
## Need to enable / disable / enable - workaround for https://github.com/dokku/dokku-http-auth/issues/24
#dokku letsencrypt:enable "cadvisor.$DOMAIN"
#dokku http-auth:enable "cadvisor.$DOMAIN" "$MONITORING_USERNAME" "$MONITORING_PASSWORD"
#dokku http-auth:disable "cadvisor.$DOMAIN"
#dokku http-auth:enable "cadvisor.$DOMAIN" "$MONITORING_USERNAME" "$MONITORING_PASSWORD"

## Grafana
#dokku apps:create "grafana.$DOMAIN"
#dokku ports:add "grafana.$DOMAIN" http:80:3000
#dokku network:set "grafana.$DOMAIN" attach-post-deploy prometheus-bridge
#sudo mkdir -p /var/lib/dokku/data/storage/grafana/{config,data,plugins}
#sudo mkdir -p /var/lib/dokku/data/storage/grafana/config/provisioning/datasources
#sudo chown -R 472:472 /var/lib/dokku/data/storage/grafana
#dokku storage:mount "grafana.$DOMAIN" /var/lib/dokku/data/storage/grafana/config/provisioning/datasources:/etc/grafana/provisioning/datasources
#dokku storage:mount "grafana.$DOMAIN" /var/lib/dokku/data/storage/grafana/data:/var/lib/grafana
#dokku storage:mount "grafana.$DOMAIN" /var/lib/dokku/data/storage/grafana/plugins:/var/lib/grafana/plugins
#sudo tee /var/lib/dokku/data/storage/grafana/config/provisioning/datasources/prometheus.yml <<EOF
#datasources:
#  - name: Prometheus
#    type: prometheus
#    access: proxy
#    orgId: 1
#    url: http://prometheus1.$DOMAIN.web:9090
#    basicAuth: false
#    isDefault: true
#    version: 1
#    editable: true
#EOF
#dokku config:set --no-restart "grafana.$DOMAIN" GF_SECURITY_ADMIN_USER="$MONITORING_USERNAME" GF_SECURITY_ADMIN_PASSWORD="$MONITORING_PASSWORD"
#docker pull grafana/grafana:latest
#docker tag grafana/grafana:latest dokku/grafana:latest
#dokku git:from-image "grafana.$DOMAIN" dokku/grafana:latest
#dokku letsencrypt:enable "grafana.$DOMAIN"

#dokku apps:destroy "prometheus1.$DOMAIN" --force
#dokku apps:destroy "node-exporter1.$DOMAIN" --force
#dokku apps:destroy "grafana.$DOMAIN" --force
#dokku apps:destroy "cadvisor.$DOMAIN" --force
#sudo rm -rf /var/lib/dokku/data/storage/prometheus /var/lib/dokku/data/storage/node-exporter /var/lib/dokku/data/storage/grafana
