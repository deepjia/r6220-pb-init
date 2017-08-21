# R6220 PandoraBox Initialization Script
## Introduction
This is my initialization script for R6200 Pandorabox.

Only tested on macOS, but should also work on any Unix-like OS.

## Prerequisites
Netgear R6220 with PandoraBox firmware.

MacOS, Linux or any OS with SSH clients.

## Usage
### Unix-like OS

```
bash init-r6220.sh
```

### Other OS

Copy router folder to /tmp of the router, then:

```
sh /tmp/router/general.sh
```
If you have customize sript:

```
sh /tmp/router/custom.sh
```
### Note：
Default root password is `admin`

Reboot the router manually once finished.
## Customization
Add custom.sh in router folder.

eg:

```
#!/bin/bash

# Parameters
export wanproto=pppoe
export pppoeuser=myusername
export pppoepasswd=mypassword
export wifissid=myssid
export wifikey=MYWIFIKEY
export channel24=6
#export ....

# Run genral.sh
sh /tmp/router/general.sh

# DHCP
echo "Configuring static leases..."
echo -e >>/etc/config/dhcp "\
config dhcp 'glan'\n\toption start '100'\n\toption leasetime '12h'\n\toption limit '150'\n\toption interface 'glan'\n
config host\n\toption name 'Hostname'\n\toption mac 'aa:aa:aa:aa:aa:aa'\n\toption ip '192.168.1.200'\n"
/etc/init.d/dnsmasq restart

# Firewall for specific lan ip
echo "Configuring firewall..."
cat /etc/firewall.user|grep glist || echo "ipset -N glist iphash">>/etc/firewall.user
cat <<EOF>>/etc/firewall.user

iptables -t nat -A PREROUTING -s 192.168.1.100 -p tcp -m set --match-set glist dst -j REDIRECT --to-port 1080
iptables -t nat -A OUTPUT -s 192.168.1.100 -p tcp -m set --match-set glist dst -j REDIRECT --to-port 1080
EOF
/etc/init.d/firewall restart

# Dropbear
echo "Configuring dropbear..."
cat <<EOF>>/etc/dropbear/authorized_keys
ssh-rsa AAAAAAAAAAAAAAAA user@hostname.local
ssh-rsa AAAAAAAAAAAAAAAA user2@hostname2.local
EOF
sed -i "s/PasswordAuth 'on'/PasswordAuth 'off'/" /etc/config/dropbear
sed -i "s/RootPasswordAuth 'on'/RootPasswordAuth 'off'/" /etc/config/dropbear
/etc/init.d/dropbear restart
```
