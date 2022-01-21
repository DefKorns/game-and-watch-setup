#!/bin/bash
export OPENOCD="/opt/openocd-git/bin/openocd"
export GCC_PATH=/opt/gcc-arm-none-eabi/bin
export PATH=$GCC_PATH:$PATH
libraryChecker() {
    ## Prompt the user
    read -rp "Do you want to install missing libraries? [Y/n]: " answer
    ## Set the default value if no answer was given
    answer=${answer:Y}
    ## If the answer matches y or Y, install
    echo "Installing required tools..."
    [[ $answer =~ [Yy] ]] && sudo apt-get install "${packages[@]}"
}

initStep() {
    clear
    local PS3='Please select what do you want to do: '
    local options=("Backup & Restore Tools" "Retro-Go" "Exit")
    local opt
    select opt in "${options[@]}"; do
        case $opt in
        "Backup & Restore Tools")
            echo "Before continue please check the correct pinout https://imgur.com/6IxzPi9. Press return when ready!"
            read -rn 1
            echo "Running Backup & Restore Tools Sanity Checks:"
            echo ""
            cd game-and-watch-backup || exit
            OPENOCD="/opt/openocd-git/bin/openocd"
            ./1_sanity_check.sh
            echo ""
            OPENOCD="/opt/openocd-git/bin/openocd"
            ./2_backup_flash.sh "$ADAPTER" "$TARGET"
            echo ""
            OPENOCD="/opt/openocd-git/bin/openocd"
            ./3_backup_internal_flash.sh "$ADAPTER" "$TARGET"
            echo ""
            OPENOCD="/opt/openocd-git/bin/openocd"
            ./4_unlock_device.sh "$ADAPTER" "$TARGET"
            echo ""
            OPENOCD="/opt/openocd-git/bin/openocd"
            ./5_restore.sh "$ADAPTER" "$TARGET"
            cd ..
            ;;
        "Retro-Go")
            echo "Running Retro-Go:"
            echo ""
            cd game-and-watch-retro-go || exit
            roms="gb nes sms gg pce"
            for rom in $roms; do
                files=$(find "roms/$rom" -maxdepth 1 -type f -name "*.$rom" 2>/dev/null | wc -l)
                has_games="false"
                if [ "$files" != "0" ]; then
                    has_games="true"
                    break
                fi
            done
            if [ "${has_games}" = "false" ]; then
                echo "Please place extracted roms on the correct directory."
                echo ""
                echo "GB roms in 'game-and-watch-retro-go/roms/gb/';"
                echo "NES roms in 'game-and-watch-retro-go/roms/nes/';"
                echo "SMS roms in 'game-and-watch-retro-go/roms/sms/';"
                echo "GG roms in 'game-and-watch-retro-go/roms/gg/';"
                echo "PCE roms in 'game-and-watch-retro-go/roms/pce/';"
                exit
            fi

            flashSize
            make -j"$(nproc)" "$LF" flash
            cd ..
            ;;
        "Exit")
            exit
            ;;
        *) echo "invalid option $REPLY" ;;
        esac
    done
}

flashSize() {
    local PS3='Please select where to flash your games: '
    local options=("16MB External Flash" "Internal Flash" "Exit")
    local opt
    select opt in "${options[@]}"; do
        case $opt in
        "16MB External Flash")
            echo "Flashing To 16MB External Flash:"
            echo ""
            LF="LARGE_FLASH=1"
            break
            ;;
        "Internal Flash")
            echo "Flashing To Internal Flash:"
            echo ""
            LF=""
            break
            ;;
        "Exit")
            exit
            ;;
        *) echo "invalid option $REPLY" ;;
        esac
    done
}

adapterSelector() {
    PS3='Please select your ARM debug probe: '

    adapters=("J-Link" "RaspberryPi" "ST-LINK" "Quit")
    select adp in "${adapters[@]}"; do
        case $adp in
        "J-Link")
            ADAPTER="jlink"
            ;;
        "RaspberryPi")
            ADAPTER="rpi"
            ;;
        "ST-LINK")
            ADAPTER="stlink"
            ;;
        "Quit")
            exit
            ;;
        *) echo "invalid option $REPLY" ;;
        esac
        echo "You choose $adp as your ARM debug probe"
        initStep
    done

}
#For best compatibility, please use Ubuntu 20.04 (0.10.0) or greater!
# binutils-arm-none-eabi python3 libhidapi-hidraw0 libftdi1 libftdi1-2
packages=("gcc-arm-none-eabi" "binutils-arm-none-eabi" "python3" "libhidapi-hidraw0" "libftdi1" "libftdi1-2" "git" "make")
## Run the run_install function if sany of the libraries are missing
dpkg -s "${packages[@]}" >/dev/null 2>&1 || libraryChecker

# sudo apt-get install gcc-arm-none-eabi binutils-arm-none-eabi python3 libftdi1 git make

echo "Downloading OpenOCD..."
[ ! -f "$PWD/openocd-git.deb.zip" ] && wget https://nightly.link/kbeckmann/ubuntu-openocd-git-builder/workflows/docker/master/openocd-git.deb.zip

echo "Unpacking download..."
unzip openocd-git.deb.zip
sudo dpkg -i openocd-git_*_amd64.deb

echo "Installing OpenOCD..."
sudo apt-get -y -f install

# You must configure this for the debug adapter you're using!
# stlink is the default, but you may set it to something else, such as jlink, or rpi (Raspberry Pi):
# export ADAPTER=jlink
# export ADAPTER=rpi
# export ADAPTER=stlink

echo "Cloning and building the Backup & Restore Tools:"
git clone https://github.com/ghidraninja/game-and-watch-backup/
cd game-and-watch-backup || exit
# The -j option specifies the number of jobs (commands) to run simultaneously. Example: make -j8
# make -j"$(nproc)"
cd ..

echo "Cloning and building Flashloader:"
git clone https://github.com/ghidraninja/game-and-watch-flashloader

cd game-and-watch-flashloader || exit

# make download_sdk -j"$(nproc)"
# See notes above for -j option.
[ -f "/opt/gcc-arm-none-eabi/bin/arm-none-eabi-gcc" ] && GCC_PATH="GCC_PATH=/opt/gcc-arm-none-eabi/bin" || [ -f "/usr/bin/arm-none-eabi-gcc" ] && GCC_PATH="GCC_PATH=/usr/bin"
make -j"$(nproc)" "$GCC_PATH"

cd ..

echo "Cloning and building Retro-Go"

git clone --recurse-submodules https://github.com/kbeckmann/game-and-watch-retro-go
cd game-and-watch-retro-go || exit

# Place GB roms in `./roms/gb/`, NES roms in `./roms/nes/`, SMS roms in `./roms/sms/`, GG roms in `./roms/gg/`, PCE roms in `./roms/pce/`:
# cp /path/to/rom.gb ./roms/gb/
# cp /path/to/rom.nes ./roms/nes/
# cp /path/to/rom.sms ./roms/sms/
# cp /path/to/rom.nes ./roms/gg/
# cp /path/to/pce.nes ./roms/pce/

# On a Mac running make < v4 you have to manually download the HAL package by running:
# make download_sdk

#Uncomment the line below if you have HAL Driver Errors when building.
#git clone --depth 1 https://github.com/STMicroelectronics/STM32CubeH7 && ln -s STM32CubeH7/Drivers Drivers

# Build and program external and internal flash.
# Note: If you are using the 16MB external flash, build using:
#           make -j8 LARGE_FLASH=1 flash
#       A custom flash size may be specified with the EXTFLASH_SIZE variable.

#make -j2 flash
cd ..

PS3='Please select your Game & Watch type: '

gwVersion=("Mario" "Zelda" "Quit")
select gw in "${gwVersion[@]}"; do
    case $gw in
    "Mario")
        TARGET="mario"
        ;;
    "Zelda")
        TARGET="zelda"
        ;;
    "Quit")
        exit
        ;;
    *) echo "invalid option $REPLY" ;;
    esac
    echo "You choose $gw as your Game & Watch"
    adapterSelector
done
