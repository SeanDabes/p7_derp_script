#!bin/bash

# Terminal Colors
readonly BLUE='\033[1;34m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[1;31m'
readonly CYAN='\033[1;36m'
readonly MAGENTA='\033[1;35m'
readonly GRAY='\033[1;90m'
readonly WHITE='\033[1;37m'
readonly NOCOLOR='\033[0m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly WHITEONBLUE='\033[1;37;44m'
readonly WHITEONMAGENTA='\033[1;37;45m'
readonly WHITEONYELLOW='\033[1;37;43m'
readonly WHITEONCYAN='\033[1;37;46m'

clear
echo -e "${WHITEONBLUE}                                      ${NOCOLOR} ${GRAY}`date`${NOCOLOR}"
echo -e "${WHITEONBLUE}    █▀▄ █▀▀ █▀▄ █▀█ █▀▀ █▀▀ █▀▀ ▀█▀   ${NOCOLOR} ${BLUE}Device: $2${NOCOLOR}"
echo -e "${WHITEONYELLOW}    █ █ █▀▀ █▀▄ █▀▀ █▀▀ █▀▀ ▀▀█  █    ${NOCOLOR} ${YELLOW}Version: $3${NOCOLOR}"
echo -e "${WHITEONCYAN}    ▀▀  ▀▀▀ ▀ ▀ ▀   ▀   ▀▀▀ ▀▀▀  ▀    ${NOCOLOR} ${CYAN}LineageOS branch: $4${NOCOLOR}"
echo -e "${WHITEONCYAN}         >>Building script<<          ${NOCOLOR}"
case $1 in
    "wait")
        while [ ! -f /tmp/end_derp ]; do
            sleep 1
        done
    ;;
    "nowait")
        echo
        echo
    ;;
esac
