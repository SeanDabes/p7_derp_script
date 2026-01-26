#!/bin/bash

partition="/media/seandabes/data" # Change for your own

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
readonly WHITEONGREEN='\033[1;37;42m'
readonly BLACKONWHITE='\033[1;30;47m'


# Function to set the color based on the value
set_color() {
    if (( $(echo "$1 < 70" | bc -l) )); then
        echo -e "${GREEN}"  # Green
    elif (( $(echo "$1 < 85" | bc -l) )); then
        echo -e "${YELLOW}"  # Yellow
    else
        echo -e "${RED}"  # Red
    fi
}

# Function to create a graphical bar
draw_bar() {
    local percent="$1"
    local length=$((percent / 5))  # Length of the bar (20 characters = 100%)
    printf "▕"
    for ((i=0; i<20; i++)); do
        if [ $i -lt $length ]; then
            printf "▒"
        else
            printf " "
        fi
    done
    printf "▏%3s%%" "$percent"
}

clear
echo
echo -e "${WHITEONMAGENTA} System Monitor       ${NOCOLOR}"
echo

# Infinite loop
while true; do
    # RAM usage
    used_ram=$(LC_ALL=C free | awk '/Mem/{print int($3/$2*100)}')  # Use int to get only the integer part

    # Swap usage
    used_swap=$(LC_ALL=C free | awk '/Swap/{print int($3/$2*100)}')  # Use int to get only the integer part

    # CPU usage
    used_cpu=$(LC_ALL=C top -bn1 | awk '/^%Cpu/{print int(100-$8)}')  # Use int to get only the integer part

    # Disk usage
    used_disk=$(df --output=pcent $partition | tail -n1 | tr -d '%' | cut -d '.' -f 1)  # Remove decimals

    # Set colors
    ram_color=$(set_color "$used_ram")
    swap_color=$(set_color "$used_swap")
    cpu_color=$(set_color "$used_cpu")
    disco_color=$(set_color "$used_disk")

    # Print all information in one line
    echo -ne "\r ${NOCOLOR}${WHITE}RAM${ram_color}$(draw_bar "$used_ram")${NOCOLOR}            ${WHITE}Swap${swap_color}$(draw_bar "$used_swap")${NOCOLOR}            ${WHITE}CPU${cpu_color}$(draw_bar "$used_cpu")${NOCOLOR}           ${WHITE}Disk${disco_color}$(draw_bar "$used_disk")${NOCOLOR}"

    # Wait for 1 second
    sleep 1
done
