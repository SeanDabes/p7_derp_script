#!/bin/sh

# Script to upload files to server
# Uses rclone to manage server-client connections
# By SeanDabes

# -----Server config, change and configure to your flavour
server="onedrive"
server_root="DerpFest"

check_server(){
    if [ ! -z $(rclone lsf --dirs-only $server:$server_root | grep $start_date) ]; then
        return 0
    else
        return 1
    fi
}

bash $banner_script nowait $device $android_version $los_branch
echo -e "${BLUE}Files upload${NOCOLOR}"

echo -n "- Checking server..."
if check_server; then
    echo -e "${RED}Folder already exists in server, aborting.${NOCOLOR}"
    exit
else
    echo -e "${GREEN}OK${NOCOLOR}"
    if [ -d $out_rom_dir ]; then
        echo "- Uploading files..."
        rclone -P copy $out_rom_dir  $server:"$server_root"
    else
        echo -e "${RED}Folder $out_rom_dir doesn't exist${NOCOLOR}"
        exit
    fi
fi
