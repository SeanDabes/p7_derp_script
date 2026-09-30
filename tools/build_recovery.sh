#!/bin/bash
set -e

# ----------------------------------------------------------------------
# Recovery / vendor_boot preparation
# Ensures $out_rom_dir/<device>/vendor_boot.img exists, either by compiling
# it in userdebug variant (when recovery has new commits, signalled by the
# build_recovery flag) or by fetching the one from the last public release.
# ----------------------------------------------------------------------

build_recovery_vendor_boot() {
    local device="$1"
    local jobs="$2"

    local src_dir="out/target/product/$device/"
    local out_dir="$out_rom_dir/$device"
    local backup_file="$out_dir/vendor_boot.img"

    mkdir -p "$out_dir"

    if [ -n "${vendor_boot_override:-}" ]; then
        echo -e "${WHITEONMAGENTA}Using user-provided vendor_boot.img${NOCOLOR}"
        echo "  Source: $vendor_boot_override"
        echo "  Dest:   $backup_file"
        cp "$vendor_boot_override" "$backup_file"
        if [ -f "$backup_file" ]; then
            echo -e "${GREEN}OK${NOCOLOR}"
            return 0
        else
            echo -e "${RED}ERROR: could not copy vendor_boot.img${NOCOLOR}"
            exit 1
        fi
    fi

    cd "$derpfestdir" || { echo "Error: cannot enter $derpfestdir"; exit 1; }

    source build/envsetup.sh

    # En esta fase no queremos recompilar el kernel: sólo el vendor_boot.
    export SKIP_KERNEL_BUILD=true
    export SKIP_KERNEL_SYNC=true

    if [ "$build_recovery" = "true" ]; then
        echo -e "${WHITEONMAGENTA} Building recovery (userdebug) with $jobs jobs...${NOCOLOR}"
        lunch "lineage_$device-$android_version-userdebug"
        mka vendorbootimage -j "$jobs"

        echo -n "- Copying newly built vendor_boot.img..."
        cp "$src_dir/vendor_boot.img" "$backup_file"
        if [ -f "$backup_file" ]; then
            echo -e "${GREEN}OK${NOCOLOR}"
        else
            echo -e "${RED}KO${NOCOLOR}"
            exit 1
        fi
    else
        echo -e "${WHITEONMAGENTA} Recovery unchanged. Fetching prebuilt vendor_boot.img from last build...${NOCOLOR}"
        last_build_dir=$(rclone lsf --dirs-only $public_server:$public_dir | grep $last_build)
        echo "$last_build_dir"
        rclone -P copy "$public_server:$public_dir/$last_build_dir/$device/vendor_boot.img" "$out_dir"
        if [ ! -f "$backup_file" ]; then
            echo -e "${RED}ERROR: prebuilt vendor_boot.img not found at $out_dir${NOCOLOR}"
            exit 1
        fi
        echo -e "${GREEN}OK${NOCOLOR}"
    fi
}

if [ $# -lt 2 ]; then
    echo "Usage: $0 <device> <jobs>"
    exit 1
fi

build_recovery_vendor_boot "$1" "$2"
