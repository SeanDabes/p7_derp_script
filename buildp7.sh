#!/bin/bash

# Modular script to build the DerpFest ROM for the Pixel 7 family. By Sean Dabes.
# Mods are in a specific directory where can be added, removed, modified or (de)activated one by one without affecting the rest.
# Also, a beautiful look has been applied thanks to terminal colors and tmux. Why? Because terminal can be nice and because I was bored :)
# To build from ground, tmux has to be installed and enough space has to be ensured (about 600GB).
# The command to build the whole family from ground is ./buildp7.sh -s -d all

ERROR=false
syncderp=false
synckernel=false
poweroff=false
root=false
info=false
originalbuild=false
device=""
jobs=""

SECONDS=0 # Timer start


export android_version="bp4a"
export derp_repo="https://github.com/DerpFest-LOS/"
export derp_branch="16.2"
export los_branch="lineage-23.2"
export los_repo="https://github.com/LineageOS/"
export local_manifest_url="git@github.com:SeanDabes/derp_local_manifest_p7.git"

local_manifest_dir="derp_local_manifest_p7"
local_manifest_file="$local_manifest_dir/roomservice_seandabes.xml"
export rootdir=$(pwd)
export toolsdir="$rootdir/tools"
export modsdir="$rootdir/SDmods"
export banner_script="$toolsdir/banner.sh"
export monitor_script="$toolsdir/monitor.sh"
export build_script="$toolsdir/build_rom.sh"
export derpfestdir="$rootdir/../derpfest" # Change for own one

modscounter=0

# Terminal Colors
export readonly BLUE='\033[1;34m'
export readonly GREEN='\033[1;32m'
export readonly YELLOW='\033[1;33m'
export readonly RED='\033[1;31m'
export readonly CYAN='\033[1;36m'
export readonly MAGENTA='\033[1;35m'
export readonly GRAY='\033[1;90m'
export readonly WHITE='\033[1;37m'
export readonly NOCOLOR='\033[0m'
export readonly BOLD='\033[1m'
export readonly DIM='\033[2m'
export readonly WHITEONBLUE='\033[1;37;44m'
export readonly WHITEONMAGENTA='\033[1;37;45m'
export readonly WHITEONYELLOW='\033[1;37;43m'
export readonly WHITEONCYAN='\033[1;37;46m'
export readonly WHITEONRED='\033[1;37;41m'
colors=("$BLUE" "$GREEN" "$YELLOW" "$RED" "$CYAN" "$MAGENTA" "$GRAY" "$WHITE")

init(){
    # Ensuring permissions
    for file in $(find $modsdir | grep install.sh); do
        chmod -vR +x $file
    done
}

get_mod_property(){
    local line=$(grep -m 1 "$2" "$1")
    eval "echo $line" | cut -d '=' -f 2 | xargs
}

mods_scripts=()
mods_dirs=()
mods_status=()
active_prebuild_mods=()
active_postbuild_mods=()
while IFS= read -r line; do
    mods_scripts+=("$line")
    mods_dirs+=("$(dirname $line)")
    mods_status+=("$(get_mod_property $line modstatus)")
    if [ $(get_mod_property $line modstatus) = 1 ]; then
        if [ $(get_mod_property $line modtype) = prebuild ]; then
            active_prebuild_mods+=("$line")
        fi
        if [ $(get_mod_property $line modtype) = postbuild ]; then
            active_postbuild_mods+=("$line")
        fi
    fi
done < <(find $modsdir -type f -name "install.sh" | sort)

# Counting mods
export num_total_mods=${#mods_scripts[@]}
export num_active_prebuild_mods=${#active_prebuild_mods[@]}
export num_active_postbuild_mods=${#active_postbuild_mods[@]}

summary(){
    bash $banner_script nowait "" $android_version $los_branch
    echo -e "${WHITEONBLUE}Total mods: $numtotalmods ${NOCOLOR}"
    echo

    # Iterate arrays to get info from them
    for i in "${!mods_scripts[@]}"; do
        local file="${mods_scripts[i]}"
        local dir="${mods_dirs[i]}"
        echo -ne "${BLUE}$($file enum): "
        if [ "${mods_status[i]}" = 1 ]; then
            echo -e "${GREEN}Active${NOCOLOR}"
        else
            echo -e "${RED}Inactive${NOCOLOR}"
        fi
        echo "  Type: $(get_mod_property $file modtype)"
        echo "Folder: $dir"
        echo "  File: $file"
        echo
    done
    exit
}

apply_mods(){
    local counter=1
    local -n array_ref="active_$2_mods" # -n argument links to the actual variable
    for j in "${!array_ref[@]}";do
        bash $banner_script nowait $device $android_version $los_branch
        echo -e "${WHITEONMAGENTA} Applying $2 mods... ${NOCOLOR}"
        echo
        echo -ne "${YELLOW} $counter/$((num_active_$2_mods)) "
        bash "${array_ref[j]}" $1
        sleep 3
        counter=$((counter + 1))
    done

    sleep 3
}

sync(){
    bash $banner_script nowait $device $android_version $los_branch
    echo -e "${WHITEONMAGENTA} Syncing DerpFest                  ${NOCOLOR}"
    if [ ! -d $derpfestdir ]; then
        echo "Preparing building instance..."
        mkdir $derpfestdir
        cd $derpfestdir
        repo init -u "$derp_repo""android_manifest.git" -b $derp_branch --git-lfs
        git clone $local_manifest_url $local_manifest_dir
        if [ ! -d ".repo/local_manifests" ]; then mkdir ".repo/local_manifests"; fi
        cp $local_manifest_file .repo/local_manifests/
    else
        echo "Cleaning source tree..."
        for i in "${mods_scripts[@]}"; do
            bash $i clean
            done
    fi
    echo
    echo "Syncing..."
    cd $derpfestdir
    repo sync --force-sync -c -j 8
    sleep 5

    if [ -z $device ]; then exit; fi
}

helpmsg(){
    echo "Script to build DerpFest for Google Pixel 7 series"
    echo
    echo "Usage:"
    echo " -d, --device <device> Specifies the device to build for (panther, cheetah, lynx or all)."
    echo " -j, --jobs <jobs>     Specifies the maximum jobs when compiling."
    echo "                       If not supplied, all processor threads will be used."
    echo " -s, --sync            Downloads sources."
    echo " -p, --poweroff        Determines whether the computer should be turned off when finished."
    echo " -i, --info            Show info related to modules."
    echo " -n, --nomodules       Builds the ROM without Sean Dabes' modules, DerpFest as is."
    echo
    exit 1
}

# Using getopt for handling options
OPTIONS=$(getopt -o d:j:spin -l device:,jobs:,sync,poweroff,info,nomodules -- "$@")
eval set -- "$OPTIONS"

while true; do
    case "$1" in
        -d|--device)
            device="$2"
            shift 2
            ;;
        -s|--sync)
            syncderp=true
            shift
            ;;
        -p|--poweroff)
            poweroff=true
            shift
            ;;
        -j|--jobs)
            jobs="$2"
            shift 2
            ;;
        -i|--info)
            info=true
            shift
            ;;
        -n|--nomodules)
            originalbuild=true
            shift
            ;;
        --)
            shift
            break
            ;;
    esac
done

if [ -z $jobs ]; then jobs=$(nproc --all); fi

if [ $info = true ]; then summary; fi

if [ $syncderp = true ]; then sync; fi

case "$device" in
    "all")
        bash $banner_script nowait $device $android_version $los_branch
        if [ $originalbuild = false ]; then apply_mods $device prebuild; fi

        bash $build_script cheetah rom $jobs
        if [ $ERROR = true ]; then continue; fi
        bash $build_script panther rom $jobs
        if [ $ERROR = true ]; then continue; fi
        bash $build_script lynx rom $jobs
        if [ $ERROR = true ]; then continue; fi

        bash $build_script cheetah recovery $jobs
        if [ $ERROR = true ]; then continue; fi
        bash $build_script panther recovery $jobs
        if [ $ERROR = true ]; then continue; fi
        bash $build_script lynx recovery $jobs
        if [ $ERROR = true ]; then continue; fi
        ;;
    "panther" | "cheetah" | "lynx" )
        bash $banner_script nowait $device $android_version $los_branch
        if [ $originalbuild = false ]; then apply_mods $device prebuild; fi

        bash $build_script $device rom $jobs
        if [ $ERROR = true ]; then continue; fi

        bash $build_script $device recovery $jobs
        if [ $ERROR = true ]; then continue; fi
        ;;
    *)
        echo
        echo -e "${RED} No device provided ${NOCOLOR}"
        echo
        helpmsg
        exit 1
        ;;
esac


elapsed_time=$SECONDS # Timer tick
secs=$((elapsed_time % 60))
mins=$(( (elapsed_time % 3600) / 60 ))
hours=$((elapsed_time / 3600))
if [ $secs -lt 10 ]; then secs="0$secs"; fi
if [ $mins -lt 10 ]; then mins="0$mins"; fi
if [ $hours -lt 10 ]; then hours="0$hours"; fi

echo -e "${YELLOW}┌──────────────────┐${NOCOLOR}"
echo -e "${YELLOW}│ ${CYAN}Time spent:      ${YELLOW}│${NOCOLOR}"
echo -e "${YELLOW}│ ${WHITEONMAGENTA} "$hours"h "$mins"m "$secs"s ${NOCOLOR}    ${YELLOW}│${NOCOLOR}"
echo -e "${YELLOW}└──────────────────┘${NOCOLOR}"


if [ $poweroff = true ]; then
    timer=10
    timercolor=""
    echo -e "${WHITEONMAGENTA}Switching off computer in $timer seconds        ${NOCOLOR}"
    for (( i = $timer; i >= 0; i-- )); do
        if [ $i != 0 ]; then
            if [ $(($timer/$i)) = 1 ]; then timercolor=${GREEN}; fi
            if [ $(($timer/$i)) = 2 ]; then timercolor=${YELLOW}; fi
            if [ $(($timer/$i)) = 3 ]; then timercolor=${RED}; fi
            echo -ne "$timercolor████${NOCOLOR}"
        else
            echo -ne "${RED}████${NOCOLOR}"
        fi
        sleep 1
    done
    echo
    systemctl poweroff
fi
