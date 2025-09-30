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

echo "Uninstalling Classic and Remote BBA Mode...

"

# Stop and disable service
systemctl stop remote_bba_mode.service || true
systemctl disable remote_bba_mode.service || true
rm -f /etc/systemd/system/remote_bba_mode.service
systemctl daemon-reload

# Remove rsyslog rule and log file
rm -f /etc/rsyslog.d/10-iptables.conf
rm -f /var/log/iptables.log
systemctl restart rsyslog

# Remove scripts
rm -r /home/pi/dreampi/bba_mode

echo "Uninstallation complete.
"
