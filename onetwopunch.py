#!/usr/bin/env python3

import argparse
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

# ANSI colors
RED   = "\033[31m"
GREEN = "\033[32m"
BLUE  = "\033[34m"
RESET = "\033[39m"


def banner():
    print(r"""
                             _                                          _       _
  ___  _ __   ___           | |___      _____    _ __  _   _ _ __   ___| |__   / \
 / _ \| '_ \ / _ \          | __\ \ /\ / / _ \  | '_ \| | | | '_ \ / __| '_ \ /  /
| (_) | | | |  __/ ᕦ(ò_óˇ)ᕤ | |_ \ V  V / (_) | | |_) | |_| | | | | (__| | | /\_/
 \___/|_| |_|\___|           \__| \_/\_/ \___/  | .__/ \__,_|_| |_|\___|_| |_\/
                                                |_|
                                                                   by superkojiman
""")


def find_binary(names):
    for name in names:
        path = shutil.which(name)
        if path:
            return path
    return None


def run(cmd, log_path):
    """Run a command, stream output to terminal, and write it to log_path."""
    print(f"{BLUE}[+]{RESET} {' '.join(cmd)}")
    with open(log_path, "w") as fh:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        for line in proc.stdout:
            print(line, end="", flush=True)
            fh.write(line)
        proc.wait()
    return proc.returncode


def parse_ports(log_path):
    """Extract unique sorted port numbers from unicornscan output."""
    ports = set()
    try:
        with open(log_path) as fh:
            for line in fh:
                if "open" in line.lower():
                    for m in re.finditer(r'\[(\d+)\]', line):
                        ports.add(int(m.group(1)))
    except FileNotFoundError:
        pass
    return ",".join(str(p) for p in sorted(ports))


def backup_dir(path):
    if path.exists():
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        path.rename(path.parent / f"{path.name}-{stamp}")


def main():
    banner()

    if os.geteuid() != 0:
        print(f"{RED}[!]{RESET} This script must be run as root")
        sys.exit(1)

    nmap_bin = find_binary(["nmap"])
    if not nmap_bin:
        print(f"{RED}[!]{RESET} Unable to find nmap. Install it and make sure it's in your PATH environment")
        sys.exit(1)

    us_bin = find_binary(["unicornscan", "us"])
    if not us_bin:
        print(f"{RED}[!]{RESET} Unable to find unicornscan or us. Install it and make sure it's in your PATH environment")
        sys.exit(1)

    print(f"{BLUE}[+]{RESET} Using unicornscan binary: {us_bin}")

    parser = argparse.ArgumentParser(
        description="onetwopunch: unicornscan + nmap combined scanner",
        add_help=False,
    )
    parser.add_argument("-t", "--targets",  required=True,  help="File containing IP addresses to scan")
    parser.add_argument("-p", "--proto",    default="tcp",  choices=["tcp", "udp", "all"], help="Protocol (default: tcp)")
    parser.add_argument("-i", "--iface",    default="eth0", help="Network interface (default: eth0)")
    parser.add_argument("-r", "--rate",     default="1000", help="Unicornscan packets-per-second rate (default: 1000)")
    parser.add_argument("-n", "--nmap-opt", default="-sV",  help="Nmap options (default: -sV)")
    parser.add_argument("-h", "--help",     action="help",  help="Show this help message")
    args = parser.parse_args()

    targets_file = Path(args.targets)
    if not targets_file.is_file():
        print(f"{RED}[!]{RESET} Target file not found: {targets_file}")
        sys.exit(1)

    nmap_opts = args.nmap_opt.split()

    print(f"{BLUE}[+]{RESET} Protocol : {args.proto}")
    print(f"{BLUE}[+]{RESET} Interface: {args.iface}")
    print(f"{BLUE}[+]{RESET} Rate     : {args.rate} pps")
    print(f"{BLUE}[+]{RESET} Nmap opts: {args.nmap_opt}")
    print(f"{BLUE}[+]{RESET} Targets  : {targets_file}")

    log_dir = Path.home() / ".onetwopunch"
    ndir = log_dir / "ndir"
    udir = log_dir / "udir"
    backup_dir(ndir)
    backup_dir(udir)
    ndir.mkdir(parents=True, exist_ok=True)
    udir.mkdir(parents=True, exist_ok=True)

    ips = [
        line.strip()
        for line in targets_file.read_text().splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]

    for ip in ips:
        log_ip = ip.replace("/", "-")
        print(f"{BLUE}[+]{RESET} Scanning {ip} for {args.proto} ports...")

        if args.proto in ("tcp", "all"):
            print(f"{BLUE}[+]{RESET} Obtaining all open TCP ports using unicornscan...")
            tcp_log = udir / f"{log_ip}-tcp.txt"
            run(
                [us_bin, "-i", args.iface, "-mT", "-I", f"-r{args.rate}", f"{ip}:1-65535"],
                tcp_log,
            )
            ports = parse_ports(tcp_log)
            if ports:
                print(f"{GREEN}[*]{RESET} TCP ports for nmap to scan: {ports}")
                run(
                    [
                        nmap_bin, "-e", args.iface,
                        *nmap_opts,
                        "-oX", str(ndir / f"{log_ip}-tcp.xml"),
                        "-oG", str(ndir / f"{log_ip}-tcp.grep"),
                        "-p", ports,
                        ip,
                    ],
                    ndir / f"{log_ip}-tcp-nmap.txt",
                )
            else:
                print(f"{RED}[!]{RESET} No TCP ports found")

        if args.proto in ("udp", "all"):
            print(f"{BLUE}[+]{RESET} Obtaining all open UDP ports using unicornscan...")
            udp_log = udir / f"{log_ip}-udp.txt"
            run(
                [us_bin, "-i", args.iface, "-mU", "-I", f"-r{args.rate}", f"{ip}:1-65535"],
                udp_log,
            )
            ports = parse_ports(udp_log)
            if ports:
                print(f"{GREEN}[*]{RESET} UDP ports for nmap to scan: {ports}")
                run(
                    [
                        nmap_bin, "-e", args.iface,
                        *nmap_opts, "-sU",
                        "-oX", str(ndir / f"{log_ip}-udp.xml"),
                        "-oG", str(ndir / f"{log_ip}-udp.grep"),
                        "-p", ports,
                        ip,
                    ],
                    ndir / f"{log_ip}-udp-nmap.txt",
                )
            else:
                print(f"{RED}[!]{RESET} No UDP ports found"  )

    print(f"{BLUE}[+]{RESET} Scans completed")
    print(f"{BLUE}[+]{RESET} Results saved to {log_dir}")


if __name__ == "__main__":
    main()
