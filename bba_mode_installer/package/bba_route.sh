#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

# BBA Mode tool written by scrivanidc@gmail.com
# -------------------------------------------------------------------------
# We are living our best Dreamcast Lives
# -------------------------------------------------------------------------
# Rev1.1 - jun/2023 - Rev1.2 sep/2023 - Rev.1.3 jan/2024 - Rev.2.0 Sep/2025

systemctl stop dreampi
#Change the IP Pattern below if is the same of your standard network
#Second example: ip 192.168.5.1 / dhcpstart 192.168.5.2 / dhcpend 192.168.5.100
ip_address="192.168.2.1"
netmask="255.255.255.0"
dhcp_range_start="192.168.2.2"
dhcp_range_end="192.168.2.2"
dhcp_time="24h"
dns_server="46.101.91.123"
eth="eth0"
wlan="wlan0"

#If you want to share the onboard ethernet connection through a additional USB Ethernet port, do like these example:
#eth="eth1" # the secondary ethernet port that will serve BBA.
#wlan="eth0" # the onboard ethernet port where internet cable is connected to.

#checking if the source interface is operational
check=$(ip -o -4 addr show $wlan | awk '{print $4}' | cut -d/ -f1)
if [ -z $check ]; then
    msg="BBA Mode: Source interface "$wlan" does not have assigned IP, set connection for "$wlan" and retry."
    echo ""
    echo $msg
    echo ""
    logger $msg
	systemctl restart dreampi &
    pgrep -f bba_bin | sudo xargs kill -9 2>/dev/null
    pgrep -f bba_mode | sudo xargs kill -9 2>/dev/null
    exit 0
fi

systemctl start network-online.target &> /dev/null

iptables -F
iptables -t nat -F
iptables -t nat -A POSTROUTING -o $wlan -j MASQUERADE
iptables -A FORWARD -i $wlan -o $eth -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $eth -o $wlan -j ACCEPT

sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

ifconfig $eth down
ifconfig $eth up
ifconfig $eth $ip_address netmask $netmask

# Remove default route created by dhcpcd
ip route del 0/0 dev $eth &> /dev/null

systemctl stop dnsmasq

rm -rf /etc/dnsmasq.d/custom* &> /dev/null
rm -rf /tmp/custom-dnsmasq.conf &> /dev/null

echo "interface=$eth
bind-interfaces
server=$dns_server
domain-needed
log-queries
dhcp-authoritative
bogus-priv
dhcp-range=$dhcp_range_start,$dhcp_range_end,$dhcp_time" > /tmp/custom-dnsmasq.conf

cp /tmp/custom-dnsmasq.conf /etc/dnsmasq.d/custom-dnsmasq.conf 2>/dev/null
systemctl start dnsmasq

sed -i '/dnsmasq/d;/^exit/i rm -f /etc/dnsmasq.d/custom* 2> /dev/null\n' /etc/rc.local
sed -i ':L;N;s/^\n$//;t L' /etc/rc.local

# #>>> down here is rules in case you want to reuse .98 IP DMZ capacity on BBA Mode, that means, don't need to additionally open ports for raspberrypi IP.
# #>>> port 22 ssh is set to reject any outside connections, this is for security.
# #>>> so you need to uncomment then all, removing the # from the beginning
#ip_pattern=$(ifconfig $wlan | grep -Eo 'inet ([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}')
#ip_address=$ip_pattern'98'
#ip addr add $ip_address/24 dev $eth
#iptables -I INPUT -p tcp --dport 22 -d $ip_address -j REJECT

#driving strikers port forwarding rule
iptables -t nat -A PREROUTING -p udp --dport 30099 -i wlan0 -j DNAT --to-destination $dhcp_range_end:30099
#classicube port forwarding rule
iptables -t nat -A PREROUTING -p udp --dport 25565 -i wlan0 -j DNAT --to-destination $dhcp_range_end:25565
