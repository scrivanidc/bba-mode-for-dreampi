#!/bin/bash
#Minutes to Start BBA Mode
min=$2

# BBA Mode tool written by scrivanidc@gmail.com - jun/2023
# --------------------------------------------------------
# We are living our best Dreamcast Lives
# --------------------------------------------------------
# Rev1.0 - jun/2023 - Rev1.2 sep/2023 - Rev.1.3 jan/2024

#BBA Mode tool files locations
bba_modesh="/home/pi/bba_mode.sh"
eth_routesh="/home/pi/eth_route.sh"
bba_binsh="/home/pi/dreampi/bba_bin.sh"
bba_binpy="/home/pi/dreampi/bba_bin.py"
#bba_bin* files need to be in Dreampi bin files >
#because imports dcnow.py/config_server.py

chk='^[0-9]+$'

echo "------------------------------------------------------------"
echo "Execution Options"
echo "./bba_mode.sh --help   > Parameters help"
echo ""
echo "Welcome to BBA Mode tool"
if [ -z "$1" ]; then
echo " Please type the number of your choice"
echo ""
echo " 0  > Start BBA Mode immediately"
echo " 1  > Start BBA Mode after a wait time"
echo " 2  > Start Manual List Dreamcast Now"
echo " 3  > Enable on every startup after a wait time"
echo " 4  > Disable from every startup"
echo "------------------------------------------------------------"
    read -p 'Option: ' option
    if ! [[ $option =~ $chk ]]; then echo "Not a number"; fi
else
    option=$1
fi

start="Starting BBA Mode ..."
if [[ "$option" == 0 || "$option" == 1 || "$option" == 2 ]]; then echo ""; echo $start; fi
echo ""
logger $start

#install tcpdump if is not installed yet.
tcpdump_check=$(command -v tcpdump)
if [ -z "$tcpdump_check" ]; then
    echo "First time running: apt update and tcpdump will be installed once"
    sudo apt update
    sudo apt-get install -qq -y tcpdump 2> /dev/null
fi

if [ "$option" == 1 ]; then
    if [ -z $min ]; then
        echo "Type the number of minutes to start or press enter for default time 10"
        read -p '> '  min
        if [ -z "$min" ]; then min=10; fi
    fi

    wait_msg="BBA Mode starts in $min min if a modem connection is not made"
    echo ""
    echo $wait_msg
    echo ""
    logger $wait_msg

    let sec=$min*60
    sleep $sec
    log1=$(tail -n 900 /var/log/syslog | awk -v d1="$(date --date="-$min min" "+%b %_d %H:%M")" -v d2="$(date "+%b %_d %H:%M")" '$0 > d1 && $0 < d2 || $0 ~ d2' | grep "Heard")
    log2=$(tail -n 900 /var/log/messages | awk -v d1="$(date --date="-$min min" "+%b %_d %H:%M")" -v d2="$(date "+%b %_d %H:%M")" '$0 > d1 && $0 < d2 || $0 ~ d2' | grep "Heard")

    if [ -z "$log1" ] && [ -z "$log2" ]; then
        logger "No modem connection for $min minute(s)"
    else
        logger "BBA Mode canceled due to detected modem connection"
        exit 0
    fi
fi

if [ "$option" == 0 ] || [ "$option" == 1 ]; then

    #kill sessions of me older than this one
    sudo kill -9 $(ps aux | grep bba | awk '{ print $2 }' | head -n -3) 2>/dev/null

    ech0=$(grep -m 1 "eth=" "$eth_routesh" | cut -d '"' -f 2)
    ech1=$(grep -m 1 "dhcp_range_start=" "$eth_routesh" | cut -d '"' -f 2)
    ech2=$(grep -m 1 "netmask=" "$eth_routesh" | cut -d '"' -f 2)
    ech3=$(grep -m 1 "ip_address=" "$eth_routesh" | cut -d '"' -f 2)
    ech4=$(grep -m 1 "dns_server=" "$eth_routesh" | cut -d '"' -f 2)

    txt="BBA Mode Additional Instructions: Make sure your connection is as needed for this routing.
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
and is set to share present wi-fi over the onboard ethernet port
edit the file if you need a different IP pattern or share ethernet to ethernet(extra usb lan)

This mode does not impact the standard dial-up mode, as it uses a customized/separate file
of dnsmasq and is prepared to undo unwanted actions.

From now on the modem function is turned off until the next reboot."

    #Start eth sharing route
    sudo bash -c "$eth_routesh"
    active="no"
    logger "Set on DC> IP=$ech1 Netmask=$ech2 Gateway/DHCPServer=$ech3 DNS1=$ech3 DNS2=$ech4"
    logger "Edit $eth_routesh Router Script File if you need a different IP pattern "
    echo "$txt"
    echo ""
    echo "Starting BBA Connection Analysis soon ..."
    sleep 15

    while true
    do
      echo "BBA Connection Analysis ..."

      linkup=$(cat /sys/class/net/$ech0/carrier | grep 1)
      if [ -n "$linkup" ] && [ "$active" == "no" ]; then
          active="yes"
          msgup="BBA Mode: Ethernet link_up/connection detected"
          echo $msgup
          logger $msgup
          sudo bash -c "$bba_binsh 1 $eth_routesh $bba_binpy"
          sleep 15
      fi

      linkdown=$(cat /sys/class/net/$ech0/carrier | grep 0)
      if [ -n "$linkdown" ] && [ "$active" == "yes" ]; then
          active="no"
          msgdown="BBA Mode: Ethernet link_down/disconnection detected in the last minute"
          echo $msgdown
          logger $msgdown
          sudo bash -c "$bba_binsh 0" &
          sleep 15
      fi

      sleep 3
    done
fi

if [ "$option" == 2 ]; then
    #kill sessions of me older than this one
    sudo kill -9 $(ps aux | grep bba | awk '{ print $2 }' | head -n -3) 2>/dev/null
    logger "BBA Mode: Manual List Dreamcast Now"
    sudo bash -c "$bba_binsh 2 $eth_routesh $bba_binpy"
    exit 0
fi

if [ "$option" == 3 ]; then
echo "-----------------------------------------------------------------------------"
echo "Welcome to BBA Mode Enable tool"
echo ""
echo "How many minutes do you want BBA Mode to start after turning on the system?"
echo "Type the number or press enter for default time 10"
read -p '> ' v

if [ -z $v ]; then v=10; fi

if ! [[ $v =~ $chk ]]; then
  echo "$v: Not a number"
  echo "Default value 10 selected"
  v=10
fi

sudo sed -i '/dnsmasq/d;/bba_mode/d;/^exit/i rm -f /etc/dnsmasq.d/custom* 2> /dev/null\nbash -c "'$bba_modesh' 1 '$v'" $>/tmp/bba.log &\n' /etc/rc.local
sudo sed -i ':L;N;s/^\n$//;t L' /etc/rc.local

echo ""
echo "BBA Mode has been successfully enabled to start $v after startup. (rc.local)"
echo "-----------------------------------------------------------------------------"
 exit 0
fi

if [ "$option" == 4 ]; then
echo "------------------------------------------------------------"
echo "Welcome to BBA Mode Disable tool"
echo ""
echo "Removing BBA Mode from system startup (rc.local)..."
echo ""

sudo sed -i '/bba_mode/d' /etc/rc.local
sudo sed -i ':L;N;s/^\n$//;t L' /etc/rc.local

echo "BBA Mode has been successfully disabled from system startup."
echo "------------------------------------------------------------"
 exit 0
fi

if [ "$1" == "--help" ] || [ -z "$1" ] ; then
    if [ -z "$1"  ]; then
        echo "No option selected, please try again"
        echo "You can also call the script passing parameters"
        echo ""
    fi
    echo "./bba_mode.sh    > Start BBA Mode user friendly"
    echo "./bba_mode.sh 0  > Start BBA Mode immediately"
    echo "./bba_mode.sh 1  > Start BBA Mode after a wait time"
    echo "./bba_mode.sh 2  > Start Manual List Dreamcast Now"
    echo "./bba_mode.sh 3  > Enable on every startup after a wait time"
    echo "./bba_mode.sh 4  > Disable from every startup"
    echo "------------------------------------------------------------"
    exit 0
fi

if ! [[ "$1" =~ $chk ]]; then echo "Invalid parameter"; fi
echo ""
exit 0
