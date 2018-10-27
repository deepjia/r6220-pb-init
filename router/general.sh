#!/bin/sh
cd /tmp/router || exit 1


wanconfig(){
while true; do
  echo "Network type for WAN? [pppoe/dhcp/static]"
  [ $wanproto ] && echo "Use preset value." || read -p "(Default: pppoe):" wanproto
  case $wanproto in
    pppoe|'' ) setpppoe;break;;
    dhcp ) break;;
    static ) setstatic;break;;
    * ) echo "Please input pppoe/dhcp/static";;
  esac
done
#设置hostname和samba name
sed -i "s/hostname.*/hostname '${rhostname}'/" /etc/config/system
sed -i "s/name.*/name '${sambaname}'/" /etc/config/samba
echo "Network configured, waiting for network..."
/etc/init.d/network restart
/etc/init.d/samba restart
sleep 10s
}


setpppoe(){
[ $pppoeuser ] && echo "Use preset value." || read -p "Input PPPoE username:" pppoeuser
[ $pppoepasswd ] && echo "Use preset value." || read -p "Input PPPoE password:" -s pppoepasswd
awk -v pppoeuser="$pppoeuser" -v pppoepasswd="$pppoepasswd" '{gsub(/option proto '\''dhcp'\''/,\
"option _orig_ifname '\''eth0.2'\''\
\toption _orig_bridge '\''false'\''\
\toption proto '\''pppoe'\''\
\toption username '\''"pppoeuser"'\''\
\toption password '\''"pppoepasswd"'\''\
\toption ipv6 '\''auto'\''\
\toption peerdns '\''0'\''\
\toption dns '\''114.114.114.114 114.114.115.115 119.29.29.29'\''")}1' /etc/config/network>/tmp/router/network
mv /tmp/router/network /etc/config/network
}


setstatic(){
[ $ipaddr ] && echo "Use preset value." || read -p "Input WAN IP:" ipaddr
[ $netmask ] && echo "Use preset value." || read -p "Input WAN Netmask:" netmask
[ $gateway ] && echo "Use preset value." || read -p "Input WAN Netmask:" gateway
awk -v ipaddr="$ipaddr" -v netmask="$netmask" -v gateway="$gateway" '{gsub(/option proto '\''dhcp'\''/,\
"option _orig_ifname '\''eth0.2'\''\
\toption _orig_bridge '\''false'\''\
\toption proto '\''static'\''\
\toption ipaddr '\''"ipaddr"'\''\
\toption netmask '\''"netmask"'\''\
\toption gateway '\''"gateway"'\''")}1' /etc/config/network>/tmp/router/network
mv /tmp/router/network /etc/config/network
}


modifypkg(){
#换一个优雅的皮肤，顺便删掉PandoraboxROM里集成的KMS服务
echo "Installing and removing packages..."
opkg install luci-theme-ATMaterial*.ipk
opkg remove luci-app-vlmcsd vlmcsd
}


addpkg(){
echo "Network OK"
echo "Adding pkg source..."
#修改架构，mipsel_1004kc_dsp在OpenWrt里也可以使用ramips_24kec，PandoraBox基于OpenWrt而非LEDE
cat<<EOF >>/etc/opkg.conf
arch all 1
arch noarch 1
arch mipsel_1004kc_dsp 10
arch ramips_24kec 10
EOF
#添加openwrt-dist源
cat<<EOF >>/etc/opkg/customfeeds.conf
src/gz openwrt-dist http://openwrt-dist.sourceforge.net/packages/OpenWrt/base/ramips
src/gz openwrt_dist_luci http://openwrt-dist.sourceforge.net/packages/OpenWrt/luci
EOF
#dropbear支持scp但不支持sftp，可以安装openssh-sftp-server来支持，即使不安装也有scp
opkg update
opkg install openssh-sftp-server luci-app-sqm
opkg remove luci-i18n-vsftpd-zh-cn luci-app-vsftpd vsftpd
}


ss(){
#默认不安装ss透明代理
echo "Configure ss transparent proxy? (Not stable, for newest firmware only)[y/n]"
[ $ifss ] && echo "Use preset value." || read -p "(Default: n):" ifss
while true; do
  case $ifss in
    Y|y|yes ) break;;
    N|n|no|'' ) return 0;;
    * ) echo "Please input y(es) or n(o)";;
  esac
done
echo "Configuring chinternet..."
opkg remove dnsmasq && opkg install dnsmasq-full
opkg install shadowsocks-libev simple-obfs coreutils-base64 curl
echo "Enter the information of SS server. You can change it later in LuCI page."
[ $ssaddr ] && echo "Use preset value." || read -p "SS server address:" ssaddr
[ $ssport ] && echo "Use preset value." || read -p "SS server port:" ssport
[ $ssencryt ] && echo "Use preset value." || read -p "SS encryption method:" ssencryt
[ $sspassswd ] && echo "Use preset value." || read -p "SS password:" -s sspassswd
while true; do
  echo "Do your server support obfs-simple plugin? [y/n]"
  [ $ifobfs ] && echo "Use preset value." || read -p "(Default: y):" ifobfs
  case $ifobfs in
    Y|y|yes|'' ) ifobfs='\n\t"plugin":"obfs-local",\n\t"plugin_opts":"obfs=http;obfs-host=cloudfront.net",'
    break;;
    N|n|no ) ifobfs='';break;;
    * ) echo "Please input y(es) or n(o)";;
  esac
done
#配置文件/etc/ss.json
echo -e "{
\t\"server\":\"${ssaddr}\",
\t\"server_port\":${ssport},
\t\"local_port\":1080,
\t\"password\":\"${sspassswd}\",
\t\"timeout\":600,${ifobfs}
\t\"method\": \"${ssencryt}\"
}">>/etc/ss.json
#添加几个自定义的luci页面
cp -r chinternet /usr/lib/lua/luci/model/cbi/
cp chinternet.lua /usr/lib/lua/luci/controller/
#gfwlist转换为dnsmasq，并添加自定义规则
curl -s -L --insecure -o glist2dnsmasq.sh https://raw.githubusercontent.com/cokebar/gfwlist2dnsmasq/master/gfwlist2dnsmasq.sh
chmod +x ssd glist2dnsmasq.sh
cp ssd /etc/init.d/
cp glist2dnsmasq.sh /etc/
mkdir /etc/dnsmasq.d
uci add_list dhcp.@dnsmasq[0].confdir=/etc/dnsmasq.d
uci commit dhcp
/etc/glist2dnsmasq.sh -i -s glist -o /etc/dnsmasq.d/dnsmasq_glist_ipset.conf
echo -e >>/etc/dnsmasq.d/dnsmasq_custom_ipset.conf "\
server=/fast.com/127.0.0.1#5353\nipset=/fast.com/glist
server=/speedtest.net/127.0.0.1#5353\nipset=/speedtest.net/glist
server=/amazonaws.com/127.0.0.1#5353\nipset=/amazonaws.com/glist
server=/winudf.com/127.0.0.1#5353\nipset=/winudf.com/glist"
/etc/init.d/ssd enable
/etc/init.d/ssd restart
/etc/init.d/dnsmasq restart
cat /etc/firewall.user|grep glist || echo "ipset -N glist iphash">>/etc/firewall.user
while true; do
  echo "Apply transparent proxy to all network interfaces and devices? [y/n]"
  [ $ifallproxy ] && echo "Use preset value." || read -p "(Default: n):" ifallproxy
  case $ifallproxy in
    Y|y|yes ) noglan;break;;
    N|n|no|'' ) glan;break;;
    * ) echo "Please input y(es) or n(o)";;
  esac
done
/etc/init.d/firewall restart
}


noglan(){
echo "Configuring firewall..."
cat <<EOF >>/etc/firewall.user
iptables -t nat -A PREROUTING -p tcp -m set --match-set glist dst -j REDIRECT --to-port 1080
iptables -t nat -A OUTPUT -p tcp -m set --match-set glist dst -j REDIRECT --to-port 1080
EOF
}


glan(){
echo "Adding network glan..."
echo -e "config interface 'glan'
\toption type 'bridge'
\toption proto 'static'
\toption ipaddr '192.168.2.1'
\toption netmask '255.255.255.0'
\toption _orig_ifname 'glan ra1'
\toption _orig_bridge 'true'
">>/etc/config/network
echo "Configuring glan DHCP..."
echo -e "config dhcp 'glan'
\toption start '100'
\toption leasetime '12h'
\toption limit '150'
\toption interface 'glan'
">>/etc/config/dhcp
/etc/init.d/dnsmasq restart
#glan与lan公用防火墙区域
sed -i "s/list network 'lan'/option network 'lan glan'/" /etc/config/firewall
cat <<EOF >>/etc/firewall.user
iptables -t nat -A PREROUTING -i br-glan -p tcp -m set --match-set glist dst -j REDIRECT --to-port 1080
iptables -t nat -A OUTPUT -o br-glan -p tcp -m set --match-set glist dst -j REDIRECT --to-port 1080
EOF
#创建透明代理热点XXX-G
echo -e  "config wifi-iface
\toption device 'ra'
\toption mode 'ap'
\toption ssid 'Wireless-G'
\toption encryption 'psk2'
\toption network 'glan'
">>/etc/config/wireless
echo -e "Interface 'glan' and Wi-Fi interface '${wifissid}-G' created."
}


wireless(){
[ $wifissid ] && echo "Use preset value." || read -p "Input Wi-Fi SSID name:" wifissid
[ $wifikey ] && echo "Use preset value." || read -p "Input Wi-Fi key:" -s wifikey
echo "Configuring wireless network..."
echo "Input 2.4G Channel: [auto/1/2/.../13]"
[ $channel24 ] && echo "Use preset value." || read -p "(Default: auto):" channel24
case $channel24 in
  [1-13] ) sed -i "/wifi-device '\?ra'\?/,/wifi-device '\?rai'\?/{s/channel '\?auto'\?/channel '${channel24}'/}" /etc/config/wireless
	;;
  * ) echo "Use auto channel."
	;;
esac
#2.4G的SSID
sed -i "/wifi-device '\?ra'\?/,/ssid/{s/ssid .*/ssid '${wifissid}'/}" /etc/config/wireless
#5G的SSID
sed -i "/wifi-device '\?rai'\?/,/ssid/{s/ssid .*/ssid '${wifissid}-5'/}" /etc/config/wireless
#sed -i "/smart '\?0'\?/d" /etc/config/wireless
sed -i "s/encryption '\?none'\?/encryption 'psk2'/" /etc/config/wireless
sed -i "s/Wireless-G/${wifissid}-G/" /etc/config/wireless
#awk -v wifikey="$wifikey" '/encryption/{print "\toption key '\''"wifikey"'\''\
#\toption rssikick '\''-76'\''\
#\toption rssiassoc '\''-75'\''"}1' /etc/config/wireless>/tmp/router/wireless
awk -v wifikey="$wifikey" '/encryption/{print "\toption key '\''"wifikey"'\''\
\toption rssikick '\''-80'\''"}1' /etc/config/wireless>/tmp/router/wireless
mv /tmp/router/wireless /etc/config/wireless
}

virtualhere(){
#默认不安装virtualhere
echo "Install VirtualHere to connect printer and scanner like usb devices? [y/n]"
[ $ifvirtualhere ] && echo "Use preset value." || read -p "(Default: n):" ifvirtualhere
while true; do
  case $ifvirtualhere in
    Y|y|yes ) break;;
    N|n|no|'' ) return 0;;
    * ) echo "Please input y(es) or n(o)";;
  esac
done
wget http://virtualhere.com/sites/default/files/usbserver/vhusbdmipsel
chmod +x vhusbdmipsel
cp vhusbdmipsel /usr/sbin/
#/usr/sbin/vhusbdmipsel -b
#sed -i "s|exit 0|/usr/sbin/vhusbdmipsel -b\nexit 0|" /etc/rc.local
chmod +x vhusbd
cp vhusbd /etc/init.d/
/etc/init.d/vhusbd enable
}


green='\033[0;32m'
plain='\033[0m'
rhostname=Netgear
sambaname=R6220
wanconfig
modifypkg
ping -c 1 baidu.com && addpkg && ss
virtualhere
wireless
echo "Please reboot."
