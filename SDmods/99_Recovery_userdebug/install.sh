#!/bin/bash

# Prepare environment to compile DerpFest recovery in userdebug variant
# If there are not new commits in recovery repo, download it from last public release
# and save compiling time

# Module status, 1=active 0=inactive
modstatus=1
modname="Recovery userdebug"
modtype=prebuild
workdir="$derpfestdir/bootable/recovery"

userdebug_recovery(){
    if [ -z $build_recovery ]; then
        echo -n "- Checking $workdir..."
        last_recovery_commit_date=$(git -C $workdir log -1 --format=%cd --date=format:%Y%m%d 2>/dev/null || echo "19700101")

        if [ "$last_recovery_commit_date" -gt "$last_build" ]; then
            echo -e "${YELLOW}There are new commits, recovery must be recompiled${NOCOLOR}"
            build_recovery=true
        else
            echo -e "${GREEN}Recovery is up to date${NOCOLOR}"
            echo "- Getting vendor_boot from last public release..."
            out_recovery_dir="$out_rom_dir/$1"
            if [ ! -d $out_recovery_dir ]; then
                mkdir -p $out_recovery_dir
            fi
            rclone -P copy "$public_server":"$public_dir/$last_build""_$derp_branch/$1/vendor_boot.img" $out_recovery_dir
            if [ -f "$out_recovery_dir/vendor_boot.img" ]; then
                echo -e "${GREEN}File successfully downloaded${NOCOLOR}"
            else
                echo -e "${RED}File NOT downloaded${NOCOLOR}"
                exit 1
            fi
        fi
    fi
    if [[ $build_recovery == "true" ]]; then
        echo -e "${YELLOW}Recovery has been forced to be recompiled${NOCOLOR}"
    fi
}

case $1 in
    "enum")
        echo $modname
        exit
    ;;
    "clean")
        echo -n "- $modname..."
        cd $workdir
        git reset --hard &> /dev/null
        echo -e "${GREEN}OK${NOCOLOR}"
        exit
    ;;
    "panther" | "cheetah" | "lynx")
        echo -e "${BLUE}$modname for $1${NOCOLOR}"
        userdebug_recovery $1
    ;;
    "all")
        echo -e "${BLUE}$modname for all supported devices${NOCOLOR}"
        devices=(cheetah panther lynx)
        for item in "${devices[@]}"; do
            echo "Device: "$item
            userdebug_recovery $item
        done
    ;;
esac

