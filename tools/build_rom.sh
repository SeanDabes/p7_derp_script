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
    local work_dir="$out_dir/work_dir"
    local ota_file="DerpFest-v$derp_branch-$start_date-$device-Official-Stable.zip"
    local backup_file="$out_dir/vendor_boot.img"

    if [[ $device == "panther" ]] || [[ $device == "cheetah" ]]; then
        local kernel_dir="device/google/pantah-kernels/6.1/"
    fi
    if [[ $device == "lynx" ]]; then
        local kernel_dir="device/google/$device-kernels/6.1/"
    fi

    mkdir -p "$out_dir"

    cd "$derpfestdir" || { echo "Error: cannot enter $derpfestdir"; exit 1; }

    # vendor_boot.img debe existir ya: lo prepara build_recovery.sh.
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}ERROR: vendor_boot.img not found at $backup_file${NOCOLOR}"
        echo -e "${RED}Did build_recovery.sh run first?${NOCOLOR}"
        exit 1
    fi

    if [ -f "device/google/gs201/wildkernel/Image.lz4" ]; then
        echo -e "${WHITEONMAGENTA}WildKernel present, using prebuilt kernel${NOCOLOR}"
        echo -n "- Copying WildKernel Image.lz4..."
        cp "device/google/gs201/wildkernel/Image.lz4" "$kernel_dir"
        if [ -f "$kernel_dir/Image.lz4" ]; then
            echo -e "${GREEN}OK${NOCOLOR}"
        else
            echo -e "${RED}KO${NOCOLOR}"
            exit 1
        fi
        export SKIP_KERNEL_BUILD=true
        export SKIP_KERNEL_SYNC=true
    else
        echo -e "${YELLOW}WildKernel not present, kernel will be built from source${NOCOLOR}"
    fi

    # ------------------------------------------------------------------
    # 1. Build target-files-package (user)
    # ------------------------------------------------------------------
    echo -e "\n${WHITEONMAGENTA} Building target-files-package (user) with $jobs jobs...${NOCOLOR}"
    source build/envsetup.sh
    lunch "lineage_$device-$android_version-user"

    echo -n "- Removing previous artifacts..."
    rm -rf "out/target/product/$device/obj/BOOTIMAGE*"
    rm -f "out/target/product/$device/vendor_boot.img"
    echo -e "${GREEN}OK${NOCOLOR}"

    mka target-files-package otatools -j "$jobs" || { echo -e "${RED}mka failed${NOCOLOR}"; exit 1; }
    echo -e "${GREEN}mka succeeded, continuing...${NOCOLOR}"

    # 2. Extract target-files
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

    if [ ! -f "$work_dir/IMAGES/vendor_boot.img" ]; then
        echo -e "${RED}ERROR: $work_dir/IMAGES/vendor_boot.img not found in target_files${NOCOLOR}"
        exit 1
    fi
    cp "$backup_file" "$work_dir/IMAGES/vendor_boot.img"
    if [ -f "$work_dir/IMAGES/vendor_boot.img" ]; then
        echo -e "${GREEN}vendor_boot.img replaced with userdebug version${NOCOLOR}"
    else
        echo -e "${RED}ERROR: could not replace vendor_boot.img${NOCOLOR}"
        exit 1
    fi

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

    # 4. Repack target-files
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

    # 5. Build OTA package
    echo -e "\n${WHITEONMAGENTA} Building OTA package...${NOCOLOR}"
    cd "$derpfestdir"
    export TMPDIR="$derpfestdir/tmp-ota"
    mkdir -p "$TMPDIR"
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

    # 6. Cleanup
    rm -rf "$work_dir" "$TMPDIR"

    # 7. SHA256 checksum
    cd "$out_dir"
    sha256sum "$ota_file" >> "$ota_file.sha256sum"
    cd "$derpfestdir"

    echo -e "\n${GREEN}Process completed successfully!${NOCOLOR}"
}

if [ $# -lt 2 ]; then
    echo "Usage: $0 <device> <jobs>"
    exit 1
fi

build_all "$1" "$2"
sleep 5
