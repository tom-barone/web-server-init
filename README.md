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
vi ~/.ssh/authorized_keys
# ^ Put in the public key
# Also if you want to let them ssh in as root
#sudo cat ~/.ssh/authorized_keys >> /root/.ssh/authorized_keys
sudo mkdir -p /root/.ssh
sudo tee -a /root/.ssh/authorized_keys < ~/.ssh/authorized_keys
```

# Add the docker group

sudo groupadd docker
sudo usermod -aG docker tbone

````

Copy the `init.sh` script to your server and run it.

```bash
scp init.sh tbone@<server>:~
````

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
- Leave the domain name blank
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

Check `/etc/resolv.conf` to make sure the changes have taken effect.

For a simple mini PC that has WiFi support, the `/etc/network/interfaces` file can be modified to connect via both Ethernet / WiFi:

```bash
# Example Ethernet config (double check the interface name with 'ip a')
# metric: currently set to a higher priority value so that Ethernet is preferred
# auto: Means the interface will be brought up automatically on boot
# dhcp: Use DHCP from the router to get an IP address
auto eno1
iface eno1 inet dhcp
    metric 100

# Example WiFi config (double check the interface name with 'ip a')ip route get 8.8.8.8
# allow-hotplug: Means the interface will be brought up when the system detects a hotplug event
#                i.e. whenever the WiFi network becomes available
allow-hotplug wlp0s20f3
iface wlp0s20f3 inet dhcp
    wpa-ssid <wifi_ssid>
    wpa-psk  <wifi_password>
    metric 200

# Check which interface is being used with 'ip route get 8.8.8.8'
# Or check routing table with 'ip route'
# NOTE: If using with a stock home internet router, these are both given separate IP addresses.
#       So any port forwarding (22, 80, 443 etc) needs to pick which interface to send traffic to.
```

Run the regular setup scripts as above.

## Dead battery on an old laptop

An old laptop with a dead battery can cause annoying cycling between `AC Power` and `0% Battery` states.

To fix this, you can [disable the battery module](https://wiki.debian.org/KernelModuleBlacklisting) in the kernel and stop it being loaded at boot time, which causes the system to rely on AC power only and ignore the battery entirely.

Add the following line to `/etc/modprobe.d/battery.conf`:

```bash
blacklist battery
```

Then apply the changes to the boot process:

```bash
sudo update-initramfs -u
```
