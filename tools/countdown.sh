#!/bin/bash

# Graphical countdown with progress bar (Unicode character ▒)
# Usage: ./countdown.sh [duration]
# Duration format: 10s, 5m, 1h30m20s, 2h, etc. (default 10s)

# Force UTF-8 locale for proper Unicode display
export LC_ALL=en_US.UTF-8

parse_duration() {
    local duration="$1"
    local total=0
    local number=""
    local i=0
    local len=${#duration}

    while [ $i -lt $len ]; do
        char="${duration:$i:1}"
        if [[ "$char" =~ [0-9] ]]; then
            number+="$char"
        else
            if [ -z "$number" ]; then
                echo "Error: missing number before unit" >&2
                return 1
            fi
            case "$char" in
                s) total=$((total + number)) ;;
                m) total=$((total + number * 60)) ;;
                h) total=$((total + number * 3600)) ;;
                *) echo "Error: invalid unit '$char'" >&2; return 1 ;;
            esac
            number=""
        fi
        ((i++))
    done

    if [ -n "$number" ]; then
        total=$((total + number))
    fi

    echo "$total"
}

input_duration="${1:-10s}"

total=$(parse_duration "$input_duration")
if [ $? -ne 0 ] || [ "$total" -le 0 ]; then
    echo "Error: invalid duration. Use format like 30s, 5m, 1h30m20s, etc." >&2
    exit 1
fi

echo
echo -e "${WHITEONMAGENTA} DerpFest for Pixel 7 family ${NOCOLOR}"
echo -e "${BLUE} Waiting $input_duration ($total seconds) before compiling...${NOCOLOR}"
echo

bar_width=50
remaining=$total

while [ $remaining -gt 0 ]; do
    hours=$((remaining / 3600))
    minutes=$(((remaining % 3600) / 60))
    seconds=$((remaining % 60))

    if [ $hours -gt 0 ]; then
        time_fmt=$(printf "%02d:%02d:%02d" "$hours" "$minutes" "$seconds")
    else
        time_fmt=$(printf "%02d:%02d" "$minutes" "$seconds")
    fi

    elapsed=$((total - remaining))
    percent=$((elapsed * 100 / total))

    # Build the bar exactly bar_width characters long
    filled=$((elapsed * bar_width / total))
    empty=$((bar_width - filled))

    # Create filled part (▒ characters)
    filled_spaces=$(printf "%${filled}s" "")
    filled_part=${filled_spaces// /▒}

    # Create empty part (spaces)
    empty_part=$(printf "%${empty}s" "")

    # Combine both parts
    bar="$filled_part$empty_part"

    # Print the bar without extra padding
    printf "\r▕%s▏ %3d%%  %s" "$bar" "$percent" "$time_fmt"

    sleep 1
    ((remaining--))
done

# Final bar (all ▒)
full_bar=$(printf "%${bar_width}s" "")
full_bar=${full_bar// /▒}
printf "\r▕%s▏ 100%%  " "$full_bar"
if [ $total -ge 3600 ]; then
    echo "00:00:00"
else
    echo "00:00"
fi

# echo "Countdown finished!"
