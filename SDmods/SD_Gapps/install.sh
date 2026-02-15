#!/bin/bash

# CHANGE GAPPS TO THE SEANDABES' ONES
# Ensure local manifest fetches from https://codeberg.org/SeanDabes/android_vendor_gapps to vendor/gapps

# Module status, 1=active 0=inactive
modstatus=1
modname="Gapps by SeanDabes"
modtype=prebuild
workdir="$derpfestdir/vendor/lineage"
workdir2="$derpfestdir/vendor/gms"

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
pattern="vendor/gms/products/gms.mk"
pattern2="vendor/gapps/arm64/arm64-vendor.mk"

echo -e "${BLUE}$modname enabling${NOCOLOR}"
echo -n "- Checking file..."
before=$(grep $pattern $workfile | cut -d \" -f 4)
if [[ $before = $new_value ]]; then
    echo -e "${GREEN}File already OK${NOCOLOR}"
else
    echo -e "${YELLOW}File with wrong value${NOCOLOR}"
    echo -n "- Modifying $workfile..."
    if [ -f $workfile ]; then
        pattern="${pattern//\//\\/}"
        curr_value=$pattern
        new_value="${pattern2//\//\\/}"

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

sleep 0.1

echo -n "- Avoiding duplicated definitions..."
filename="Android.bp"
suffix="_sd"
for file in $(find $workdir2 -name $filename); do
    mv "$file" "$file""$suffix"
done
if [ -z $(find $workdir2 -name $filename) ]; then
    echo -e "${GREEN}OK${NOCOLOR}"
else
    echo -e "${YELLOW}Some items could not be changed${NOCOLOR}"
fi
