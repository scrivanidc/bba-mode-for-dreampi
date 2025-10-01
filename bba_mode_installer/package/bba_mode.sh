#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

#Minutes to Start BBA Mode
min=$2

# BBA Mode tool written by scrivanidc@gmail.com
# -------------------------------------------------------------------------
# We are living our best Dreamcast Lives
# -------------------------------------------------------------------------
# Rev1.1 - jun/2023 - Rev1.2 sep/2023 - Rev.1.3 jan/2024 - Rev.1.4 Sep/2025

#BBA Mode tool files locations
bba_modesh="/home/pi/dreampi/bba_mode/bba_mode.sh"
eth_routesh="/home/pi/dreampi/bba_mode/bba_route.sh"
bba_binsh="/home/pi/dreampi/bba_mode/bba_bin.sh"
bba_binpy="/home/pi/dreampi/bba_mode/bba_bin.py"
bba_mac="/home/pi/dreampi/bba_mac.txt"
#files need to be in Dreampi bin directory

chk='^[0-9]+$'

clean_session() {
  echo "Stopping Remote BBA Mode Service  ..."
  systemctl stop remote_bba_mode
  echo "Stopping Standard DreamPi Service ..."
  systemctl stop dreampi
  killall -q tcpdump 2>/dev/null
  killall -q python2.7 2>/dev/null
  #Just to make sure
  pgrep -f bba_bin | sudo xargs kill -9 2>/dev/null
  pgrep -f tcpdump | sudo xargs kill -9 2>/dev/null
  pgrep -f python | sudo xargs kill -9 2>/dev/null
  echo "------------------------------------------------------------"
}

#remote_status = $(systemctl is-active remote_bba_mode | xargs -I{} echo -e "\e[1;32m{}\e[0m")

echo "------------------------------------------------------------
Execution Options
bba_mode --help   > Parameters help

> Welcome to BBA Mode tool <

Classic BBA Mode (hotspot): 0,1,2,3"
device=$(grep -m 1 "eth=" "$eth_routesh" | cut -d '"' -f 2)
classic_status=$(ip -o -4 addr show $device | awk '{print $4}' | cut -d/ -f1)
if [ "$classic_status" == "192.168.2.1" ]; then
    echo -e "Status: \e[1;32mActive\e[0m"
else
    echo -e "Status: \e[1;31mInactive\e[0m"
fi

echo "
Remote BBA Mode: 6,7"
remote_status=$(systemctl is-active remote_bba_mode)
if [ "$remote_status" == "active" ]; then
    echo -e "Status: \e[1;32m${remote_status^}\e[0m"
else
    echo -e "Status: \e[1;31m${remote_status^}\e[0m"
fi

if [ -z "$1" ]; then
echo "
 Please type the number of your choice

 0  > Start BBA Mode immediately
 1  > Start BBA Mode after a wait time
 2  > Enable on every startup after a wait time
 3  > Disable from every startup
 4  > Start Manual List Dreamcast Now
 5  > Manage Custom Mac Address (DCNow Profile)
 6  > Start Remote BBA Mode Service
 7  > Stop Remote BBA Mode Service
 8  > Just exit
------------------------------------------------------------"
    read -p 'Option: ' option
    if [[ ! $option =~ $chk && -n $option ]]; then echo "Not a number"; fi
else
    option=$1
fi

#install tcpdump if is not installed yet.
tcpdump_check=$(command -v tcpdump)
if [ -z "$tcpdump_check" ]; then
    echo "First time running: apt update and tcpdump will be installed once"
    apt update
    apt-get install -qq -y tcpdump 2> /dev/null
fi

if [ "$option" == 1 ]; then
    if [ -z $min ]; then
        echo "Type the number of minutes to start or press enter for default time 10"
        read -p '> '  min
        if [ -z "$min" ]; then min=10; fi
		if ! [[ $min =~ $chk ]]; then echo "Not a number"; exit 0; fi
    fi

    wait_msg="BBA Mode starts in $min min if a modem connection is not made"
    echo ""
    echo $wait_msg
    echo "Press CTRL+C to cancel or wait for the chosen time"
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
    clean_session
	bash -c "$bba_binsh 0" | tee /tmp/bba.log &
    exit 0
fi

if [ "$option" == 2 ]; then
 echo "-----------------------------------------------------------------------------"
 echo "Welcome to BBA Mode Enable tool"
 echo ""
 echo "How many minutes do you want BBA Mode to start after turning on the system?"
 echo "Type the number or press enter for default time 10"
 read -p '> ' v
 
 if ! [[ $v =~ $chk ]]; then echo "Not a number"; exit 0; fi 
 if [ -z $v ]; then v=10; fi
 
 sed -i '/dnsmasq/d;/bba_mode/d;/^exit/i rm -f /etc/dnsmasq.d/custom* 2> /dev/null\nbash '$bba_modesh' 1 '$v' &\n' /etc/rc.local
 sed -i ':L;N;s/^\n$//;t L' /etc/rc.local
 
 echo ""
 echo "BBA Mode has been successfully enabled to start $v after startup. (rc.local)"
 echo "-----------------------------------------------------------------------------"
 exit 0
fi

if [ "$option" == 3 ]; then
 echo "------------------------------------------------------------"
 echo "Welcome to BBA Mode Disable tool"
 echo ""
 echo "Removing BBA Mode from system startup (rc.local)..."
 echo ""
 
 sed -i '/bba_mode/d' /etc/rc.local
 sed -i ':L;N;s/^\n$//;t L' /etc/rc.local
 
 echo "BBA Mode has been successfully disabled from system startup."
 echo "------------------------------------------------------------"
 exit 0
fi

if [ "$option" == 4 ]; then
    clean_session
    logger "BBA Mode: Manual List Dreamcast Now"

    echo "Manual List Autonomous Dreamcast Now Service - Starting ..."
    echo ""
    echo " 1 - Phantasy Star Online"
    echo " 2 - Quake III Arena"
    echo " 3 - 4x4 Evolution"
    echo " 4 - Aero Dancing Series"
    echo " 5 - Alien Front Online"
    echo " 6 - ChuChu Rocket"
    echo " 7 - Daytona USA"
    echo " 8 - DeeDee Planet"
    echo " 9 - Driving Strikers"
    echo "10 - F355 Challenge"
    echo "11 - Golf Shiyouyo 2"
    echo "12 - Hundred Swords"
    echo "13 - Internet Game Pack"
    echo "14 - Maximum Pool"
    echo "15 - Mobile Suit Gundam: Federation vs. Zeon"
    echo "16 - Monaco/POD/Speed Devils"
    echo "17 - Next Tetris, The"
    echo "18 - Ooga Booga"
    echo "19 - Outtriger"
    echo "20 - PBA Bowling"
    echo "21 - Planet Ring"
    echo "22 - Power Smash"
    echo "23 - Sega Tetris"
    echo "24 - Starlancer"
    echo "25 - Toy Racer"
    echo "26 - Worms World Party"
    echo "27 - Yakyuu Team de Asobou Net!"
    echo "28 - 2K Series: NBA 2K1"
    echo "29 - 2K Series: NBA 2K2"
    echo "30 - 2K Series: NCAA 2K2"
    echo "31 - 2K Series: NFL 2K1"
    echo "32 - 2K Series: NFL 2K2"
    echo "33 - DCPlaya"
    echo "34 - Web Browsing"
    echo "35 - Quake III Arena Custom Maps"
    echo "36 - Reboot and restart standard DreamPi (modem)"
    echo ""
    echo "Choose game number > "
    read n

    if ! [[ $n =~ $chk ]]; then
      echo "Not a number"
      exit 0
    fi

    if [[ $n -gt 36 ]]; then
      echo "Invalid option"
    elif [[ $n -eq 36 ]]; then
      reboot
    else
      echo ""
      python2.7 "$bba_binpy" "$n" --no-daemon &
      sleep 6
      echo "
Running in background

BBA Mode tool written by scrivanidc@gmail.com
------------------------------------------------------------
We are living our best Dreamcast Lives
------------------------------------------------------------"
    fi
    exit 0
fi

if [ "$option" == 5 ]; then
    echo "Manage Custom MAC Address (DCNow Profile)"

    # Create file if it doesn't exist
    [ ! -f "$bba_mac" ] && touch "$bba_mac"

    mac_=$(cat "$bba_mac" 2>/dev/null)

    # Function to validate MAC format
    is_valid_mac() {
        [[ "$1" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]
    }

    # Function to generate a fake MAC Address
    generate_mac() {
        od -An -N6 -tx1 /dev/urandom | tr -d ' \n' | sed 's/\(..\)/\1:/g; s/:$//' | tr 'a-f' 'A-F'
    }

    # If MAC is empty
    if [ -z "$mac_" ]; then
        echo "------------------------------------------------------------"
        echo "No custom MAC Address found"
        echo " 1  > Register my custom MAC Address"
        echo " 2  > Auto Generate and register a new custom MAC Address"
        echo " 3  > Exit"
        echo "------------------------------------------------------------"
        read -p 'Option: ' mac_o

        case "$mac_o" in
            1)
                read -p 'Enter your MAC Address (format XX:XX:XX:XX:XX:XX): ' mac_a
                if ! is_valid_mac "$mac_a"; then
                    echo "Invalid format"
                    exit 0
                fi
                echo "$mac_a" > "$bba_mac"
                echo "Successfully registered: $mac_a"
                ;;
            2)
                mac_a=$(generate_mac)
                echo "$mac_a" > "$bba_mac"
                echo "Successfully generated and registered: $mac_a"
                ;;
            *)
                echo "Exiting..."
                ;;
        esac
    fi

    # If MAC exists, is valid, and is active
	if [[ -n "$mac_" && ! "$mac_" =~ ^# ]] && is_valid_mac "$mac_"; then
        echo "------------------------------------------------------------"
        echo "Custom MAC Address is registered and active"
        echo "$mac_"
        echo " 11  > Deactivate registered custom MAC Address"
        echo " 12  > Generate and overwrite with a new custom MAC Address"
        echo " 13  > Delete registered custom MAC Address"
        echo " 14  > Exit"
        echo "------------------------------------------------------------"
        read -p 'Option: ' mac_o

        case "$mac_o" in
            11)
                sed -i '1s/^/#/' "$bba_mac"
                echo "Successfully deactivated: $(cat "$bba_mac")"
                ;;
            12)
                mac_a=$(generate_mac^^)
                echo "$mac_a" > "$bba_mac"
                echo "Successfully generated and registered: $mac_a"
                ;;
            13)
                > "$bba_mac"
                echo "Successfully deleted custom MAC Address"
                ;;
            *)
                echo "Exiting..."
                ;;
        esac
    fi

    # If MAC starts with #
    if [[ "$mac_" =~ ^# ]]; then
        echo "------------------------------------------------------------"
        echo "Custom MAC Address is registered but disabled"
        echo "${mac_#\#}"  # Show without #
        echo " 21  > Reactivate registered custom MAC Address"
        echo " 22  > Auto Generate and overwrite with a new custom MAC Address"
        echo " 23  > Delete registered custom MAC Address"
        echo " 24  > Exit"
        echo "------------------------------------------------------------"
        read -p 'Option: ' mac_o

        case "$mac_o" in
            21)
                sed -i 's/^#//' "$bba_mac"
                echo "Successfully reactivated: $(cat "$bba_mac")"
                ;;
            22)
                mac_a=$(generate_mac)
                echo "$mac_a" > "$bba_mac"
                echo "Successfully generated and registered: $mac_a"
                ;;
            23)
                > "$bba_mac"
                echo "Successfully deleted custom MAC Address"
                ;;
            *)
                echo "Exiting..."
                ;;
        esac
    fi
	if ! is_valid_mac "$mac_a"; then > "$bba_mac"; fi
	if ! [[ $mac_o =~ $chk ]]; then echo "Not a number"; fi
	echo "
BBA Mode is designed to use a custom MAC address in the Dreamcast Now profile, if registered, instead of the active network interface's MAC address.

This gives you the option of having a separate profile for BBA without interfering with the profile used for the modem connection.

Therefore, you should observe the new Unnamed profile and set up your new BBA nickname and Gravatar account."	
    exit 0
fi

if [ "$option" == 6 ]; then
 echo "Starting Remote BBA Mode Service"
 echo "Dreamcast uses RPI IP Address(below) as Gateway and DNS Server to trigger DCNOW."
 hostname -I | awk '{print $1}' | xargs -I{} echo -e "\e[1;32m{}\e[0m"
 systemctl start remote_bba_mode &
 exit 0
fi

if [ "$option" == 7 ]; then
 echo "Stopping Remote BBA Mode Service"
 systemctl stop remote_bba_mode &
 exit 0
fi

if [ "$option" == 8 ]; then
 echo "Exiting BBA Mode Menu"
 exit 0
fi

if [[ ! $option =~ $chk ]] || [ "$option" -gt 8 ]; then
    if [ -z $option ]; then echo "No option selected, please try again"; fi
	if [[ ! $option == '--help' && -n $option ]]; then
     echo ""
     echo "Invalid parameter"
	fi
	echo "
You can also call the script passing parameters

bba_mode    > Start BBA Mode user friendly
bba_mode 0  > Start BBA Mode immediately
bba_mode 1  > Start BBA Mode after a wait time
bba_mode 2  > Enable on every startup after a wait time
bba_mode 3  > Disable from every startup
bba_mode 4  > Start Manual List Dreamcast Now
bba_mode 5  > Manage Custom Mac Address (DCNow Profile)
bba_mode 6  > Start Remote BBA Mode Service
bba_mode 7  > Stop  Remote BBA Mode Service
------------------------------------------------------------"
fi
exit 0
