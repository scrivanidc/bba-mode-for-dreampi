#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

# BBA Mode tool written by scrivanidc@gmail.com
# -------------------------------------------------------------------------
# We are living our best Dreamcast Lives
# -------------------------------------------------------------------------
# Rev1.1 - jun/2023 - Rev1.2 sep/2023 - Rev.1.3 jan/2024 - Rev.2.0 Sep/2025

cd package/

echo "Installing/Updating Remote BBA Mode...

"
mkdir /home/pi/dreampi/bba_mode

# Copy script
cp remote_bba_mode.py /home/pi/dreampi/bba_mode/

# Copy systemd service
cp remote_bba_mode.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable remote_bba_mode.service
systemctl start remote_bba_mode.service

# Configure rsyslog
cp 10-iptables.conf /etc/rsyslog.d/
touch /var/log/iptables.log
chmod 666 /var/log/iptables.log
systemctl restart rsyslog


echo "Installation/Update complete. Service is running.

-------------------------------------------------------
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
-----------------------------------------------------

"

echo "Installing/Updating Classic BBA Mode...
"

rm -f /home/pi/bba_mode.sh 2> /dev/null
rm -f /home/pi/eth_route.sh 2> /dev/null
rm -f /home/pi/dreampi/bba* 2> /dev/null
cp bba* /home/pi/dreampi/bba_mode/
chmod +x /home/pi/dreampi/bba*.sh
ln -s /home/pi/dreampi/bba_mode/bba_mode.sh /usr/local/bin/bba_mode

echo "Installation/Update complete.

Note: Classic BBA Mode (hotspot) start command has changed:

FROM: ./bba_mode.sh
at /home/pi/

TO: bba_mode
at any place

Finish."
