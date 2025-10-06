#!/usr/bin/env python

import atexit
import socket
import os
import logging
import logging.handlers
import sys
import time
import subprocess
import signal
import sh
import bba_dcnow_config

from bba_dcnow import DreamcastNowService
from datetime import datetime, timedelta

# BBA Mode tool written by scrivanidc@gmail.com
# ----------------------------------------------------------------------------------
# We are living our best Dreamcast Lives
# ----------------------------------------------------------------------------------
# Rev1.1 - jun/2023 - Rev1.2 sep/2023 - Rev.1.3 jan/2024 - Rev.2.0 Sep/2025
# ----------------------------------------------------------------------------------
# This is a modificated version of original Kazades dreampi.py structure
# All non usable elements where deleted
# DNS query function game based implemented
# BBA movements reading implemented
# DNS Injection "query[A]" + [TCPDUMP Reading URL] to ensure DCNOW Update
# Multiplayer or Browsing(BBA Portal) over DC+LAN are able to be detected on DCNOW
# Dreamcast Ethernet Devices:
# Broadbad Adapter HIT-0400 Realtek RTL8139C 10/100 Mbps 100Base-T
# LAN Adapter HIT-0300 Fujitsu MB86967 10/10 Mbps 10Base-T
# ----------------------------------------------------------------------------------

logger = logging.getLogger('bba_mode')

def check_internet_connection():
    """ Returns True if there's a connection """

    IP_ADDRESS_LIST = [
        "1.1.1.1",  # Cloudflare
        "1.0.0.1",
        "8.8.8.8",  # Google DNS
        "8.8.4.4",
    ]

    port = 53
    timeout = 3

    for host in IP_ADDRESS_LIST:
        try:
            socket.setdefaulttimeout(timeout)
            socket.socket(socket.AF_INET, socket.SOCK_STREAM).connect((host, port))
            return True
        except socket.error:
            pass
    else:
        logger.exception("No internet connection")
        return False

class Daemon(object):
    def __init__(self, pidfile, process):
        self.pidfile = pidfile
        self.process = process

    def daemonize(self):
        try:
            pid = os.fork()
            if pid > 0:
                sys.exit(0)

        except OSError:
            sys.exit(1)

        os.chdir("/")
        os.setsid()
        os.umask(0)

        try:
            pid = os.fork()
            if pid > 0:
                sys.exit(0)
        except OSError:
            sys.exit(1)

        atexit.register(self.delete_pid)
        pid = str(os.getpid())
        with open(self.pidfile, 'w+') as f:
            f.write("%s\n" % pid)

    def delete_pid(self):
        os.remove(self.pidfile)

    def _read_pid_from_pidfile(self):
        try:
            with open(self.pidfile, 'r') as pf:
                pid = int(pf.read().strip())
        except IOError:
            pid = None
        return pid

    def start(self):
        pid = self._read_pid_from_pidfile()

        if pid:
            logger.info("Daemon already running, exiting")
            sys.exit(1)

        logger.info("Starting daemon")
        self.daemonize()
        self.run()

    def stop(self):
        pid = self._read_pid_from_pidfile()

        if not pid:
            logger.info("pidfile doesn't exist, deamon must not be running")
            return

        try:
            while True:
                os.kill(pid, signal.SIGTERM)
                time.sleep(0.1)

        except OSError:
            if os.path.exists(self.pidfile):
                os.remove(self.pidfile)
            else:
                sys.exit(1)

    def restart(self):
        self.stop()
        self.start()

    def run(self):
        self.process()

class GracefulKiller(object):
    def __init__(self):
        self.kill_now = False
        signal.signal(signal.SIGINT, self.exit_gracefully)
        signal.signal(signal.SIGTERM, self.exit_gracefully)

    def exit_gracefully(self, signum, frame):
        logging.warning("Received signal: %s", signum)
        self.kill_now = True

def dns():

    default_port = 80
    timeout = 3

    print("")
    print("Trying DNS Lookup")
    var=int(sys.argv[1])

    game_hosts = {
        1:  ("game01.st-pso.games.sega.net", "Phantasy Star Online"),
        2:  ("master.quake3arena.com", "Quake III Arena"),
        3:  ("master.4x4evolution.com", "4x4 Evolution"),
        4:  ("aeroisd.dricas.com", "Aero Dancing Series"),
        5:  ("auriga.segasoft.com", "Alien Front Online"),
        6:  ("chuchu.games.dream-key.com", "ChuChu Rocket"),
        7:  ("daytona.web.dreamcast.com", "Daytona USA"),
        8:  ("ddplanet.sega.co.jp", "DeeDee Planet"),
        9:  ("strikers.realityjump.co.uk", "Driving Strikers"),
        10: ("f355.sega-rd2.com", "F355 Challenge"),
        11: ("golf.dricas.com", "Golf Shiyouyo 2"),
        12: ("hundred.dricas.com", "Hundred Swords"),
        13: ("authorize.vc-igp.games.sega.net", "Internet Game Pack"),
        14: ("coolpool.east.won.net", "Maximum Pool"),
        15: ("ca1203.mmcp6", "Mobile Suit Gundam: Federation vs. Zeon"),
        16: ("connect.gameloft.com", "Monaco/POD/Speed Devils"),
        17: ("peerchat.gamespy.com", "Next Tetris, The"),
        18: ("authorize.vc-ooga.games.sega.net", "Ooga Booga"),
        19: ("kage-bootstrap.dreamcast.com", "Outtrigger"),
        20: ("gamestats.pba2001.com", "PBA Bowling"),
        21: ("master.ring.dream-key.com", "Planet Ring"),
        22: ("powersmash.dricas.com", "Power Smash"),
        23: ("tetris.dricas.com", "Sega Tetris"),
        24: ("master.gamespy.com", "Starlancer"),
        25: ("gamesauth.dream-key.com", "Toy Racer"),
        26: ("master.worms.dream-key.com", "Worms World Party"),
        27: ("yakyuu.dricas.com", "Yakyuu Team de Asobou Net!"),
        28: ("AUTHORIZE.VC-NBA2K1.GAMES.SEGA.NET", "2K Series: NBA 2K1"),
        29: ("AUTHORIZE.VC-NBA2K2.GAMES.SEGA.NET", "2K Series: NBA 2K2"),
        30: ("AUTHORIZE.VC-NCAA2K2.GAMES.SEGA.NET", "2K Series: NCAA 2K2"),
        31: ("AUTHORIZE.VC-NFL2K1.GAMES.SEGA.COM", "2K Series: NFL 2K1"),
        32: ("AUTHORIZE.VC-NFL2K2.GAMES.SEGA.NET", "2K Series: NFL 2K2"),
        33: ("dcplaya.dnslookup", "DCPlaya"),
        34: ("dreampipe.net", "Web Browsing"),
        35: ("master.id-q3c.games.sega.net", "Quake III Arena Custom Maps")
    }
 
    host, game_name = game_hosts.get(var, ("google.com", "Unknown"))
    port = 6500 if var == 24 else default_port

    try:
        socket.setdefaulttimeout(timeout)
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect((host, port))
        s.close()
        print("\nHost reached: {}:{}\n\nCheck Dreamcast Now page\n".format(host, port))
    except socket.error:
        print("\nHost not reached: {}:{}\n\nCheck Dreamcast Now page\n".format(host, port))

def main():
    try:
        # Don't do anything until there is an internet connection
        while not check_internet_connection():
            logger.info("Waiting for internet connection...")
            time.sleep(3)

        var=int(sys.argv[1])
        if var == 0:
            dev=sys.argv[2]
            # If BBA Mode > TCP Dump on ethernet port to read Dreamcast moves
            subprocess.check_output("tcpdump -i " + dev + " -vv > /tmp/capture1 &", shell=True)
        else:
            dns()

        bba_dcnow_config.start()
        dcnow = DreamcastNowService()
        dcnow.go_online()

        logger.info("BBA Mode: DC Now Session Started")

        while True:
            if var == 0:
                # Toy Racer packet monitoring
                subprocess.check_output("grep -a '.2048 ' /tmp/capture1 | cut -d ':' -f 1 | grep '.2048 ' | awk '{print $3;}' > /tmp/capture2", shell=True)
                # If there is communication under 2048 toy racer port, we inject the correct DNS Query, cause there is no URL at all on BBA Toy Racer communications
                subprocess.check_output("sed -i -e 's/^/gamesauth.dream-key.com /' /tmp/capture2", shell=True)

                # Other BBA Games packet monitoring for DNS query research, to  ensure we send the game flag to Now
                subprocess.check_output("grep -a 'A? ' /tmp/capture1 | cut -d ':' -f 3 | grep 'A? ' | awk '{print $2;}' | sed 's/\.$//' >> /tmp/capture2", shell=True)
                # If we have a Toy Racer detection, this sed commando will add query[A] to initial of line, before the gamesauth.dream-key, if is other BBA Game, the grep above this that will actually populate capture2 file and we don't have the first toy racer sed injection.
                subprocess.check_output("sed -i -e 's/^/dnsmasq[0000]: query[A] /' /tmp/capture2", shell=True)

                # Remove any duplicate value
                subprocess.check_output("sort /tmp/capture2 | uniq | tee /tmp/capture2", shell=True)

                with open("/tmp/capture2") as f:
                    for line in f:
                        logger.info(line.strip())

                subprocess.check_output("truncate -s 0 /tmp/capture*", shell=True)

                lines = sh.tail("-n", "3", "/var/log/messages")
                for line in lines.splitlines():
                    if "link_down" in line:
                        dcnow.go_offline()
                        bba_dcnow_config.stop()
                        return 0
            time.sleep(3)
    except:
        return 1
    finally:
        logger.info("BBA Mode: DC Now Session Ended")

if __name__ == '__main__':
    logger.setLevel(logging.INFO)
    handler = logging.handlers.SysLogHandler(address='/dev/log')
    logger.addHandler(handler)

    if len(sys.argv) > 1 and "--no-daemon" in sys.argv:
        logger.addHandler(logging.StreamHandler())
        sys.exit(main())

    daemon = Daemon("/tmp/bba_mode.pid", main)

    if len(sys.argv) == 2:
        if sys.argv[1] == "start":
            daemon.start()
        elif sys.argv[1] == "stop":
            daemon.stop()
        elif sys.argv[1] == "restart":
            daemon.restart()
        else:
            sys.exit(2)
        sys.exit(0)
    else:
        print("Usage: %s start|stop|restart" % sys.argv[0])
        sys.exit(2)
