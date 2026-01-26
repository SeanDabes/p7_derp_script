#!/bin/bash

# Sean Dabes
# Script for modifying text-based files
# rmlinespp:      Removes lines between patterns
# rmline:         Removes a copmplete line (pattern matches)
# change_value:   Changes a value in a line with a pattern
# $1: operation
# $2: file
# $3: key pattern
# $4: end pattern / old value
# $5: new value

rmlines(){ # file, key_pattern, end_pattern
    local tempfile="temp.bp"
    local line_number1=0
    local line_number2=0
    local line_number3=0
    local found_line1=0
    local found_line2=0
    local start=0
    local end=0

    while IFS= read -r line; do
        line_number1=$((line_number1 + 1))

        if [[ "$line" == *"$2"* ]]; then
            found_line1=$line_number1
            break
        fi
    done < "$1"

    while IFS= read -r line; do
        line_number2=$((line_number2 + 1))

        if [[ "$line" == *"$3"* ]]; then
            if [ "$line_number2" -lt "$found_line1" ]; then
                continue
            else
                found_line2=$line_number2
                break
            fi
        fi
    done < "$1"

    start=$(($found_line1 - 1))
    end=$(($found_line2 - 1))

    line_number=0

    while IFS= read -r line; do
        line_number3=$((line_number3 + 1))

        if (( line_number3 < start || line_number3 > end )); then
            echo "$line" >> "$tempfile"
        fi
    done < "$1"

    mv "$tempfile" "$1"
}

rmline(){
    sed -i "/$2/d" "$1" > /dev/null 2>&1
}

change_value(){
    sed -i "/$2/ s/\"$3\"/\"$4\"/" "$1"
}

case $1 in
    "rmlinespp")
        rmlines $2 $3 $4
    ;;
    "rmline")
        rmline $2 $3
    ;;
    "change_value")
        change_value $2 $3 $4 $5
    ;;
    *)
        echo "no operation supplied"
    ;;
esac
