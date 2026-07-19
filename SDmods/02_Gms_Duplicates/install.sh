#!/bin/bash

# REMOVE DUPLICATED GMS APPS
# Some gms apps are duplicated in device tree and in gms vendor.
# To avoid errors while compiling, it's needed to remove one of the duplicates.
# I have chosen the ones from vendor to keep device tree as clean as possible.

# Module status, 1=active 0=inactive
modstatus=0
modname="Remove duplicated gms apps"
modtype=prebuild
workdir="$derpfestdir/vendor/gms"

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

workfile="$workdir/common/Android.bp"
applist=(
    CarrierSettings
    CarrierWifi
    WfcActivation
)

echo -e "${BLUE}$modname${NOCOLOR}"

modify(){
    # Use perl to remove complete blocks
    perl -e '
    use strict;
    use warnings;

    my $patron = shift @ARGV;
    my $in_block = 0;
    my $brace_count = 0;
    my @block_lines;
    my $skip_block = 0;

    while (my $line = <>) {
        # Detect the block android_app_import start
        if ($line =~ /^\s*android_app_import\s*\{\s*$/) {
            if (!$in_block) {
                $in_block = 1;
                $brace_count = 1;
                $skip_block = 0;
                @block_lines = ($line);
                next;
            }
        }

        if ($in_block) {
            push @block_lines, $line;

            # Count braces
            $brace_count += ($line =~ tr/{//);
            $brace_count -= ($line =~ tr/}//);

            # Verify if pattern is in name
            if ($line =~ /name:\s*"\Q$patron\E"/) {
                $skip_block = 1;
            }

            # If we reach the block end
            if ($brace_count == 0) {
                if (!$skip_block) {
                    print @block_lines;
                }

                $in_block = 0;
                $brace_count = 0;
                $skip_block = 0;
                @block_lines = ();
                next;
            }
            next;
        }

        # Print lines out of block
        print $line;
    }
    ' "$1" "$workfile" > "${workfile}.tmp" && mv "${workfile}.tmp" "$workfile"
}

for item in "${applist[@]}"; do
    echo -n "- $item..."
    modify $item
    if [[ -z $(grep $item $workfile) ]]; then
        echo -e "${GREEN}OK${NOCOLOR}"
    else
        echo -e "${RED}Error${NOCOLOR}"
    fi
    sleep 0.1
done
