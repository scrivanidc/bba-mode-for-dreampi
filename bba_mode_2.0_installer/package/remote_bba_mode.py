# -*- coding: utf-8 -*-
import subprocess
import time
import re
import signal
import sys
import logging
import logging.handlers
import glob
from bba_dcnow import DreamcastNowService

# Remote BBA Mode tool written by scrivanidc@gmail.com - sep/2025
# ---------------------------------------------------------------
# We are living our best Dreamcast Lives
# ---------------------------------------------------------------

DNS_PORT = 53
LOG_FILE = "/var/log/iptables.log"
CHECK_INTERVAL = 5
TIMEOUT = 60
SERVICE_DEPENDENCY = "dreampi.service"

running = True
active_ip = None
session = None
dns_rule_applied = False
traffic_rule_applied = False
session_closed = False
last_traffic_time = None
last_traffic_line = None
restart_dreampi = 0

logger = logging.getLogger("remote_bba_mode")
logger.setLevel(logging.INFO)
handler = logging.StreamHandler(sys.stdout)
formatter = logging.Formatter("%(message)s")
handler.setFormatter(formatter)
logger.addHandler(handler)

def is_dreampi_active():
    try:
        output = subprocess.check_output(["systemctl", "is-active", SERVICE_DEPENDENCY]).strip()
        return output
    except subprocess.CalledProcessError as e:
        return e.output.strip()

def setup_iptables_logging():
    subprocess.call([
        "iptables", "-A", "INPUT", "-p", "udp", "--dport", str(DNS_PORT),
        "-j", "LOG", "--log-prefix", "DNS_QUERY: "
    ])
    global dns_rule_applied
    dns_rule_applied = True
    clean_logfile()
    logger.info("Start Monitoring DNS Traffic - Remote BBA_MODE.")

def clean_logfile():
    try:
        with open(LOG_FILE, "w") as f:
            f.write("")
        logger.info("iptables log cleared.")
    except Exception as e:
        logger.info("Error clearing iptables log: %s" % e)

def cleanup_iptables_logging():
    subprocess.call([
        "iptables", "-D", "INPUT", "-p", "udp", "--dport", str(DNS_PORT),
        "-j", "LOG", "--log-prefix", "DNS_QUERY: "
    ])
    if active_ip and traffic_rule_applied:
        subprocess.call([
            "iptables", "-D", "FORWARD", "-s", active_ip,
            "-j", "LOG", "--log-prefix", "DC_TRAFFIC: "
        ])
    logger.info("iptables rules removed.")
    logger.info("Stop Monitoring DNS Traffic - Remote BBA_MODE.")

def get_recent_ips(prefix, lines=100):
    try:
        with open(LOG_FILE, "r") as f:
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
        with open(LOG_FILE, "r") as f:
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
    if session:
        session.go_offline()

def monitor_dns_activity():
    global active_ip, session, dns_rule_applied, traffic_rule_applied, session_closed, last_traffic_time, last_traffic_line, restart_dreampi
    while running:
        if is_dreampi_active() == "active":
            if dns_rule_applied:
                cleanup_iptables_logging()
                dns_rule_applied = False
            if active_ip:
                session.go_offline()
                session_closed = True
                active_ip = None
                session = None
            time.sleep(CHECK_INTERVAL*2)
            continue
        elif not dns_rule_applied:
            setup_iptables_logging()

        now = time.time()

        if not active_ip:
            dns_sources = get_recent_ips("DNS_QUERY:", lines=100)
            for ip in dns_sources:
                if ip != active_ip:
                    active_ip = ip
                    last_traffic_time = now
                    logger.info("DNS query detected from %s. Starting Dreamcast Now session." % ip)
                    try:
                        session = DreamcastNowService()
                        session.go_online("")
                    except Exception as e:
                        logger.info("Error starting Dreamcast Now session: %s" % e)
                    subprocess.call([
                        "iptables", "-A", "FORWARD", "-s", active_ip,
                        "-j", "LOG", "--log-prefix", "DC_TRAFFIC: "
                    ])
                    traffic_rule_applied = True
                    session_closed = False
                    time.time()
                    break

        elif active_ip:
            current_line = get_last_traffic_line(active_ip)
            if current_line and current_line != last_traffic_line:
                last_traffic_line = current_line
                last_traffic_time = now

            elif now - last_traffic_time > TIMEOUT:
                logger.info("No traffic change from %s for %d seconds. Ending session." % (active_ip, TIMEOUT))
                try:
                    session.go_offline()
                except Exception as e:
                    logger.info("Error ending Dreamcast Now session: %s" % e)
                subprocess.call([
                    "iptables", "-D", "FORWARD", "-s", active_ip,
                    "-j", "LOG", "--log-prefix", "DC_TRAFFIC: "
                ])
                session_closed = True
                active_ip = None
                session = None
                traffic_rule_applied = False
                last_traffic_time = None
                clean_logfile()

        if glob.glob("/dev/ttyACM*") and is_dreampi_active() == "failed" and restart_dreampi <= CHECK_INTERVAL:
               restart_dreampi += 1
               logger.info("USB Modem detected - Restarting DreamPi Service.")
               subprocess.call(["systemctl", "start", SERVICE_DEPENDENCY])

        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    logger.info("Starting Dreamcast DNS monitor...")
    signal.signal(signal.SIGTERM, signal_handler)
    try:
        monitor_dns_activity()
    finally:
        cleanup_iptables_logging()
        if session:
            session.go_offline()

