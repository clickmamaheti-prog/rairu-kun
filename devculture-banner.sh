#!/bin/bash
# DevCulture Premium SSH Login Banner

C='\033[0m'        # Reset
CY='\033[1;96m'    # Bright Cyan
PK='\033[1;95m'    # Bright Pink/Magenta
YW='\033[1;93m'    # Yellow
GR='\033[1;92m'    # Green
WH='\033[1;97m'    # White
DM='\033[2;37m'    # Dim white
RD='\033[1;91m'    # Red
BL='\033[1;94m'    # Blue

# Gradient border helper
BR_TOP="${CY}╔══════════════════════════════════════════════════════════════╗${C}"
BR_MID="${CY}║${C}"
BR_BOT="${CY}╚══════════════════════════════════════════════════════════════╝${C}"
BR_SEP="${CY}╠══════════════════════════════════════════════════════════════╣${C}"

clear
echo ""
echo -e "$BR_TOP"
echo -e "${CY}║${C}                                                              ${CY}║${C}"
echo -e "${CY}║${C}   ${CY}██████╗ ${PK}███████╗${CY}██╗   ██╗${PK}██████╗ ${CY}██╗   ██╗${PK}██╗   ${CY}████████╗${CY}║${C}"
echo -e "${CY}║${C}   ${CY}██╔══██╗${PK}██╔════╝${CY}██║   ██║${PK}██╔══██╗${CY}██║   ██║${PK}██║   ${CY}╚══██╔══╝${CY}║${C}"
echo -e "${CY}║${C}   ${CY}██║  ██║${PK}█████╗  ${CY}██║   ██║${PK}██║  ██║${CY}██║   ██║${PK}██║   ${CY}   ██║   ${CY}║${C}"
echo -e "${CY}║${C}   ${CY}██║  ██║${PK}██╔══╝  ${CY}╚██╗ ██╔╝${PK}██║  ██║${CY}██║   ██║${PK}██║   ${CY}   ██║   ${CY}║${C}"
echo -e "${CY}║${C}   ${CY}██████╔╝${PK}███████╗${CY} ╚████╔╝ ${PK}██████╔╝${CY}╚██████╔╝${PK}███████╗${CY}██║   ${CY}║${C}"
echo -e "${CY}║${C}   ${CY}╚═════╝ ${PK}╚══════╝${CY}  ╚═══╝  ${PK}╚═════╝ ${CY} ╚═════╝ ${PK}╚══════╝${CY}╚═╝   ${CY}║${C}"
echo -e "${CY}║${C}                                                              ${CY}║${C}"
echo -e "${CY}║${C}          ${PK}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C}          ${CY}║${C}"
echo -e "${CY}║${C}              ${WH}★  P R E M I U M   C L O U D   V P S  ★${C}          ${CY}║${C}"
echo -e "${CY}║${C}          ${PK}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C}          ${CY}║${C}"
echo -e "${CY}║${C}                                                              ${CY}║${C}"
echo -e "$BR_SEP"

# System info
UPTIME=$(uptime -p 2>/dev/null | sed 's/up //' || echo "running")
MEM_USED=$(free -m 2>/dev/null | awk '/Mem:/{printf "%.0f", $3/$2*100}')
MEM_INFO=$(free -m 2>/dev/null | awk '/Mem:/{printf "%dMB / %dMB", $3, $2}')
DISK=$(df -h / 2>/dev/null | awk 'NR==2{print $3"/"$2" ("$5")"}')
LOAD=$(cat /proc/loadavg 2>/dev/null | awk '{print $1" "$2" "$3}')
IP_PUB=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || echo "fetching...")
KERN=$(uname -r 2>/dev/null || echo "linux")
OLLAMA_ST="$RD●$C Offline"
pgrep ollama >/dev/null 2>&1 && OLLAMA_ST="${GR}●$C Online"
SSH_PORT=$(cat /tmp/port_22.txt 2>/dev/null || echo "connecting...")
WEB_PORT=$(cat /tmp/port_80.txt 2>/dev/null || echo "connecting...")

echo -e "${CY}║${C}  ${CY}🖥  System Information${C}                                          ${CY}║${C}"
echo -e "${CY}║${C}                                                              ${CY}║${C}"
echo -e "${CY}║${C}  ${WH}OS      ${CY}│${C} Ubuntu 20.04 LTS (Focal Fossa)               ${CY}║${C}"
echo -e "${CY}║${C}  ${WH}Kernel  ${CY}│${C} $KERN                                    ${CY}║${C}"
echo -e "${CY}║${C}  ${WH}Uptime  ${CY}│${C} $UPTIME                                    ${CY}║${C}"
echo -e "${CY}║${C}  ${WH}RAM     ${CY}│${C} ${GR}$MEM_INFO${C} (${MEM_USED}% used)               ${CY}║${C}"
echo -e "${CY}║${C}  ${WH}Disk    ${CY}│${C} $DISK                                ${CY}║${C}"
echo -e "${CY}║${C}  ${WH}Load    ${CY}│${C} $LOAD                                    ${CY}║${C}"
echo -e "${CY}║${C}  ${WH}IP      ${CY}│${C} ${YW}$IP_PUB${C}                                 ${CY}║${C}"
echo -e "${CY}║${C}                                                              ${CY}║${C}"
echo -e "$BR_SEP"
echo -e "${CY}║${C}  ${PK}🤖 Services${C}                                                   ${CY}║${C}"
echo -e "${CY}║${C}                                                              ${CY}║${C}"
echo -e "${CY}║${C}  ${WH}Ollama  ${CY}│${C} $OLLAMA_ST  (AI Model Server)                 ${CY}║${C}"
echo -e "${CY}║${C}  ${WH}Nginx   ${CY}│${C} $(pgrep nginx>/dev/null&&echo "${GR}●$C Online"||echo "$RD●$C Offline")  (Web Proxy)                       ${CY}║${C}"
echo -e "${CY}║${C}  ${WH}SSH     ${CY}│${C} ${GR}●$C bore.pub:${YW}${SSH_PORT}${C}                           ${CY}║${C}"
echo -e "${CY}║${C}  ${WH}Web UI  ${CY}│${C} ${BL}http://bore.pub:${YW}${WEB_PORT}${C}                         ${CY}║${C}"
echo -e "${CY}║${C}  ${WH}Ports   ${CY}│${C} ${CY}22 · 80 · 443 · 3000 · 8080 · 8888 · 11434${C}     ${CY}║${C}"
echo -e "${CY}║${C}                                                              ${CY}║${C}"
echo -e "$BR_BOT"
echo ""
echo -e "  ${DM}────────────────────────────────────────────────────────────${C}"
echo -e "            ${DM}powered by: ${PK}DevCulture${DM} ©2026 linux${C}"
echo -e "  ${DM}────────────────────────────────────────────────────────────${C}"
echo ""
