#!/bin/bash

info=""
command=""
variant=""
src_dir="out/target/product/$1/"
out_dir="$out_rom_dir$1"
target_files_zip="lineage_$1-target_files.zip"
work_dir="$out_dir""/work_dir"
ota_file="DerpFest-v$derp_branch-$start_date-$1-Official-Beta.zip"
mkdir -p $out_dir


wait_task(){
    local marquee_anim=(
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
    while [ ! -f /tmp/end_task ]; do
        for i in "${marquee_anim[@]}" ; do
            printf "\r%s %s" "$i"
            sleep 0.1
        done
    done

    echo -e "\n"
}

builddevice() {
    bash $banner_script nowait $1 $android_version $los_branch
    cd $derpfestdir

#     export KERNEL_MANIFEST_BRANCH=$los_branch
#     export KERNEL_MANIFEST_REMOTE=$los_repo

    #TMUX-SESSION-----------------------
    tmux new-session -d -s derp_session
    tmux split-window -v
    tmux split-window -h -t 0
    tmux resize-pane -t 2 -U 40
    tmux split-window -v -t 2
    tmux resize-pane -t 3 -D 30
    tmux select-pane -t 2
    tmux send-keys -t 0 "bash $banner_script wait $1 $android_version $los_branch; echo 'Process started at `date`'" C-m
    tmux send-keys -t 1 "$info" C-m
    tmux send-keys -t 2 "$command" C-m
#     tmux send-keys -t 3 "htop -p --readonly" C-m
    tmux send-keys -t 3 "bash $monitor_script" C-m
    tmux send-keys -t 1 "clear; echo; echo -e ' ${BLUE}Cooling down...${NOCOLOR}'; sleep 5; rm /tmp/end_task; tmux kill-session -t derp_session" C-m

    tmux attach-session -t derp_session

    #TMUX-SESSION-END-------------------

}

# 1. Make target-files package in user variant
info="clear; echo; echo -e '${WHITEONMAGENTA} Building ROM with $3 simultaneous processes... ${NOCOLOR}'; echo; bash -c '$(declare -f wait_task); wait_task'"
command="clear; . build/envsetup.sh && lunch lineage_$1-$android_version-user && m target-files-package -j $3; touch /tmp/end_task"

builddevice $1

# 2. Uncompress target-files in separate directory
echo "- Uncompressing target_files..."
unzip -q "$src_dir""obj/PACKAGING/target_files_intermediates/$target_files_zip" -d $work_dir
sleep 2

# 3. Take images
echo "- Copying images..."
files=(boot.img dtbo.img init_boot.img vendor_kernel_boot.img)
for item in "${files[@]}"; do
    echo -n "$item..."
    if [ -f "$work_dir/IMAGES/$item" ]; then
        cp "$work_dir/IMAGES/$item" $out_dir
        if [ -f "$out_dir""/$item" ]; then
            echo -e "${GREEN}OK${NOCOLOR}"
        else
            echo -e "${RED}ERROR${NOCOLOR}"
        fi
    else
        ERROR=true
    fi
done
sleep 2

# 4.  Make recovery in userdebug variant and place it at the same place
info="clear; echo; echo -e '${WHITEONMAGENTA} Building RECOVERY with $3 simultaneous processes... ${NOCOLOR}'; echo; bash -c '$(declare -f wait_task); wait_task'"
command="clear; . build/envsetup.sh && lunch lineage_$1-$android_version-userdebug &&  m vendorbootimage -j $3; touch /tmp/end_task"

builddevice $1

mv "$src_dir""vendor_boot.img" "$out_dir"

# 5. Replace vendor_boot in user variant by the userdebug variant
cd $out_dir
echo -n "- Replacing vendor_boot by userdebug version..."
cp "vendor_boot.img" "$work_dir/IMAGES/vendor_boot.img"
if [ -f "$work_dir/IMAGES/vendor_boot.img" ]; then
    echo -e "${GREEN}OK${NOCOLOR}"
else
    echo -e "${RED}ERROR${NOCOLOR}"
    ERROR=true
fi

# 6. Make zip again with the new vendor_boot
echo -n "- Compressing files..."
cd "$work_dir"
zip -q -r -y -X -0 "target_files_mod.zip" .
if [ -f "target_files_mod.zip" ]; then
    echo -e "${GREEN}OK${NOCOLOR}"
else
    echo -e "${RED}ERROR${NOCOLOR}"
    ERROR=true
fi

# 7. Make ota package with the modified files
info="clear; echo; echo -e '${WHITEONMAGENTA} Building OTA Package... ${NOCOLOR}'; echo; bash -c '$(declare -f wait_task); wait_task'"
command="clear; . build/envsetup.sh && lunch lineage_$1-$android_version-userdebug && ota_from_target_files $work_dir/target_files_mod.zip $out_dir/$ota_file; touch /tmp/end_task"

builddevice $1

# 8. Clean
rm -rf $work_dir

# 9. Generate sha256sum file
sha256sum $ota_file >> $ota_file.sha256sum

sleep 5
echo
