#!/bin/bash
set -e

# ----------------------------------------------------------------------
# Main build function
# ----------------------------------------------------------------------
build_all() {
    local device="$1"
    local jobs="$2"

    local src_dir="out/target/product/$device/"
    local target_files_zip="lineage_$device-target_files.zip"
    local out_dir="$out_rom_dir/$device"
    # local recovery_dir="out_vendor_boot/$device"
    local work_dir="$out_dir/work_dir"
    local ota_file="DerpFest-v$derp_branch-$start_date-$1-Official-Stable.zip"
    if [[ $device == "panther" ]] || [[ $device == "cheetah" ]]; then
        local kernel_dir="device/google/pantah-kernels/6.1/"
    fi
    if [[ $device == "lynx" ]]; then
        local kernel_dir="device/google/$device-kernels/6.1/"
    fi
    mkdir -p "$out_dir"

    cd "$derpfestdir" || { echo "Error: cannot enter $derpfestdir"; exit 1; }
    # mkdir -p "$recovery_dir"

    source build/envsetup.sh

    # 0. Build vendor_boot with WildKernel and userdebug recovery
    if [[ $build_recovery == "true" ]]; then
        echo -e "${WHITEONMAGENTA} Building recovery...${NOCOLOR}"
        lunch "lineage_$device-$android_version-userdebug"
        # bash "$modsdir/98_WildKernel/install.sh" "postlunch_hook" "$device" # Hook to install WildKernel
        echo -e "\n${WHITEONMAGENTA} Building vendor_boot with $jobs jobs...${NOCOLOR}"
        mka vendorbootimage -j "$jobs"

        echo -n "- Copying vendor_boot.img..."
        cp "$src_dir/vendor_boot.img" "$out_dir"
        if [ -f "$out_dir/vendor_boot.img" ]; then
            echo -e "${GREEN}OK${NOCOLOR}"
        else
            echo -e "${RED}KO${NOCOLOR}"
            exit 1
        fi
    fi

    # 1. Build target-files-package (user)
    echo -e "\n${WHITEONMAGENTA} Building target-files-package (user) with $jobs jobs...${NOCOLOR}"
    if [ -f "$kernel_dir/Image.lz4" ]; then   # Ensure the Image.lz4 is at the correct location
        echo "${GREEN}Kernel image found, going ahead${NOCOLOR}"
    else
        echo "${RED}Kernel image NOT found, stopping. Verify the correct download in previous mod.${NOCOLOR}"
        exit 1
    fi
    export SKIP_KERNEL_BUILD=true
    export SKIP_KERNEL_SYNC=true
    source build/envsetup.sh
    lunch "lineage_$device-$android_version-user"
    # Copy WildKernel image to proper directory
    echo -n "- Copying WildKernel Image.lz4..."
    cp "device/google/gs201/wildkernel/Image.lz4" "$kernel_dir"
    if [ -f "$kernel_dir/Image.lz4" ]; then
        echo -e "${GREEN}OK${NOCOLOR}"
    else
        echo -e "${RED}KO${NOCOLOR}"
        exit 1
    fi
    echo -n "- Removing previous artifacts..." # Just in case
    rm -rf "out/target/product/$device/obj/BOOTIMAGE*"
    rm -f "out/target/product/$device/vendor_boot.img"
    echo -e "${GREEN}OK${NOCOLOR}"

    # Monitor to keep an eye on vendor_boot (next mka deletes it as it changes from userdebur to user)
    echo -e "\n${WHITEONMAGENTA} Starting vendor_boot monitor...${NOCOLOR}"
    local backup_file="$out_dir/vendor_boot.img"
    local target_dir="out/target/product/$device"
    local target_file="$target_dir/vendor_boot.img"

    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}ERROR: vendor_boot.img backup not found in $out_dir${NOCOLOR}"
        exit 1
    fi

    mkdir -p "$target_dir"

    # Function to restore file
    restore_vendor_boot() {
        if [ ! -f "$target_file" ]; then
            mkdir -p "$target_dir"
            cp "$backup_file" "$target_file"
            echo -e "${GREEN}Restored vendor_boot.img${NOCOLOR}"
        fi
    }

    (
        while true; do
            restore_vendor_boot
            sleep 1
        done
    ) &
    MONITOR_PID=$!
    echo -e "${GREEN}Monitor started with PID $MONITOR_PID${NOCOLOR}"

    # Ejecutar mka
    mka target-files-package otatools -j "$jobs" || { echo -e "${RED}mka failed${NOCOLOR}"; exit 1; }
    echo -e "${GREEN}mka succeeded, continuing...${NOCOLOR}"

    # Kill monitor (forcefully)
    kill $MONITOR_PID 2>/dev/null

    # 2. Extract target-files into a temporary directory
    echo -e "\n- Uncompressing target_files..."
    echo -e "${WHITEONMAGENTA}Extracting and preparing images...${NOCOLOR}                          " > /tmp/build_phase
    local target_files_path="$src_dir/obj/PACKAGING/target_files_intermediates/$target_files_zip"
    if [ ! -f "$target_files_path" ]; then
        echo -e "${RED}ERROR: $target_files_path not found. Aborting.${NOCOLOR}"
        exit 1
    fi
    rm -rf "$work_dir"
    mkdir -p "$work_dir"
    unzip -q "$target_files_path" -d "$work_dir"

    # 3. Copy images
    echo -e "\n- Copying images..."
    local images=(boot.img dtbo.img init_boot.img vendor_kernel_boot.img vbmeta.img)
    local error_occurred=false
    for img in "${images[@]}"; do
        echo -n "$img..."
        if [ -f "$work_dir/IMAGES/$img" ]; then
            cp "$work_dir/IMAGES/$img" "$out_dir"
            if [ -f "$out_dir/$img" ]; then
                echo -e "${GREEN}OK${NOCOLOR}"
            else
                echo -e "${RED}ERROR${NOCOLOR}"
                error_occurred=true
            fi
        else
            echo -e "${RED}NOT FOUND${NOCOLOR}"
            error_occurred=true
        fi
    done
    if [ "$error_occurred" = true ]; then
        echo -e "${RED}Some images were not found or could not be copied. Aborting.${NOCOLOR}"
        exit 1
    fi

    # 4. Patch kernel info in package
    echo "6.1.0" > "$work_dir/META/kernel_version.txt" || { echo -e "${RED}Error: could nopt apply patch${NOCOLOR}"; exit 1; }

    # 5. Repack target-files
    echo -e "${WHITEONMAGENTA}Repacking target files...${NOCOLOR}"
    cd "$work_dir"
    if ! zip -q -r -y -X -0 "target_files_mod.zip" .; then
        echo -e "${RED}ERROR: zip failed.${NOCOLOR}"
        exit 1
    fi
    if [ ! -f "target_files_mod.zip" ]; then
        echo -e "${RED}ERROR: target_files_mod.zip not created.${NOCOLOR}"
        exit 1
    fi
    echo -e "${GREEN}OK${NOCOLOR}"

    # 6. Build OTA package (return to ROM root)
    echo -e "\n${WHITEONMAGENTA} Building OTA package...${NOCOLOR}"
    cd "$derpfestdir"   # Important: go back to the source root
    export TMPDIR="$derpfestdir/tmp-ota"
    # export TMP="$derpfestdir/tmp-ota"
    # export TEMP="$derpfestdir/tmp-ota"
    mkdir -p "$TMPDIR"
    # chmod 777 $TMPDIR
    if ! command -v ota_from_target_files >/dev/null 2>&1; then
        echo -e "${RED}ERROR: ota_from_target_files not found.${NOCOLOR}"
        exit 1
    fi
    if ! ota_from_target_files "$work_dir/target_files_mod.zip" "$out_dir/$ota_file"; then
        echo -e "${RED}ERROR: ota_from_target_files failed.${NOCOLOR}"
        exit 1
    fi
    if [ ! -f "$out_dir/$ota_file" ]; then
        echo -e "${RED}ERROR: OTA file not generated at $out_dir/$ota_file.${NOCOLOR}"
        exit 1
    fi

    # 7. Cleanup
    rm -rf "$work_dir" "$TMPDIR"

    # 8. SHA256 checksum
    cd "$out_dir"
    sha256sum "$ota_file" >> "$ota_file.sha256sum"
    cd "$derpfestdir"

    echo -e "\n${GREEN}Process completed successfully!${NOCOLOR}"
}

# ----------------------------------------------------------------------
# Execute build_all directly (no tmux)
# ----------------------------------------------------------------------
if [ $# -lt 2 ]; then
    echo "Usage: $0 <device> <jobs>"
    exit 1
fi

build_all "$1" "$3"
sleep 5
