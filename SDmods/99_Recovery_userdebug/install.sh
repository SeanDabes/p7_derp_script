#!/bin/bash

# Prepare environment to compile DerpFest recovery in userdebug variant

# Module status, 1=active 0=inactive
modstatus=1
modname="Recovery userdebug"
modtype=prebuild
workdir="$derpfestdir/bootable/recovery"

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
esac

echo -e "${BLUE}$modname${NOCOLOR}"
if [ -z $build_recovery ]; then
    echo -n "- Checking $workdir..."
    last_recovery_commit_date=$(git -C $workdir log -1 --format=%cd --date=format:%Y%m%d 2>/dev/null || echo "19700101")

    if [ "$last_recovery_commit_date" -gt "$last_build" ]; then
        echo -e "${YELLOW}There are new commits, recovery must be recompiled${NOCOLOR}"
        build_recovery=true
    else
        echo -e "${GREEN}Recovery is up to date, skip building${NOCOLOR}"
    fi
fi
if [[ $build_recovery == "true" ]]; then
    echo -e "${YELLOW}Recovery has been forced to be recompiled${NOCOLOR}"
fi
