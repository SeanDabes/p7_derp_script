#!/bin/bash

info=""
command=""
variant=""
out_rom_dir="$derpfestdir/00_latest_builds/"


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

case "$2" in
    "rom")
        info="clear; echo; echo -e '${WHITEONMAGENTA} Building ROM with $3 simultaneous processes... ${NOCOLOR}'; echo; bash -c '$(declare -f wait_task); wait_task'"
        command="clear; . build/envsetup.sh && lunch lineage_$1-$android_version-user &&  mka derp -j $jobs; touch /tmp/end_task"
    ;;
    "recovery")
        info="clear; echo; echo -e '${WHITEONMAGENTA} Building RECOVERY with $3 simultaneous processes... ${NOCOLOR}'; echo; bash -c '$(declare -f wait_task); wait_task'"
        command="clear; . build/envsetup.sh && lunch lineage_$1-$android_version-userdebug &&  m vendorbootimage -j $jobs; touch /tmp/end_task"
    ;;
esac

builddevice $1

# Move files to more accessible folder
src_dir="out/target/product/$1/"
out_dir="$out_rom_dir$1/"
mkdir -p $out_dir

if [[ $2 = "rom" ]]; then
    files=(DerpFest*.zip DerpFest*.sha256sum boot.img dtbo.img init_boot.img vendor_boot.img vendor_kernel_boot.img)
    for item in "${files[@]}"; do
        if [ -f $src_dir$item ]; then
            mv $src_dir$item $out_dir
        else
            ERROR=true
        fi
    done
fi

if [[ $2 = "recovery" ]]; then
    src_file="vendor_boot.img"
    out_file="vendor_boot_userdebug.img"
    if [ -f $file ]; then
        cp "$src_dir""$src_file" "$src_dir""$out_file"
        mv "$src_dir""$out_file" "$out_dir""$out_file"
    else
        ERROR=true
    fi
fi
sleep 5
echo
