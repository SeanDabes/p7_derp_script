#!/bin/bash

# Replace default kernel by WildKernel

# Module status, 1=active 0=inactive
modstatus=1
modname="WildKernel"
modtype=prebuild
workdir="$derpfestdir/device/google/gs201/wildkernel"

case $1 in
    "enum")
        echo $modname
        exit
    ;;
    "clean")
        echo -n "- $modname..."
        if [ -d "$workdir" ]; then
            rm -rf $workdir
        fi
        echo -e "${GREEN}OK${NOCOLOR}"
        exit
    ;;
esac

echo -e "${BLUE}$modname${NOCOLOR}"


patch_vintf() {
    local target_file="build/make/tools/releasetools/check_target_files_vintf.py"
    local full_path="$derpfestdir/$target_file"

    if [ ! -f "$full_path" ]; then
        echo -e "${RED}ERROR: $target_file not found at $full_path${NOCOLOR}"
        return 1
    fi

    # Verify if it's already patched (looking for the mark)
    if grep -q "Patched by WildKernel" "$full_path"; then
        echo -e "${GREEN}VINTF check already patched.${NOCOLOR}"
        return 0
    fi

    echo -e "${WHITEONMAGENTA}Patching $target_file to skip VINTF check...${NOCOLOR}"

    # Create backup
    cp "$full_path" "$full_path.bak"

    # Use awk to replace function
    awk '
    BEGIN { inside=0 }
    /^def CheckVintfIfTrebleEnabled/ {
        print "def CheckVintfIfTrebleEnabled(target_files, target_info):"
        print "    return True  # Patched by WildKernel"
        inside=1
        next
    }
    inside && /^def / {
        # Cuando termina la función, reiniciamos
        inside=0
        print $0
        next
    }
    inside {
        # Saltar líneas dentro de la función
        next
    }
    !inside {
        print
    }
    ' "$full_path.bak" > "$full_path"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Patch applied successfully.${NOCOLOR}"
    else
        echo -e "${RED}ERROR: Failed to apply patch.${NOCOLOR}"
        # Restore backup
        mv "$full_path.bak" "$full_path"
        return 1
    fi
}

replace_boot_image(){
    if [ ! -d $workdir ]; then
        echo -n "- Creating folder..."
        mkdir -p $workdir
        if [ -d $workdir ]; then
            echo -e "${GREEN}OK${NOCOLOR}"
        else
            echo -e "${RED}Could not create working folder${NOCOLOR}"
        fi
    fi

    cd $workdir
    rm *

    echo -n "- Downloading file..."
    curl -s https://api.github.com/repos/WildKernels/GKI_KernelSU_SUSFS/releases/latest | grep "browser_download_url" | grep "6.1.145-android14-2025-09" | head -n 1 | cut -d : -f 2,3 | tr -d \" | wget -qi -
    if [ -z $(ls *.zip) ]; then
        echo -e "${RED}File not downloaded${NOCOLOR}"
    else
        echo -e "${GREEN}OK${NOCOLOR}"
    fi

    echo -n "- Extracting image..."
    file=$(ls *.zip)
    unzip -q $file Image
    if [ -f "Image" ]; then
        echo -e "${GREEN}OK${NOCOLOR}"
    else
        echo -e "${RED}KO${NOCOLOR}"
    fi

    echo -n "- Compressing Image in lz4 format..."
    lz4 -q Image Image.lz4
    if [ -f "Image.lz4" ]; then
        echo -e "${GREEN}OK${NOCOLOR}"
    else
        echo -e "${RED}KO${NOCOLOR}"
    fi

    echo -n "- Cleaning up..."
    rm *.zip Image
    echo -e "${GREEN}OK${NOCOLOR}"
}

replace_boot_image
patch_vintf
