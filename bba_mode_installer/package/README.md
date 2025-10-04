# bba-mode-for-dreampi 2.0
A tool that brigdes between Dreamcast LAN devices and DCNow integration

Dreamcast-Talk topic: "BBA Mode for DreamPi": https://www.dreamcast-talk.com/forum/viewtopic.php?f=3&t=16649

Release 1   - jun/2023, Release 1.2 - sep/2023 , Release 1.3 - jan/2024, Release 2.0 - sep/2025

## WHAT IS NEW?
- Classic BBA Mode (Hotspot): 100% Refactored / Reviewed
- Remote BBA Mode: See below


# Remote BBA Mode for Dreamcast

Description:
Remote BBA_Mode: Dreamcast uses RPI as Gateway and DNS Server to trigger DCNOW

This project monitors DNS traffic from a Dreamcast console using Raspberry Pi and triggers Dreamcast Now sessions automatically.

## Download direct to RaspberryPi
wget https://github.com/scrivanidc/bba-mode-for-dreampi/raw/refs/heads/main/bba_mode_installer.zip

## Installation
```bash
unzip bba_mode_installer.zip
cd bba_mode_installer
./install.sh
```

## Uninstallation
```bash
./uninstall.sh
```

## Features
- It can work with custom/auto generated mac address to
   a different DCNow profile, check bba_mode menu, option 5
- Acts only when DreamPi Modem Service is not running,
   unplugging the usb modem or stopping the service.
- DreamPi standard service restart if you plug the modem back in.
- Detects Dreamcast DNS queries via iptables logging
- Starts and stops Dreamcast Now sessions based on traffic
- Automatically disables monitoring if `dreampi.service` is active
- Logs DNS and Dreamcast traffic to `/var/log/iptables.log`

## What should I do now?

Context:
You have a BBA and want your session visible on the Dreamcast Now website.

Explanation of how Remote BBA Mode works:
1. It's a service/utility that runs on the DreamPi (RaspberryPi).
2. It only monitors connections if "Traditional Modem Mode" is not running. (No impact on normal DreamPi use). This is intentional.
3. To use it as a Dreamcast Now agent for the BBA, you must first remove the USB modem. This is the signal and action that activates Remote BBA Mode.
4. In your Dreamcast game, for example, Q3A, PSO, Navigation, or any other BBA-compatible game, you must set the Raspberry Pi's IP as the Gateway and DNS Server. That's all. If you set the fixed configuration in the XDP Browser or similar once, it should stay in effect permanently.

Example:
```
Before:
IP: 192.168.0.30
Mask: 255.255.255.0
Gateway 192.168.0.1
DNS1 192.168.0.1
DNS2 46.101.91.123

After:
IP: 192.168.0.30
Mask: 255.255.255.0
Gateway: RaspberryPi IP, example 192.168.0.9
DNS1: RaspberryPi IP, example 192.168.0.9
DNS2: 46.101.91.123 (DreamPi DNS as backup)
```

5. After connecting, you should be able to see your Dreamcast Now session. If there is no activity for 1 minute, the session will be terminated. The monitoring cycle is terminated and the monitoring cycle restarts.
   
  <br>  
  
Go ahead and try it!

  <br>  

Command-line service validation
Practical commands:
```
journalctl -u remote_bba_mode.service -f (Service execution information)
sudo systemctl status remote_bba_mode.service (Service status)
sudo systemctl stop remote_bba_mode.service (Stop the service)
sudo systemctl restart remote_bba_mode.service (Restart the service)
tail -f /var/log/syslog (General system log)
```

  <br>  
Classic BBA Mode, which connects the BBA to the RPI's RJ45 port and uses it as a Wi-Fi station, still relevant, and is updated/refactored.

  <br> 
.
<img width="812" height="675" alt="bba_mode" src="https://github.com/user-attachments/assets/a375ca0f-0db9-4956-a4c8-6f6493562182" />
