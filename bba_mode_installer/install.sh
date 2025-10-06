#!/bin/bash

# BBA Mode tool written by scrivanidc@gmail.com
# -------------------------------------------------------------------------
# We are living our best Dreamcast Lives
# -------------------------------------------------------------------------
# Rev1.1 - jun/2023 - Rev1.2 sep/2023 - Rev.1.3 jan/2024 - Rev.2.0 Sep/2025

cd package/

echo "
Installing/Updating Remote BBA Mode..."
mkdir -p /home/pi/dreampi/bba_mode

echo "Copy scripts"
cp remote_bba_mode.py /home/pi/dreampi/bba_mode/
cp bba* /home/pi/dreampi/bba_mode/

echo "Copy systemd service"
sudo cp remote_bba_mode.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable remote_bba_mode.service
sudo systemctl start remote_bba_mode.service

echo "Configure rsyslog"
sudo cp 10-iptables.conf /etc/rsyslog.d/
sudo touch /var/log/iptables.log
sudo chmod 666 /var/log/iptables.log
sudo systemctl restart rsyslog

echo "Installation/Update complete. Service is running.

----------------------------------------------------------------------
Remote BBA Mode acts just when you stop dreampi
service or unplug usb modem.

If modem is plugged, DreamPi restarts
Dreamcast uses RPi as Gateway and DNS Server

Dreamcast BBA settings example:
IP:      192.168.x.20 - your regular one
Subnet:  255.255.255.0
Gateway: 192.168.0.5 - RaspberryPi [IP Address]
DNS1:    192.168.0.5 - RaspberryPi [IP Address]
DNS2: Same as DNS1 or your regular one

Your RPi IP is:"
hostname -I | awk '{print $1}' | xargs -I{} echo -e "\e[1;32m{}\e[0m"
echo "
It calls Remote because you connect your DC direct
to any router as usual and will communicate
with RPi to start and stop DCNow sessions
with the correct game identification.
Naturally it depends on the RPi being active.

Practical command: journalctl -u remote_bba_mode.service -f
----------------------------------------------------------------------

Next is: Classic BBA Mode, which connects the BBA to the RPI's RJ45 port and uses it as a Wi-Fi station, still relevant, and is updated/refactored.
"
sleep 3
echo "Installing/Updating Classic BBA Mode...
Remove old version files"
sleep 1
sudo rm -f /home/pi/bba_mode.sh 2> /dev/null
sudo rm -f /home/pi/eth_route.sh 2> /dev/null
sudo rm -f /home/pi/dreampi/bba* 2> /dev/null
sleep 1
echo "Give execution permission to bash files"
chmod +x /home/pi/dreampi/bba_mode/*.sh
sleep 1
echo "Creat symbolic link: bba_mode"
sudo rm -f /usr/local/bin/bba_mode 2> /dev/null
sudo ln -s /home/pi/dreampi/bba_mode/bba_mode.sh /usr/local/bin/bba_mode
sleep 1
echo "Installation/Update complete.

Note: Classic BBA Mode (hotspot) start command has changed:
FROM: ./bba_mode.sh
at /home/pi/

TO: bba_mode
at any place"

exit 0
