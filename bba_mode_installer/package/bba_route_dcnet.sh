#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

# BBA Mode tool written by scrivanidc@gmail.com
# ---------------------------------------------------------------------------------------------
# We are living our best Dreamcast Lives
# ---------------------------------------------------------------------------------------------
# Rev1.1 - jun/2023 - Rev1.2 sep/2023 - Rev.1.3 jan/2024 - Rev.2.0 sep/2025 - Rev.2.1 jun/2026

#Stop DreamPi
systemctl stop dreampi

#Clean DCNet Tunnel
killall pppd 2>/dev/null
ip rule del fwmark 10 table 100 2>/dev/null
ip route flush table 100 2>/dev/null

#Change the IP Pattern below if is the same of your standard network
#Second example: ip 172.16.0.1 / dhcpstart 172.16.0.2 / dhcpend 172.16.0.2
ip_address="192.168.2.1"
netmask="255.255.255.0"
dhcp_range_start="192.168.2.2"
dhcp_range_end="192.168.2.2"
dhcp_time="24h"
eth="eth0"
ppp="ppp0"

#If you want to share the onboard ethernet connection through a additional USB Ethernet port, do like these example:
#eth="eth1" # the secondary ethernet port that will serve BBA.

echo "==== DCNET DEBUG START ===="
# ----------------------------
# Region discovery (UDP probe)
# ----------------------------
get_server_names() {
    echo "[DEBUG] Sending UDP discovery packet..." >&2
    response=$(printf '\x01\xC0\x15\xDC\x03' | nc -u -w3 dcnet.flyca.st 7655 2>/dev/null)
    echo "[DEBUG] Raw response captured" >&2
    clean=$(echo "$response" | strings)
    regions=$(echo "$clean" | grep -oE "US East|US West|Europe|South America")
    echo "[DEBUG] Detected regions: $regions" >&2
    echo "$regions"
}

# ----------------------------
# Region → host mapping
# ----------------------------
map_region_to_host() {
    case "$1" in
        "US East") echo "dcnet-use.flyca.st" ;;
        "US West") echo "dcnet-usw.flyca.st" ;;
        "Europe") echo "dcnet-eu.flyca.st" ;;
        "South America") echo "dcnet-br.flyca.st" ;;
        *) echo "" ;;
    esac
}

# ----------------------------
# Parallel ping selection
# ----------------------------
best_host() {
    echo "[DEBUG] Running parallel ping test..." >&2
    tmp=$(mktemp)
    for host in "$@"; do
        (
            ping_val=$(ping -c 1 -W 1 "$host" 2>/dev/null | grep 'time=' | sed -E 's/.*time=([0-9.]+).*/\1/')
            if [ -n "$ping_val" ]; then
                echo "$ping_val $host" >> "$tmp"
            fi
        ) &
    done
    wait
    best=$(sort -n "$tmp" | head -1 | awk '{print $2}')
    rm -f "$tmp"
    echo "[DEBUG] Selected server: $best" >&2
    echo "$best"
}

# ----------------------------
# Get regions
# ----------------------------
echo "[DEBUG] Fetching region list..." >&2
regions=$(get_server_names)
hosts=()
if [ -n "$regions" ]; then
    echo "[DEBUG] Mapping regions to hosts..." >&2
    while IFS= read -r region; do
        host=$(map_region_to_host "$region")
        if [ -n "$host" ]; then
            hosts+=("$host")
            echo "[DEBUG] $region → $host" >&2
        fi
    done <<< "$regions"
else
    echo "[DEBUG] No regions found, using fallback list..." >&2
    hosts=("dcnet-use.flyca.st" "dcnet-usw.flyca.st" "dcnet-eu.flyca.st" "dcnet-br.flyca.st")
fi

echo "[DEBUG] Final host list:" >&2
printf '%s\n' "${hosts[@]}" >&2

best=$(best_host "${hosts[@]}")

if [ -z "$best" ]; then
    echo "[DEBUG] No valid host found, using fallback" >&2
    best="dcnet.flyca.st"
fi
best="dcnet.flyca.st"
echo "==== RESULT ===="
echo "DCNET: Best Server: $best"
echo "================="

# ----------------------------
# Start DCNET PPP
# ----------------------------
pppd nodetach noauth debug defaultroute usepeerdns \
user flycast1 password password \
pty "nc $best 7654" > /tmp/dcnet_bba.log 2>&1 &

# ----------------------------
# Wait for PPP to be ready
# ----------------------------
for i in {1..10}; do
    if grep -q "local  IP address" /tmp/dcnet_bba.log; then
        ppp=$(grep -m1 Connect: /tmp/dcnet_bba.log | awk '{print $2}')
        break
    fi
    sleep 1
done

#checking if the source interface is operational
check=$(ip -o -4 addr show $ppp | awk '{print $4}' | cut -d/ -f1)
if [ -z "$check" ]; then
    msg="BBA Mode: Source interface "$ppp" does not have assigned IP, set connection for "$ppp" and retry."
    echo $msg
    logger $msg
    systemctl restart dreampi &
    #pgrep -f bba_bin | xargs kill -9 2>/dev/null
    pgrep -f bba_mode | xargs kill -9 2>/dev/null
    exit 0
fi

dns_server=$(ip -o -4 addr show $ppp | awk '{print $6}' | cut -d/ -f1)

systemctl start network-online.target &> /dev/null

# ----------------------------
# Network configuration
# ----------------------------
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -t nat -A POSTROUTING -o $ppp -j MASQUERADE
iptables -A FORWARD -i $ppp -o $eth -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $eth -o $ppp -j ACCEPT

echo 1 > /proc/sys/net/ipv4/ip_forward

pkill -9 dhclient

ifconfig $eth down
ifconfig $eth up
ifconfig $eth $ip_address netmask $netmask

# Remove default route created by dhcpcd
ip route del 0/0 dev $eth &> /dev/null

systemctl stop dnsmasq

rm -rf /etc/dnsmasq.d/custom* &> /dev/null
rm -rf /tmp/custom-dnsmasq.conf &> /dev/null

cat > /tmp/custom-dnsmasq.conf <<EOF
interface=$eth
bind-interfaces
server=$dns_server
no-resolv
no-poll
domain-needed
log-queries
dhcp-authoritative
bogus-priv
dhcp-range=$dhcp_range_start,$dhcp_range_end,$dhcp_time
EOF

cp /tmp/custom-dnsmasq.conf /etc/dnsmasq.d/custom-dnsmasq.conf 2>/dev/null

#clean dhcp lease
#truncate -s 0 /var/lib/misc/dnsmasq.leases 2>/dev/null || true

systemctl start dnsmasq

sed -i '/dnsmasq/d;/^exit/i rm -f /etc/dnsmasq.d/custom* 2> /dev/null\n' /etc/rc.local
sed -i ':L;N;s/^\n$//;t L' /etc/rc.local

iptables -t mangle -A PREROUTING -s $dhcp_range_start -j MARK --set-mark 10
ip route add default dev $ppp table 100
ip rule add fwmark 10 table 100
#iptables -t nat -L -n -v

echo "Done."
