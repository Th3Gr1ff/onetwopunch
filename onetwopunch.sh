#!/bin/bash

# Colors
ESC="\e["
RESET=$ESC"39m"
RED=$ESC"31m"
GREEN=$ESC"32m"
BLUE=$ESC"34m"

function banner {
echo "                             _                                          _       _ "
echo "  ___  _ __   ___           | |___      _____    _ __  _   _ _ __   ___| |__   / \\"
echo " / _ \| '_ \ / _ \          | __\ \ /\ / / _ \  | '_ \| | | | '_ \ / __| '_ \ /  /"
echo "| (_) | | | |  __/ ᕦ(ò_óˇ)ᕤ | |_ \ V  V / (_) | | |_) | |_| | | | | (__| | | /\_/ "
echo " \___/|_| |_|\___|           \__| \_/\_/ \___/  | .__/ \__,_|_| |_|\___|_| |_\/   "
echo "                                                |_|                               "
echo "                                                                   by superkojiman"
echo ""
}

function usage {
    echo "Usage: $0 -t targets.txt [-p tcp/udp/all] [-i interface] [-r rate] [-n nmap-options] [-h]"
    echo "       -h: Help"
    echo "       -t: File containing IP addresses to scan. Required."
    echo "       -p: Protocol. Defaults to tcp (tcp/udp/all)"
    echo "       -i: Network interface. Defaults to eth0"
    echo "       -r: Unicornscan packets-per-second rate. Defaults to 1000"
    echo "       -n: Nmap options (-A, -O, etc). Defaults to -sV"
}

banner

if [[ ! $(id -u) == 0 ]]; then
    echo -e "${RED}[!]${RESET} This script must be run as root"
    exit 1
fi

if [[ -z $(which nmap) ]]; then
    echo -e "${RED}[!]${RESET} Unable to find nmap. Install it and make sure it's in your PATH environment"
    exit 1
fi

# Support both 'unicornscan' and 'us' binary names
UNICORNSCAN_BIN=""
if [[ -n $(which unicornscan 2>/dev/null) ]]; then
    UNICORNSCAN_BIN=$(which unicornscan)
elif [[ -n $(which us 2>/dev/null) ]]; then
    UNICORNSCAN_BIN=$(which us)
else
    echo -e "${RED}[!]${RESET} Unable to find unicornscan or us. Install it and make sure it's in your PATH environment"
    exit 1
fi

echo -e "${BLUE}[+]${RESET} Using unicornscan binary: ${UNICORNSCAN_BIN}"

if [[ -z $1 ]]; then
    usage
    exit 0
fi

proto="tcp"
iface="eth0"
rate="1000"
nmap_opt="-sV"
targets=""

while getopts "p:i:r:t:n:h" OPT; do
    case $OPT in
        p) proto=${OPTARG};;
        i) iface=${OPTARG};;
        r) rate=${OPTARG};;
        t) targets=${OPTARG};;
        n) nmap_opt=${OPTARG};;
        h) usage; exit 0;;
        *) usage; exit 0;;
    esac
done

if [[ -z "${targets}" ]]; then
    echo "[!] No target file provided"
    usage
    exit 1
fi

if [[ ! -f "${targets}" ]]; then
    echo -e "${RED}[!]${RESET} Target file not found: ${targets}"
    exit 1
fi

if [[ "${proto}" != "tcp" && "${proto}" != "udp" && "${proto}" != "all" ]]; then
    echo "[!] Unsupported protocol"
    usage
    exit 1
fi

echo -e "${BLUE}[+]${RESET} Protocol : ${proto}"
echo -e "${BLUE}[+]${RESET} Interface: ${iface}"
echo -e "${BLUE}[+]${RESET} Rate     : ${rate} pps"
echo -e "${BLUE}[+]${RESET} Nmap opts: ${nmap_opt}"
echo -e "${BLUE}[+]${RESET} Targets  : ${targets}"

# Backup any old scans before starting a new one
log_dir="${HOME}/.onetwopunch"
mkdir -p "${log_dir}/backup/"
if [[ -d "${log_dir}/ndir/" ]]; then
    mv "${log_dir}/ndir/" "${log_dir}/backup/ndir-$(date "+%Y%m%d-%H%M%S")/"
fi
if [[ -d "${log_dir}/udir/" ]]; then
    mv "${log_dir}/udir/" "${log_dir}/backup/udir-$(date "+%Y%m%d-%H%M%S")/"
fi

rm -rf "${log_dir}/ndir/"
mkdir -p "${log_dir}/ndir/"
rm -rf "${log_dir}/udir/"
mkdir -p "${log_dir}/udir/"

while read -r ip; do
    # Skip blank lines and comments
    [[ -z "${ip}" || "${ip}" == \#* ]] && continue

    log_ip=$(echo "${ip}" | sed 's/\//-/g')
    echo -e "${BLUE}[+]${RESET} Scanning ${ip} for ${proto} ports..."

    # unicornscan identifies all open TCP ports
    # New unicornscan: no -l flag; capture stdout via tee
    # -I = immediate output; -r = rate; 1-65535 replaces legacy :a shorthand
    if [[ "${proto}" == "tcp" || "${proto}" == "all" ]]; then
        echo -e "${BLUE}[+]${RESET} Obtaining all open TCP ports using unicornscan..."
        echo -e "${BLUE}[+]${RESET} ${UNICORNSCAN_BIN} -i ${iface} -mT -I -r${rate} ${ip}:1-65535"
        "${UNICORNSCAN_BIN}" -i "${iface}" -mT -I -r"${rate}" "${ip}":1-65535 2>&1 \
            | tee "${log_dir}/udir/${log_ip}-tcp.txt"
        ports=$(grep -i "open" "${log_dir}/udir/${log_ip}-tcp.txt" \
            | grep -oP '\[\K[0-9]+(?=\])' \
            | sort -un \
            | tr '\n' ',' \
            | sed 's/,$//')
        if [[ -n "${ports}" ]]; then
            echo -e "${GREEN}[*]${RESET} TCP ports for nmap to scan: ${ports}"
            echo -e "${BLUE}[+]${RESET} nmap -e ${iface} ${nmap_opt} -p ${ports} ${ip}"
            nmap -e "${iface}" ${nmap_opt} \
                -oX "${log_dir}/ndir/${log_ip}-tcp.xml" \
                -oG "${log_dir}/ndir/${log_ip}-tcp.grep" \
                -p "${ports}" "${ip}"
        else
            echo -e "${RED}[!]${RESET} No TCP ports found"
        fi
    fi

    # unicornscan identifies all open UDP ports
    if [[ "${proto}" == "udp" || "${proto}" == "all" ]]; then
        echo -e "${BLUE}[+]${RESET} Obtaining all open UDP ports using unicornscan..."
        echo -e "${BLUE}[+]${RESET} ${UNICORNSCAN_BIN} -i ${iface} -mU -I -r${rate} ${ip}:1-65535"
        "${UNICORNSCAN_BIN}" -i "${iface}" -mU -I -r"${rate}" "${ip}":1-65535 2>&1 \
            | tee "${log_dir}/udir/${log_ip}-udp.txt"
        ports=$(grep -i "open" "${log_dir}/udir/${log_ip}-udp.txt" \
            | grep -oP '\[\K[0-9]+(?=\])' \
            | sort -un \
            | tr '\n' ',' \
            | sed 's/,$//')
        if [[ -n "${ports}" ]]; then
            echo -e "${GREEN}[*]${RESET} UDP ports for nmap to scan: ${ports}"
            echo -e "${BLUE}[+]${RESET} nmap -e ${iface} ${nmap_opt} -sU -p ${ports} ${ip}"
            nmap -e "${iface}" ${nmap_opt} -sU \
                -oX "${log_dir}/ndir/${log_ip}-udp.xml" \
                -oG "${log_dir}/ndir/${log_ip}-udp.grep" \
                -p "${ports}" "${ip}"
        else
            echo -e "${RED}[!]${RESET} No UDP ports found"
        fi
    fi
done < "${targets}"

echo -e "${BLUE}[+]${RESET} Scans completed"
echo -e "${BLUE}[+]${RESET} Results saved to ${log_dir}"
