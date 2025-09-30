#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

# BBA Mode tool written by scrivanidc@gmail.com
# -------------------------------------------------------------------------
# We are living our best Dreamcast Lives
# -------------------------------------------------------------------------
# Rev1.1 - jun/2023 - Rev1.2 sep/2023 - Rev.1.3 jan/2024 - Rev.2.0 Sep/2025

#BBA Mode tool files locations
eth_routesh="/home/pi/dreampi/bba_route.sh"
bba_binsh="/home/pi/dreampi/bba_bin.sh"
bba_binpy="/home/pi/dreampi/bba_bin.py"

clean_session() {
  killall -q tcpdump 2>/dev/null
  killall -q python2.7 2>/dev/null
  #Just to make sure
  pgrep -f tcpdump | sudo xargs kill -9 2>/dev/null
  pgrep -f python | sudo xargs kill -9 2>/dev/null
}

if [ "$1" == 0 ]; then

    ech0=$(grep -m 1 "eth=" "$eth_routesh" | cut -d '"' -f 2)
    ech1=$(grep -m 1 "dhcp_range_start=" "$eth_routesh" | cut -d '"' -f 2)
    ech2=$(grep -m 1 "netmask=" "$eth_routesh" | cut -d '"' -f 2)
    ech3=$(grep -m 1 "ip_address=" "$eth_routesh" | cut -d '"' -f 2)
    ech4=$(grep -m 1 "dns_server=" "$eth_routesh" | cut -d '"' -f 2)

    txt="
BBA Mode Additional Instructions: Make sure your connection is as needed for this routing.
By default you must be connected via wi-fi and the LAN port available to send a cable >> CAT5-E << to the Dreamcast.

Addresses information to consider for DHCP(prefer) or Static IP configuration:

Static IP Config
Dreamcast IP - "$ech1"
Netmask      - "$ech2"
Gateway      - "$ech3"
DNS1         - "$ech3"
DNS2         - "$ech4"

DHCP Config
Hostname                - 'Dreamcast' or leave it blank
Gateway/DHCP Server     - "$ech3"
DNS1/DNS2 same as above

This comes directly from "$eth_routesh" Router Script File,
and is set to share present wi-fi over the onboard ethernet port.
Edit the file if you need a different IP pattern or share ethernet to ethernet(extra usb lan)

This mode does not impact the standard dial-up mode, as it uses a customized/separate file
of dnsmasq and is prepared to undo unwanted actions.

From now on the modem function is turned off until the next reboot.


BBA Mode tool written by scrivanidc@gmail.com
-------------------------------------------------------------------------
We are living our best Dreamcast Lives
-------------------------------------------------------------------------
"
    #Start eth sharing route
    bash -c "$eth_routesh"
    active="no"
    logger "Starting BBA Mode ..."
    logger "Set on DC> IP=$ech1 Netmask=$ech2 Gateway/DHCPServer=$ech3 DNS1=$ech3 DNS2=$ech4"
    logger "Edit $eth_routesh Router Script File if you need a different IP pattern "
    echo "$txt"
    echo ""
    echo "Starting BBA Connection Analysis soon ..."
    sleep 6
	logger "BBA Connection Analysis Active..."

    while true
    do
      echo "BBA Connection Analysis ..."

      linkup=$(cat /sys/class/net/$ech0/carrier | grep 1)
      if [ -n "$linkup" ] && [ "$active" == "no" ]; then
          active="yes"
          msgup="BBA Mode: Ethernet link_up/connection detected"
          echo $msgup ; logger $msgup
          clean_session
          python2.7 "$bba_binpy" "0" "$ech0" --no-daemon &
          sleep 12
      fi

      linkdown=$(cat /sys/class/net/$ech0/carrier | grep 0)
      if [ -n "$linkdown" ] && [ "$active" == "yes" ]; then
          active="no"
          msgdown="BBA Mode: Ethernet link_down/disconnection detected in the last minute"
          echo $msgdown ; logger $msgdown
          sleep 12
		  clean_session
      fi

      sleep 6
    done
fi

exit 0
