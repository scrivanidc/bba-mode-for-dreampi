#!/bin/bash

# Share Wifi with Eth device
#
# This script is created to work with Raspbian Stretch
# but it can be used with most of the distributions
# by making few changes.
#
# Make sure you have already installed `dnsmasq`
# Please modify the variables according to your need
# Don't forget to change the name of network interface
# Check them with `ifconfig`
sudo service dreampi stop
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
#eth="eth1" # the secondary ethernet port that will serve the shared equipment.
#eth="eth0" # the onboard ethernet port where internet cable is connected to.

#checking if the source interface is operational
check=$(ifconfig $wlan | grep 'inet' | cut -d: -f2 | awk '{print $2}')
if [ -z $check ]; then
    msg="BBA Mode: Source interface "$wlan" does not have assigned IP, set connection for "$wlan" and retry."
    echo ""
    echo $msg
    echo ""
    logger $msg
    sudo killall bba_mode.sh 2> /dev/null
    sudo service dreampi restart &
    exit 0
fi

sudo systemctl start network-online.target &> /dev/null

sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t nat -A POSTROUTING -o $wlan -j MASQUERADE
sudo iptables -A FORWARD -i $wlan -o $eth -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i $eth -o $wlan -j ACCEPT

sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

sudo ifconfig $eth down
sudo ifconfig $eth up
sudo ifconfig $eth $ip_address netmask $netmask

# Remove default route created by dhcpcd
sudo ip route del 0/0 dev $eth &> /dev/null

sudo systemctl stop dnsmasq

sudo rm -rf /etc/dnsmasq.d/custom* &> /dev/null
sudo rm -rf /tmp/custom-dnsmasq.conf &> /dev/null

echo "interface=$eth
bind-interfaces
server=$dns_server
domain-needed
log-queries
dhcp-authoritative
#log-dhcp
bogus-priv
dhcp-range=$dhcp_range_start,$dhcp_range_end,$dhcp_time" > /tmp/custom-dnsmasq.conf

sudo cp /tmp/custom-dnsmasq.conf /etc/dnsmasq.d/custom-dnsmasq.conf 2>/dev/null
sudo systemctl start dnsmasq

sudo sed -i '/dnsmasq/d;/^exit/i rm -f /etc/dnsmasq.d/custom* 2> /dev/null\n' /etc/rc.local
sudo sed -i ':L;N;s/^\n$//;t L' /etc/rc.local

# #>>> down here is rules in case you want to reuse .98 IP DMZ capacity on BBA Mode, that means, don't need to additionally open ports for raspberrypi IP.
# #>>> port 22 ssh is set to reject any outside connections, this is for security.
# #>>> so you need to uncomment then all, removing the # from the beginning
#ip_pattern=$(ifconfig $wlan | grep -Eo 'inet ([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}')
#ip_address=$ip_pattern'98'
#sudo ip addr add $ip_address/24 dev $eth
#sudo iptables -I INPUT -p tcp --dport 22 -d $ip_address -j REJECT

#driving strikers port forwarding rule
sudo iptables -t nat -A PREROUTING -p udp --dport 30099 -i wlan0 -j DNAT --to-destination $dhcp_range_end:30099
