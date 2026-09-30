#!/bin/bash

# REMOVE DUPLICATED GMS APPS
# Some gms apps are duplicated in device tree and in gms vendor.
# To avoid errors while compiling, it's needed to remove one of the duplicates.
# I have chosen the ones from vendor to keep device tree as clean as possible.

# Module status, 1=active 0=inactive
modstatus=1
modname="Remove duplicated gms apps"
modtype=prebuild
workdir="$derpfestdir/vendor/pixel/gms"
gappsdir="$derpfestdir/vendor/gapps"

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

# --- 1. Getting vendor/gapps modules ---
echo -n "- vendor/gapps modules: "
gapps_list=$(mktemp)
find "$gappsdir" -name "Android.bp" -type f 2>/dev/null | while read -r f; do
    grep -E '^\s*name:\s*"' "$f" | sed -E 's/^\s*name:\s*"([^"]+)".*/\1/'
done | sort -u > "$gapps_list"
echo $(wc -l < "$gapps_list")

# --- 2. Getting vendor/pixel/gms modules ---
echo -n "- vendor/pixel/gms modules: "
gms_list=$(mktemp)
find "$workdir" -name "Android.bp" -type f 2>/dev/null | while read -r f; do
    grep -E '^\s*name:\s*"' "$f" | sed -E 's/^\s*name:\s*"([^"]+)".*/\1/'
done | sort -u > "$gms_list"
echo $(wc -l < "$gms_list")

# --- 3. Find duplicates ---
duplicates=$(mktemp)
comm -12 "$gapps_list" "$gms_list" > "$duplicates"
dup_count=$(wc -l < "$duplicates")

if [ "$dup_count" -eq 0 ]; then
    echo -e "${GREEN}  There are no duplicates.${NOCOLOR}"
    rm -f "$gapps_list" "$gms_list" "$duplicates"
    exit 0
fi

echo -e "${YELLOW}  Duplicates found ($dup_count):${NOCOLOR}"
sed 's/^/    - /' "$duplicates"

# --- 4. Remove duplicated entries in vendor/pixel/gms ---
modify() {
    local patron="$1"
    local workfile="$2"
    perl -e '
    use strict;
    use warnings;

    my $patron = shift @ARGV;
    my $in_block = 0;
    my $brace_count = 0;
    my @block_lines;
    my $skip_block = 0;

    while (my $line = <>) {
        # Detectar inicio de bloque de nivel superior (sin indentación)
        if (!$in_block && $line =~ /^[a-z_][a-z0-9_]*\s*\{\s*$/) {
            $in_block = 1;
            $brace_count = 0;
            $skip_block = 0;
            @block_lines = ($line);
            $brace_count += ($line =~ tr/{//);
            $brace_count -= ($line =~ tr/}//);
            next;
        }

        if ($in_block) {
            push @block_lines, $line;
            $brace_count += ($line =~ tr/{//);
            $brace_count -= ($line =~ tr/}//);

            # Verificar si el patrón está en la línea de name
            if ($line =~ /^\s*name:\s*"\Q$patron\E"\s*(,|$)/) {
                $skip_block = 1;
            }

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

        print $line;
    }
    ' "$patron" "$workfile" > "${workfile}.tmp" && mv "${workfile}.tmp" "$workfile"
}

echo "- Removing duplicated entries in vendor/pixel/gms..."
find "$workdir" -name "Android.bp" -type f 2>/dev/null | while read -r bpfile; do
    while IFS= read -r dup; do
        if grep -qE "^\s*name:\s*\"${dup}\"\s*(,|$)" "$bpfile"; then
            echo -n "    - $dup ($(basename "$bpfile"))... "
            modify "$dup" "$bpfile"
            if grep -qE "^\s*name:\s*\"${dup}\"\s*(,|$)" "$bpfile"; then
                echo -e "${RED}Error${NOCOLOR}"
            else
                echo -e "${GREEN}OK${NOCOLOR}"
            fi
        fi
    done < "$duplicates"
done

rm -f "$gapps_list" "$gms_list" "$duplicates"
echo -e "${GREEN}  Completed.${NOCOLOR}"
