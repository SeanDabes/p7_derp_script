#!/bin/bash

# ENABLE VIPER4ANDROID EFFECTS
# Viper4Android requires to work some hacks.
# First, it requires the app itself
# Then, sepolicy rules
# Finally, patch audio_effects.xml to include library and effects.
# More info at https://github.com/TogoFire/packages_apps_ViPER4AndroidFX
#
# Until now, the audio_effects.xml part has been done in device tree, but in Android 16 QPR2 this file has been moved to vendor.
# This repo is a LFS one, that is a nightmare to push. So we are patching audio_effects before compiling.

# Module status, 1=active 0=inactive
modstatus=1
modname="Viper4Android audio_effects.xml"
modtype=prebuild
workdir="$derpfestdir/vendor/google/$1"
workfile="$workdir/proprietary/vendor/etc/audio_effects.xml"

case $1 in
    "enum")
        echo $modname
        exit
    ;;
    "clean")
        echo -n "- $modname..."
        workdir="$derpfestdir/vendor/google"
        if [ -d "$workdir/cheetah" ]; then
            cd "$workdir/cheetah"
            git reset --hard &> /dev/null
        fi
        if [ -d "$workdir/panther" ]; then
            cd "$workdir/panther"
            git reset --hard &> /dev/null
        fi
        if [ -d "$workdir/lynx" ]; then
            cd "$workdir/lynx"
            git reset --hard &> /dev/null
        fi
        echo -e "${GREEN}OK${NOCOLOR}"
        exit
    ;;
esac

echo -e "${BLUE}$modname patching${NOCOLOR}"

pattern1="    </libraries>"
pattern2="    </effects>"
addline1='        <library name="v4a_re" path="libv4a_re.so"/>'
addline2='        <effect name="v4a_standard_re" library="v4a_re" uuid="90380da3-8536-4744-a6a3-5731970e640f"/>'

check1=false
check2=false

check(){
    if [ $(grep -c "$addline1" "$workfile") = 1 ]; then check1=true; fi
    if [ $(grep -c "$addline2" "$workfile") = 1 ]; then check2=true; fi
}

check

echo -n "- Adding library..."
if $check1; then
    echo -e "${GREEN}Patch already applied${NOCOLOR}"
else
    sed -i "s|$pattern1|$addline1\n$pattern1|g" "$workfile"
    check
    if $check1; then
        echo -e "${GREEN}OK${NOCOLOR}"
    else
        echo -e "${RED}Patch has not been applied${NOCOLOR}"
    fi
fi

sleep 0.1

echo -n "- Adding effect..."
if $check2; then
    echo -e "${GREEN}Patch already applied${NOCOLOR}"
else
    sed -i "s|$pattern2|$addline2\n$pattern2|g" "$workfile"
    check
    if $check2; then
        echo -e "${GREEN}OK${NOCOLOR}"
    else
        echo -e "${RED}Patch has not been applied${NOCOLOR}"
    fi
fi
