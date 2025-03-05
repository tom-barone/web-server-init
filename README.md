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

## Getting started

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

```bash
scp init.sh tbone@<server>:~
```

Run `push.sh` to push new logcheck rules to a server.

## Linode

Update locales if needed, for example Linode sets Aussie servers with en_AU locales which aren't always available:

```bash
sudo dpkg-reconfigure locales
# Select en_AU.UTF-8
```

## Installing on own hardware via USB

Follow whatever is recommended on the [Debian website](https://www.debian.org/CD/netinst).

I've found it easier to use Windows to configure USB drives.
As of writing, use a clean FAT32 formatted USB drive to start with that has at least 2GB of space.
I prefer the `netinst` installer.

Boot from the USB drive and follow the prompts.

- Choose `Install` instead of `Graphical install`.
- I like to set the hostname to something like `au-adelaide`
- The domain name should be the FQDN you'll use for SSH access, for example `au-adelaide.mydomain.com`
- Don't set a root password
- Don't install any desktop environments like GNOME

After the installation is complete, remove the USB drive and reboot the PC.

Log in, confirm internet access and install the ssh server:

```bash
ping google.com
sudo apt update
sudo apt install openssh-server
```

Should now be able to SSH into the server from another machine on the local network.

For some reason, Debian likes to set the nameserver to the router or local machine which is no good and causes problems for the Docker daemon.
We'd prefer to use a public DNS server like Cloudflare or Google.
Modify the dhclient config `/etc/dhcp/dhclient.conf`, see [here](https://wiki.debian.org/resolv.conf) for details:

```bash
# Make sure this line is commented out
# supersede domain-name-servers 127.0.0.1;
# Put in some public DNS servers
supersede domain-name-servers 1.1.1.1, 1.0.0.1, 8.8.8.8;
```

Run the regular setup scripts as above.
