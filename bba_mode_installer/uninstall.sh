#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

# BBA Mode tool written by scrivanidc@gmail.com
# -------------------------------------------------------------------------
# We are living our best Dreamcast Lives
# -------------------------------------------------------------------------
# Rev1.1 - jun/2023 - Rev1.2 sep/2023 - Rev.1.3 jan/2024 - Rev.2.0 Sep/2025

echo "
Uninstalling Classic and Remote BBA Mode...
"

echo "Stop and disable service"
systemctl stop remote_bba_mode.service || true 2> /dev/null
systemctl disable remote_bba_mode.service || true 2> /dev/null
rm -f /etc/systemd/system/remote_bba_mode.service 2> /dev/null
systemctl daemon-reload

echo "Remove rsyslog rule and log file"
rm -f /etc/rsyslog.d/10-iptables.conf 2> /dev/null
rm -f /var/log/iptables.log 2> /dev/null
systemctl restart rsyslog

echo "Remove scripts"
rm /usr/local/bin/bba_mode 2> /dev/null
rm -rf /home/pi/dreampi/bba_mode 2> /dev/null

echo "
Uninstallation complete."
