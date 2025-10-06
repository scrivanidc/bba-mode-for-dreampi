# -*- coding: utf-8 -*-
import subprocess
import time
import re
import signal
import sys
import logging
import logging.handlers
import glob
import os
import socket
import requests
import uuid
import shlex
import bba_dcnow_config
from bba_dcnow import DreamcastNowService

# Remote BBA Mode tool written by scrivanidc@gmail.com - sep/2025
# ---------------------------------------------------------------
# We are living our best Dreamcast Lives
# ---------------------------------------------------------------

DNS_PORT = 53
IPTABLES_LOG = "/var/log/iptables.log"
CHECK_INTERVAL = 3
TIMEOUT = 120
SERVICE_DEPENDENCY = "dreampi.service"

session = None
dcnow_on = False
running = True
active_ip = None
inactive_ip = None
dns_rule_applied = False
traffic_rule_applied = False
session_closed = True
last_traffic_time = None
last_traffic_line = None
restart_dreampi = 0

version_file = "/home/pi/dreampi/bba_mode/bba_version.txt"
log_file = "/home/pi/dreampi/bba_mode/bba_mode.log"
script_url= "https://script.google.com/macros/s/AKfycbxQJB5SbjWumGdfukCEmV_fqU4BBUwcbgmxWWtKwBOOjldruw5sL6x5FGqT2XOzCbFh/exec"
version_url = "https://raw.githubusercontent.com/scrivanidc/bba-mode-for-dreampi/main/bba_mode_installer/package/bba_version.txt"
update_url = "https://raw.githubusercontent.com/scrivanidc/bba-mode-for-dreampi/main/bba_mode_installer/package/bba_update.txt"
zip_url = "https://raw.githubusercontent.com/scrivanidc/bba-mode-for-dreampi/main/bba_mode_installer.zip"
zip_file = "/tmp/bba_mode_installer.zip"
extract_dir = "/tmp/bba_mode_installer"

logger = logging.getLogger("remote_bba_mode")
logger.setLevel(logging.INFO)
handler = logging.StreamHandler(sys.stdout)
formatter = logging.Formatter("%(message)s")
handler.setFormatter(formatter)
logger.addHandler(handler)

def check_internet_connection():
    IP_ADDRESS_LIST = ["1.1.1.1", "8.8.8.8", "208.67.222.222"]
    port = 53
    timeout = 3
    for host in IP_ADDRESS_LIST:
        try:
            socket.setdefaulttimeout(timeout)
            socket.socket(socket.AF_INET, socket.SOCK_STREAM).connect((host, port))
            return True
        except socket.error:
            pass
    return False

def get_location():
    try:
        response = requests.get("https://ipinfo.io/json", timeout=5)
        data = response.json()
        country = data.get("country", "unknown")
        city = data.get("city", "unknown")
        return country, city
    except:
        return "unknown", "unknown"
        
def get_or_create_uuid(log_file):
    try:
        if os.path.exists(log_file):
            with open(log_file, "r") as f:
                for line in f:
                    if line.startswith("UUID:"):
                        current_uuid = line.strip().split("UUID:")[1].strip()
                        print("UUID: {}".format(current_uuid))
                        return current_uuid

        new_uuid = str(uuid.uuid4())
        with open(log_file, "r") as f:
            content = f.read()
        with open(log_file, "w") as f:
            f.write("UUID: {}\n".format(new_uuid))
            f.write(content)
            print("UUID (new): {}".format(new_uuid))
        return new_uuid

    except:
        new_uuid = str(uuid.uuid4())
        with open(log_file, "w") as f:
            f.write("UUID: {}\n".format(new_uuid))
            print("UUID (new): {}".format(new_uuid))
        return new_uuid

def get_local_version():
    try:
        with open(version_file, "r") as f:
            return f.read().strip()
    except:
        return "0.0"

def get_remote_version():
    try:
        return subprocess.check_output(["wget", "-qO-", version_url]).decode().strip()
    except:
        return get_local_version()
        
        
def do_post(desc, version):
    country, city = get_location()
    hostname = socket.gethostname()
    software = "bba_mode"
    try:
        requests.post(script_url, json={
            "hostname": hostname,
            "software": software,
            "version": version,
            "desc": desc,
            "country": country,
            "city": city,
            "uuid": uuid_value
        }, timeout=5)
        
        if os.path.exists(log_file):
            with open(log_file, "a") as f:
                f.write("Version {} - {} at {}\n".format(version, desc, time.strftime("%Y-%m-%d %H:%M:%S")))
                
        print("Version {} successfully - {}.".format(version, desc))
        
    except Exception as e:
        print("Failed to {} version {}: {}".format(desc, version, e))


def control_version():

    while not check_internet_connection():
        print("Waiting for internet connection...")
        time.sleep(3)
        
    update_flag = subprocess.check_output(["wget", "-qO-", update_url]).decode().strip()
    if update_flag.lower() != "yes":
        print("Update flag is disabled.")
        return

    global uuid_value, current_version
    uuid_value = get_or_create_uuid(log_file)
    current_version = get_local_version()
    
    desc = "register"

    already_logged = False

    if os.path.exists(log_file):
        with open(log_file, "r") as f:
            for line in f:
                if current_version in line:
                    already_logged = True
                    break
                    
    if not already_logged:
    
        do_post(desc, current_version)
        
    else:
        print("Version {} already registered previously.".format(current_version))
        
    check_for_update()
    
    
def check_for_update():

    remote_version = get_remote_version()
    desc = "update"
    
    if not remote_version:
        print("Could not retrieve remote version.")
        return

    if remote_version == current_version:
        print("BBA Mode is up to date (v{}).".format(current_version))
        return

    print("New version available: {} (local: {})".format(remote_version, current_version))

    try:
        if os.path.exists(zip_file):
            os.remove(zip_file)
        if os.path.exists(extract_dir):
            subprocess.call(["rm", "-rf", extract_dir])

        print("Downloading update package...")
        subprocess.call(["wget", "-O", zip_file, zip_url])
        subprocess.call(["unzip", "-o", zip_file, "-d", "/tmp/"])

        install_path = os.path.join(extract_dir, "install.sh")
        if os.path.isfile(install_path):
            print("Running installer...")
            
            try:
                subprocess.call(["sudo", "-u", "pi", "bash", "install.sh"], cwd=extract_dir)
                with open(version_file, "w") as f:
                    f.write(remote_version)
                print("Update complete.")
                
                do_post(desc, remote_version)
                
            except Exception as e:
                print("Installation failed: {}".format(e))
        else:
            print("Installer not found.")
    except Exception as e:
        print("Update failed: {}".format(e))
        
        
def is_dreampi_active():
    try:
        output = subprocess.check_output(["systemctl", "is-active", SERVICE_DEPENDENCY]).strip()
        return output
    except subprocess.CalledProcessError as e:
        return e.output.strip()

def start_iptables_input():
    try:
        subprocess.call([
            "iptables", "-A", "INPUT", "-p", "udp", "--dport", str(DNS_PORT),
            "-j", "LOG", "--log-prefix", "DNS_QUERY: "
        ])
    except subprocess.CalledProcessError as e:
        logger.info("Error trying to add DNS_QUERY rule: {} -> {}".format(e))
        
    global dns_rule_applied
    dns_rule_applied = True
    clean_logfile()
    logger.info("Start Monitoring DNS Traffic - Remote BBA_MODE.")

def start_iptables_forward(ip):
    try:
        subprocess.call([
            "iptables", "-A", "FORWARD", "-s", ip,
            "-j", "LOG", "--log-prefix", "DC_TRAFFIC: "
        ])
    except subprocess.CalledProcessError as e:
        logger.info("Error trying to remove DC_TRAFFIC rule: {} -> {}".format(e))        
    
def stop_iptables_forward():
    output = subprocess.check_output(["iptables-save"]).decode()
    for line in output.splitlines():
        if "DC_TRAFFIC:" in line:
            rule = line.replace("-A", "-D", 1)
            logger.info("Removing rule: {}".format(rule))
            try:
                subprocess.call(["iptables"] + shlex.split(rule))
            except subprocess.CalledProcessError as e:
                logger.info("Error trying to remove rule: {} -> {}".format(rule, e))

def clean_logfile():
    try:
        with open(IPTABLES_LOG, "w") as f:
            f.write("")
        logger.info("iptables log cleared.")
    except Exception as e:
        logger.info("Error clearing iptables log: %s" % e)

def cleanup_iptables_logging():
    try:
        subprocess.call([
            "iptables", "-D", "INPUT", "-p", "udp", "--dport", str(DNS_PORT),
            "-j", "LOG", "--log-prefix", "DNS_QUERY: "
        ])
    except subprocess.CalledProcessError as e:
        logger.info("Error trying to remove DNS_QUERY rule: {} -> {}".format(e))

    stop_iptables_forward()
       
    logger.info("iptables rules removed.")
    logger.info("Stop Monitoring DNS Traffic - Remote BBA_MODE.")

def get_recent_ips(prefix, lines=100):
    try:
        with open(IPTABLES_LOG, "r") as f:
            logs = f.readlines()[-lines:]
        sources = set()
        for line in logs:
            if prefix in line:
                match = re.search(r"SRC=([\d\.]+)", line)
                if match:
                    ip = match.group(1)
                    if ip != "127.0.0.1":
                        sources.add(ip)
        return sources
    except Exception as e:
        logger.info("Error reading logs: %s" % e)
        return set()

def get_last_traffic_line(ip):
    try:
        with open(IPTABLES_LOG, "r") as f:
            logs = f.readlines()[-100:]
        for line in reversed(logs):
            if "DC_TRAFFIC:" in line and ("SRC=%s" % ip) in line:
                return line.strip()
        return None
    except Exception as e:
        logger.info("Error retrieving last traffic line: %s" % e)
        return None

def signal_handler(sig, frame):
    global running
    running = False
    logger.info("Terminating service...")
   
def start_dcnow():
    global session, dcnow_on
    stop_dcnow()
    if not dcnow_on:
        try:
            bba_dcnow_config.start()
            session = DreamcastNowService()
            session.go_online()
            dcnow_on = True
        except Exception as e:
            logger.info("Error starting Dreamcast Now session: %s" % e)

def stop_dcnow():
    global session, dcnow_on
    if dcnow_on:
        try:
            if session:
                bba_dcnow_config.stop()
                session.go_offline()
                session = None
                dcnow_on = False
        except Exception as e:
            logger.info("Error ending Dreamcast Now session: %s" % e)
    
    

def monitor_dns_activity():
    global active_ip, inactive_ip, dns_rule_applied, traffic_rule_applied, session_closed, last_traffic_time, last_traffic_line, restart_dreampi
    while running:
        if is_dreampi_active() == "active":
            stop_dcnow()
            if dns_rule_applied:
                cleanup_iptables_logging()
                dns_rule_applied = False
            if active_ip or inactive_ip:
                session_closed = True
                active_ip = None
                inactive_ip = None
            time.sleep(CHECK_INTERVAL*2)
            continue
        elif not dns_rule_applied:
            start_iptables_input()

        now = time.time()

        if dns_rule_applied:
            dns_sources = get_recent_ips("DNS_QUERY:", lines=100)
            for ip in dns_sources:
                if ip != active_ip and ip != inactive_ip and session_closed:

                    last_traffic_time = now
                    logger.info("DNS query detected from %s. Starting Dreamcast Now session." % ip)
                    
                    start_dcnow()
                    
                    if traffic_rule_applied:
                        stop_iptables_forward()

                    start_iptables_forward(ip)
                    traffic_rule_applied = True
                    session_closed = False
                    active_ip = ip
                    inactive_ip = None
                    break

        if active_ip:
            current_line = get_last_traffic_line(active_ip)
            if current_line and current_line != last_traffic_line:
                last_traffic_line = current_line
                last_traffic_time = now

            elif now - last_traffic_time > TIMEOUT:
                logger.info("No traffic change from %s for %d seconds. Ending session." % (active_ip, TIMEOUT))
                stop_dcnow()
                inactive_ip = active_ip
                              
                session_closed = True
                active_ip = None
                last_traffic_time = None
                clean_logfile()
                
        if inactive_ip:
            current_line = get_last_traffic_line(inactive_ip)
            if current_line and current_line != last_traffic_line:
                last_traffic_line = current_line
                last_traffic_time = now
                
                logger.info("Traffic detected from %s. Starting Dreamcast Now session." % inactive_ip)
                start_dcnow()
                active_ip = inactive_ip
                inactive_ip = None
                session_closed = False
        
        if glob.glob("/dev/ttyACM*") and is_dreampi_active() == "failed" and restart_dreampi <= CHECK_INTERVAL*2:
               restart_dreampi += 1
               logger.info("USB Modem detected - Restarting DreamPi Service. {}/{}".format(restart_dreampi,CHECK_INTERVAL*2))
               stop_dcnow()
               subprocess.call(["systemctl", "start", SERVICE_DEPENDENCY])

        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    logger.info("Starting Dreamcast DNS monitor...")
    signal.signal(signal.SIGTERM, signal_handler)
    try:
        control_version()
        monitor_dns_activity()
    finally:
        cleanup_iptables_logging()
        stop_dcnow()

