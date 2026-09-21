#!/bin/bash

# CHANGE GAPPS TO THE SEANDABES' ONES
# Ensure local manifest fetches from https://codeberg.org/SeanDabes/android_vendor_gapps to vendor/gapps

# Module status, 1=active 0=inactive
modstatus=1
modname="Gapps by SeanDabes"
modtype=prebuild
workdir="$derpfestdir/vendor/lineage"
workdir2="$derpfestdir/vendor/pixel/gms"

case $1 in
    "enum")
        echo $modname
        exit
    ;;
    "clean")
        echo -n "- $modname..."
        for item in $workdir $workdir2; do
            cd $item
            git reset --hard &> /dev/null
        done
        echo -e "${GREEN}OK${NOCOLOR}"
        exit
    ;;
esac

workfile="$workdir/config/derpfest.mk"
old_mk="vendor/pixel/gms/products/gms.mk"     # lo que hay que sustituir
new_mk="vendor/gapps/arm64/arm64-vendor.mk"  # lo que queremos poner

echo -e "${BLUE}$modname enabling${NOCOLOR}"
echo -n "- Checking file..."

# ¿ya está aplicado?
if grep -qF "$new_mk" "$workfile"; then
    echo -e "${GREEN}File already OK${NOCOLOR}"
else
    echo -e "${YELLOW}File with wrong value${NOCOLOR}"
    echo -n "- Modifying $workfile..."
    if [ -f "$workfile" ]; then
        # escapa solo para sed
        old_sed="${old_mk//\//\\/}"
        new_sed="${new_mk//\//\\/}"
        sed -i "s/$old_sed/$new_sed/" "$workfile"

        if grep -qF "$new_mk" "$workfile"; then
            echo -e "${GREEN}OK${NOCOLOR}"
        else
            echo -e "${RED}File not changed${NOCOLOR}"   # ojo: tenías NOLOCOR
        fi
    else
        echo -e "${RED}File not found${NOCOLOR}"
    fi
fi
