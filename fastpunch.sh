#!/bin/bash 

# Colors
ESC="\e["
RESET=$ESC"39m"
RED=$ESC"31m"
GREEN=$ESC"32m"
BLUE=$ESC"34m"

function banner {
echo -e "${GREEN}"
echo "+------------------------------------------------------------------+"
echo "| fastpunch - modified version of 'onetwopunch' to allow for fast  |"
echo "|             scanning of hosts using the default port info in     |"
echo "|             unicornscan.                                         |"
echo "|                                                                  |"
echo "| Reports are output in text nmap, XML and grepable nmap           |"
echo "|                                                                  |"
echo "| Original Code https://github.com/superkojiman/onetwopunch        |"
echo "+------------------------------------------------------------------+"
echo -e "${RESET}"
}

function usage {
    echo "Usage: $0 -t targets.txt [-p tcp/udp/all] [-i interface] [-n nmap-options] [-f] [-c] [-h]"
    echo "       -h: Help"
    echo "       -t: File containing ip addresses to scan. This option is required."
    echo "       -p: Protocol. Defaults to tcp"
    echo "       -i: Network interface. Defaults to eth0"
    echo "       -n: NMAP options (-A, -O, etc). Defaults to -A."
    echo "       -f: Fast scan with default port list. Defaults to 'all' ports."
    echo "       -c: Move previous results to backup directory. Defaults to keeping files."
}

banner

if [[ ! $(id -u) == 0 ]]; then
    echo -e "${RED}[!]${RESET} This script must be run as root"
    exit 1
fi

if [[ -z $(which nmap) ]]; then
    echo -e "${RED}[!]${RESET} Unable to find nmap. Install it and make sure it's in your PATH   environment"
    exit 1
fi

if [[ -z $(which unicornscan) ]]; then
    echo -e "${RED}[!]${RESET} Unable to find unicornscan. Install it and make sure it's in your PATH environment"
    exit 1
fi

if [[ -z $1 ]]; then
    usage
    exit 0
fi

#=====
# commonly used default options
#=====

# by default scan only the tcp ports
proto="tcp"

# default to the eth0 interface
iface="eth0"

# default to do nmap banners and scripts
nmap_opt="-A"

# user must supply a file for the hosts
targets=""

# default to scanning all ports
scanspeed="a"

# default to keeping old data
cleanstart="no"

#=====
# get user options from command line
#=====
while getopts "p:i:t:n:hfc" OPT; do
    case $OPT in
        p) proto=${OPTARG};;
        i) iface=${OPTARG};;
        t) targets=${OPTARG};;
        n) nmap_opt=${OPTARG};;
	f) scanspeed="d";;
        c) cleanstart="yes";;
        h) usage; exit 0;;
        *) usage; exit 0;;
    esac
done

if [[ -z $targets ]]; then
    echo -e "${RED}[!]$PRESET} No target file provided\n"
    usage
    exit 1
fi

#=====
# check user gave us a supported protocol
#=====
if [[ ${proto} != "tcp" && ${proto} != "udp" && ${proto} != "all" ]]; then
    echo -e "${RED}[!]${RESET} Unsupported protocol\n"
    usage
    exit 1
fi

#=====
# print out the starting options
#=====
echo -e "${BLUE}[+]${RESET} Protocol : ${proto}"
echo -e "${BLUE}[+]${RESET} Interface: ${iface}"
echo -e "${BLUE}[+]${RESET} Nmap opts: ${nmap_opt}"
echo -e "${BLUE}[+]${RESET} Targets  : ${targets}"

log_dir="${HOME}/oscp"
scan_dir="${log_dir}/scans"

#=====
# backup any old scans before we start a new one
#=====

mkdir -p "${log_dir}/backup/"

if [[ ${cleanstart} == "yes" ]]; then
    echo -e "${BLUE}[+]${RESET} Creating backup of current data"

    if [[ -d "${scan_dir}/" ]]; then 
        mv "${scan_dir}" "${scan_dir}/backup/scans-$(date "+%Y-%m-%d-%H:%M:%S")/"
    fi 

    rm -rf "${scan_dir}/"
    mkdir -p "${scan_dir}/"
fi

#=====
# loop through all the ip addresses in the given file
#=====
while read ip; do
    echo -e "${BLUE}[+]${RESET} Scanning $ip for $proto ports..."

    mkdir -p "${scan_dir}/${ip}/"

    #=====
    # unicornscan identifies all open TCP ports
    #=====
    if [[ $proto == "tcp" || $proto == "all" ]]; then 
	if [[ $scanspeed == "a" ]]; then
            echo -e "${BLUE}[+]${RESET} Obtaining all open TCP ports using unicornscan..."
            echo -e "${BLUE}[+]${RESET} unicornscan -i ${iface} -mT ${ip}:a -l ${scan_dir}/${ip}/tcp-all.txt"
            unicornscan\
                -i ${iface}\
                -mT ${ip}:a\
                -l ${scan_dir}/${ip}/tcp-all.txt
            ports=$(cat "${scan_dir}/${ip}/tcp-all.txt" | grep open | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
	else
            echo -e "${BLUE}[+]${RESET} Obtaining default open TCP ports using unicornscan..."
            echo -e "${BLUE}[+]${RESET} unicornscan -i ${iface} -mT ${ip} -l ${scan_dir}/${ip}/tcp-fast.txt"
            unicornscan\
                -i ${iface}\
                -mT ${ip}\
                -l ${scan_dir}/${ip}/tcp-fast.txt
            ports=$(cat "${scan_dir}/${ip}/tcp-fast.txt" | grep open | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
	fi

        #=====
        # nmap follows up
        #=====
        if [[ ! -z $ports ]]; then 
	    if [[ $scanspeed == "a" ]]; then
                echo -e "${GREEN}[*]${RESET} TCP ports for nmap to scan: $ports"
                echo -e "${BLUE}[+]${RESET} nmap -e ${iface} ${nmap_opt} -oA ${scan_dir}/${ip}/tcp-all -p ${ports} ${ip}"
                nmap\
                    -e ${iface}\
                    ${nmap_opt}\
                    -oA ${scan_dir}/${ip}/tcp-all \
                    -p ${ports}\
                    ${ip}
	    else
                echo -e "${GREEN}[*]${RESET} TCP ports for nmap to scan: $ports"
                echo -e "${BLUE}[+]${RESET} nmap -e ${iface} ${nmap_opt} -oA ${scan_dir}/${ip}/tcp-fast -p ${ports} ${ip}"
                nmap -e ${iface} ${nmap_opt} -oA ${scan_dir}/${ip}/tcp-fast -p ${ports} ${ip}
	    fi
        else
            echo -e "${RED}[!]${RESET} No TCP ports found"
        fi
    fi

    #=====
    # unicornscan identifies all open UDP ports
    #=====
    if [[ $proto == "udp" || $proto == "all" ]]; then  
        if [[ $scanspeed == "a" ]]; then
            echo -e "${BLUE}[+]${RESET} Obtaining all open UDP ports using unicornscan..."
            echo -e "${BLUE}[+]${RESET} unicornscan -i ${iface} -mU ${ip}:a -l ${scan_dir}/${ip}/udp-all.txt"
            unicornscan -i ${iface} -mU ${ip}:a -l ${scan_dir}/${ip}/udp-all.txt
            ports=$(cat "${scan_dir}/${ip}/udp-all.txt" | grep open | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
	else
            echo -e "${BLUE}[+]${RESET} Obtaining default open UDP ports using unicornscan..."
            echo -e "${BLUE}[+]${RESET} unicornscan -i ${iface} -mU ${ip} -l ${scan_dir}/${ip}/udp-fast.txt"
            unicornscan -i ${iface} -mU ${ip} -l ${scan_dir}/${ip}/udp-fast.txt
            ports=$(cat "${scan_dir}/${ip}/udp-fast.txt" | grep open | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
	fi

        #=====
        # nmap follows up
        #=====
        if [[ ! -z $ports ]]; then
	    if [[ $scanspeed == "a" ]]; then
                echo -e "${GREEN}[*]${RESET} UDP ports for nmap to scan: $ports"
                echo -e "${BLUE}[+]${RESET} nmap -e ${iface} ${nmap_opt} -sU -oA ${scan_dir}/${ip}/udp-all -p ${ports} ${ip}"
                nmap -e ${iface} ${nmap_opt} -sU -oA ${scan_dir}/${ip}/udp-all -p ${ports} ${ip}
            else
                echo -e "${GREEN}[*]${RESET} UDP ports for nmap to scan: $ports"
                echo -e "${BLUE}[+]${RESET} nmap -e ${iface} ${nmap_opt} -sU -oA ${scan_dir}/${ip}/udp-fast -p ${ports} ${ip}"
                nmap -e ${iface} ${nmap_opt} -sU -oA ${scan_dir}/${ip}/udp-fast -p ${ports} ${ip}
            fi
        else
            echo -e "${RED}[!]${RESET} No UDP ports found"
        fi
    fi
done < ${targets}

echo -e "${BLUE}[+]${RESET} Scans completed"
echo -e "${BLUE}[+]${RESET} Results saved to ${scan_dir}"
