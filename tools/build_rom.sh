#!/bin/bash
set -e
set -u

# ----------------------------------------------------------------------
# Pane 1: status animation (runs in tmux, reads /tmp/build_phase)
# ----------------------------------------------------------------------
spinner_animation() {
    local spinner=(
        '▕                    ▏'
        '▕▒                   ▏'
        '▕▒▒                  ▏'
        '▕▒▒▒                 ▏'
        '▕ ▒▒▒                ▏'
        '▕  ▒▒▒               ▏'
        '▕   ▒▒▒              ▏'
        '▕    ▒▒▒             ▏'
        '▕     ▒▒▒            ▏'
        '▕      ▒▒▒           ▏'
        '▕       ▒▒▒          ▏'
        '▕        ▒▒▒         ▏'
        '▕         ▒▒▒        ▏'
        '▕          ▒▒▒       ▏'
        '▕           ▒▒▒      ▏'
        '▕            ▒▒▒     ▏'
        '▕             ▒▒▒    ▏'
        '▕              ▒▒▒   ▏'
        '▕               ▒▒▒  ▏'
        '▕                ▒▒▒ ▏'
        '▕                 ▒▒▒▏'
        '▕                  ▒▒▏'
        '▕                   ▒▏'
    )
    local phase=""

    while [ ! -f /tmp/end_task ]; do
        if [ -f /tmp/build_phase ]; then
            phase=$(cat /tmp/build_phase)
        else
            phase="Waiting for build to start..."
        fi

        for i in "${spinner[@]}"; do
            printf "\033[2;2H"   # Move to row 2, col 2
            printf "%s\n" "$phase"
            printf "\033[4;2H"   # Move to row 4, col 2
            printf "%s" "$i"
            sleep 0.1
            [ -f /tmp/end_task ] && break
        done
    done
    echo -e "\n\n${BLUE}Build completed. Cooling down...${NOCOLOR}"
    sleep 5
    rm -f /tmp/build_phase /tmp/end_task
    tmux kill-session -t derp_session
}

# ----------------------------------------------------------------------
# Main build function (runs in pane 2)
# ----------------------------------------------------------------------
build_all() {
    local device="$1"
    local jobs="$2"

    local src_dir="out/target/product/$device/"
    local target_files_zip="lineage_$device-target_files.zip"
    local out_dir="$out_rom_dir/$device"
    local work_dir="$out_dir/work_dir"
    local ota_file="DerpFest-v$derp_branch-$start_date-$1-Official-Stable.zip"

    mkdir -p "$out_dir"

    cd "$derpfestdir" || { echo "Error: cannot enter $derpfestdir"; exit 1; }

    # 1. Build target-files-package (user)
    echo -e "\n${WHITEONMAGENTA} Building target-files-package (user) with $jobs jobs...${NOCOLOR}"
    echo -e "${WHITEONMAGENTA}Building ROM (user variant) with $jobs jobs...${NOCOLOR}              " > /tmp/build_phase
    source build/envsetup.sh
    lunch "lineage_$device-$android_version-user"
    mka target-files-package otatools -j "$jobs"

    # 2. Extract target-files into a temporary directory
    echo -e "\n- Uncompressing target_files..."
    echo -e "${WHITEONMAGENTA}Extracting and preparing images...${NOCOLOR}                          " > /tmp/build_phase
    local target_files_path="$src_dir/obj/PACKAGING/target_files_intermediates/$target_files_zip"
    if [ ! -f "$target_files_path" ]; then
        echo -e "${RED}ERROR: $target_files_path not found. Aborting.${NOCOLOR}"
        exit 1
    fi
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

    # 4. Build vendorbootimage (userdebug)
    echo -e "\n${WHITEONMAGENTA} Building vendorbootimage (userdebug) with $jobs jobs...${NOCOLOR}"
    echo -e "${WHITEONMAGENTA}Building recovery (userdebug variant) with $jobs jobs...${NOCOLOR}   " > /tmp/build_phase
    lunch "lineage_$device-$android_version-userdebug"
    mka vendorbootimage -j "$jobs"

    # 5. Replace vendor_boot.img in the working directory
    echo -n "- Replacing vendor_boot with userdebug version..."
    echo -e "${WHITEONMAGENTA}Replacing vendor_boot...${NOCOLOR}" > /tmp/build_phase
    local vendor_boot_src="$src_dir/vendor_boot.img"
    if [ ! -f "$vendor_boot_src" ]; then
        echo -e "${RED}ERROR: $vendor_boot_src not found. Aborting.${NOCOLOR}"
        exit 1
    fi
    cp "$vendor_boot_src" "$work_dir/IMAGES/vendor_boot.img"
    if [ -f "$work_dir/IMAGES/vendor_boot.img" ]; then
        echo -e "${GREEN}OK${NOCOLOR}"
    else
        echo -e "${RED}ERROR${NOCOLOR}"
        exit 1
    fi

    # 6. Repack target-files
    echo -n "- Compressing files..."
    echo -e "${WHITEONMAGENTA}Repacking target files...${NOCOLOR}                                  " > /tmp/build_phase
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

    # 7. Build OTA package (return to ROM root)
    echo -e "\n${WHITEONMAGENTA} Building OTA package...${NOCOLOR}"
    echo -e "${WHITEONMAGENTA}Generating OTA package...${NOCOLOR}                                  " > /tmp/build_phase

    cd "$derpfestdir"   # Important: go back to the source root

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

    # 8. Cleanup
    rm -rf "$work_dir"

    # 9. SHA256 checksum
    cd $out_dir
    sha256sum "$ota_file" >> "$ota_file.sha256sum"
    cd $derpfestdir

    # Signal completion
    touch /tmp/end_task
    echo -e "\n${GREEN}Process completed successfully!${NOCOLOR}"
}

# ----------------------------------------------------------------------
# Tmux configuration: a single session for the whole process
# ----------------------------------------------------------------------
# Clean up any old temporary files
rm -f /tmp/build_phase /tmp/end_task

# Export the functions so they are available to subshells
export -f build_all
export -f spinner_animation

tmux new-session -d -s derp_session

# Split panes
tmux split-window -v
tmux split-window -h -t 0
tmux resize-pane -t 2 -U 40
tmux split-window -v -t 2
tmux resize-pane -t 3 -D 30
tmux select-pane -t 2

# Pane 0: banner info (external script)
tmux send-keys -t 0 "bash $banner_script wait $1 $android_version $los_branch; echo 'Process started at `date`'" C-m

# Pane 1: status animation (runs the spinner that reads /tmp/build_phase)
tmux send-keys -t 1 "clear; echo; echo -e ' ${BLUE}Build status:${NOCOLOR}'; bash -c '$(declare -f spinner_animation); spinner_animation'" C-m

# Pane 2: main build process (using exported function)
tmux send-keys -t 2 "clear; echo; echo -e '${WHITEONMAGENTA} Starting build...${NOCOLOR}'; bash -c 'build_all \"$1\" \"$3\"'" C-m

# Pane 3: monitor (external script)
tmux send-keys -t 3 "bash $monitor_script" C-m

# Attach to the tmux session
tmux attach-session -t derp_session
