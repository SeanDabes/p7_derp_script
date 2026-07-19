#!/bin/bash

# ENABLE DOCUMENTSUI FROM LINEAGEOS
# DerpFest hides by default the DocumentsUI app from launcher.
# This mod deactivates this feature to show again this app.

# Module status, 1=active 0=inactive
modstatus=1
modname="DocumentsUI"
modtype=prebuild
workdir="$derpfestdir/vendor/lineage"

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

workfile="$workdir/config/permissions/derpfest-sysconfig.xml"
pattern="documentsui.LauncherActivity"
curr_value="false"
new_value="true"

echo -e "${BLUE}$modname enabling${NOCOLOR}"
echo -n "- Checking file..."
before=$(grep $pattern $workfile | cut -d \" -f 4)
if [[ $before = $new_value ]]; then
    echo -e "${GREEN}File already OK${NOCOLOR}"
else
    echo -e "${YELLOW}File with wrong value${NOCOLOR}"
    echo -n "- Modifying $workfile..."
    if [ -f $workfile ]; then
        sed -i "/$pattern/s/$curr_value/$new_value/" "$workfile"
        after=$(grep $pattern $workfile | cut -d \" -f 4)
        if [[ $before != $after ]]; then
            echo -e "${GREEN}OK${NOCOLOR}"
        else
            echo -e "${RED}File not changed${NOLOCOR}"
        fi
    else
        echo -e "${RED}File not found${NOCOLOR}"
    fi
fi
