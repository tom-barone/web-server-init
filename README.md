# Self hosted web server setup

Current best practices:

- Debian 12 as base OS.
- Dokku for managing web apps.
- Block all ports except 22, 80, 443.
- Disable password based logins for SSH entirely and use SSH keys.
- Fail2Ban for stemming the flow of brute force attacks.
- Postfix for sending emails.
- Logcheck for monitoring logs.
- unattended-upgrades for automatic security updates.
- [Uptime Robot](https://uptimerobot.com) to monitor the server every 5 minutes and alert if it goes down.

# Getting started

Create a user account:

```bash
sudo adduser tbone
sudo usermod -aG sudo tbone

# Add their public key
sudo su tbone
mkdir ~/.ssh
cat <your_ssh_public_key> | tee -a ~/.ssh/authorized_keys

# Add the docker group
sudo groupadd docker
sudo usermod -aG docker tbone
```

Copy the `init.sh` script to your server and run it.

Run `push.sh` to push new logcheck rules to a server.

# Linode

Update locales if needed, for whatever reason Linode sets Aussie servers with en_AU locales which aren't always available:

```bash
sudo dpkg-reconfigure locales
# Select en_AU.UTF-8
```
