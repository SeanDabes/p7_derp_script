#!/bin/bash
set -e

# Modular script to build the DerpFest ROM for the Pixel 7 family. By Sean Dabes.
# Mods are in a specific directory where can be added, removed, modified or (de)activated one by one without affecting the rest.

rm -f /tmp/build_recovery

ERROR=false
syncderp=false
synckernel=false
poweroff=false
root=false
info=false
originalbuild=false
upload=false
recovery=false
device=""
jobs=""
wait_duration=""
vendor_boot_override=""

SECONDS=0 # Timer start


export android_version="cp2a"
export derp_repo="https://github.com/DerpFest-AOSP/"
export derp_branch="17"
export los_branch="lineage-24"
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
export recovery_script="$toolsdir/build_recovery.sh"
export upload_script="$toolsdir/upload.sh"
export wait_script="$toolsdir/countdown.sh"
export changelog_script="$toolsdir/changelog.sh"
export derpfestdir="$rootdir/../derpfest_$derp_branch" # Change for own one
export build_recovery=""
export mods_state_file="$rootdir/.SDmods.state"

# Take last public ROM
export public_server="onedrive"
export public_dir="DerpFest"
export last_build=$(rclone lsf --dirs-only $public_server:$public_dir | sort -r | head -n 1 | cut -d "_" -f 1)


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
    # bash $banner_script nowait
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
    local -n array_ref="active_$2_mods"     # -n argument links to the actual variable

    : > "$mods_state_file"                  # estado limpio ANTES de correr los mods

    echo -e "${WHITEONMAGENTA} Applying $2 mods... ${NOCOLOR}"
    echo
    for j in "${!array_ref[@]}";do
        echo -ne "${YELLOW} $counter/$((num_active_$2_mods)) "
        bash "${array_ref[j]}" $1
        echo
        sleep 3
        counter=$((counter + 1))
    done

    if [ -s "$mods_state_file" ]; then       # solo si algún mod escribió algo
        echo -e "${WHITEONMAGENTA} Applying state from mods...${NOCOLOR}"
        source "$mods_state_file"
    fi

    : > "$mods_state_file"                  # dejarlo vacío al salir

    sleep 3
}

sync(){
    # bash $banner_script nowait
    echo -e "${WHITEONMAGENTA} Syncing DerpFest                  ${NOCOLOR}"
    if [ ! -d $derpfestdir ]; then
        echo -e "${GREEN}Preparing building instance...${NOCOLOR}"
        mkdir $derpfestdir
        cd $derpfestdir
        repo init -u "$derp_repo""android_manifest.git" -b $derp_branch --git-lfs
        git clone $local_manifest_url $local_manifest_dir -b $derp_branch
        if [ ! -d ".repo/local_manifests" ]; then mkdir ".repo/local_manifests"; fi
        cp $local_manifest_file .repo/local_manifests/
    else
        cd $derpfestdir
        echo -e "${GREEN}Updating local manifest...${NOCOLOR}"
        cd $local_manifest_dir
        git pull
        cd $derpfestdir
        cp $local_manifest_file .repo/local_manifests/
        echo -e "${GREEN}Cleaning source tree...${NOCOLOR}"
        for i in "${mods_scripts[@]}"; do
            bash $i clean
            done
    fi
    echo
    echo -e "${GREEN}Syncing...${NOCOLOR}"
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
    echo " -u, --upload          Uploads compiled files to server."
    echo "                       Use rclone to configure a server and set it in tools/upload.sh."
    echo " -w, --wait            Waits the supplied time before compiling."
    echo "                       Duration format: 10s, 5m, 1h30m20s, 2h, etc. (default 10s)"
    echo " -v, --vendor_boot <path> Uses the specified vendor_boot.img instead of"
    echo "                          compiling or downloading one."
    echo
    exit 1
}

# Using getopt for handling options
OPTIONS=$(getopt -o d:j:spinuw:rv: -l device:,jobs:,sync,poweroff,info,nomodules,upload,wait,recovery,vendor_boot: -- "$@")
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
        -u|--upload)
            upload=true
            shift
            ;;
        -w|--wait)
            wait_duration="$2"
            shift 2
            ;;
        -r|--recovery)
            build_recovery=true
            shift
            ;;
        -v|--vendor_boot)
            vendor_boot_override="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
    esac
done

if [ -n "$vendor_boot_override" ]; then
    if [ ! -f "$vendor_boot_override" ]; then
        echo -e "${RED}ERROR: vendor_boot.img not found at '$vendor_boot_override'${NOCOLOR}"
        exit 1
    fi
    vendor_boot_override=$(realpath "$vendor_boot_override")
    export vendor_boot_override
    echo -e "${YELLOW}Using user-provided vendor_boot.img: $vendor_boot_override${NOCOLOR}"
fi

if [ -z $jobs ]; then jobs=$(nproc --all); fi

if [ $info = true ]; then summary; fi

if [ ! -z $wait_duration ]; then bash $wait_script $wait_duration; fi

export start_date="$(date +%Y%m%d)"
export out_rom_dir="$derpfestdir/00_latest_builds/$start_date""_""$derp_branch/"

changelog(){
    # Generate changelog from last build
    bash "$changelog_script" "$last_build" "$derpfestdir" "$out_rom_dir/changelog_$start_date""_""$derp_branch"".txt"
}

if [ $syncderp = true ]; then sync; fi

case "$device" in
    "all")
        if [ $originalbuild = false ]; then apply_mods $device prebuild; fi

        bash $recovery_script cheetah $jobs
        bash $build_script cheetah $jobs
        if [ $ERROR = true ]; then continue; fi
        bash $recovery_script panther $jobs
        bash $build_script panther $jobs
        if [ $ERROR = true ]; then continue; fi
        bash $recovery_script lynx $jobs
        bash $build_script lynx $jobs
        if [ $ERROR = true ]; then continue; fi

        changelog
        ;;
    "panther" | "cheetah" | "lynx" )
        if [ $originalbuild = false ]; then apply_mods $device prebuild; fi

        bash $recovery_script $device $jobs
        bash $build_script $device $jobs
        ;;
    *)
        if [ $upload = true ]; then
            bash $upload_script
        else
            echo
            echo -e "${RED} No device provided ${NOCOLOR}"
            echo
            helpmsg
            exit 1
        fi
        ;;
esac

if [ $upload = true ]; then
    bash $upload_script
fi

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
