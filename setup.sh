#!/bin/bash
# shellcheck disable=SC2068
#  Copyright (c) 2022 DefKorns (https://defkorns.github.io/LICENSE)
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# PATHS
export OPENOCD="/opt/openocd-git/bin/openocd"
export GCC_PATH="$PWD/gcc-arm-none-eabi-10.3-2021.10/bin"
export PATH=$GCC_PATH:$PATH
export PATH=$OPENOCD:$PATH

# VARIABLES
#For best compatibility, please use Ubuntu 20.04 (0.10.0) or greater!
adpArgs=("jlink" "rpi" "stlink")
chpArg=("4" "8" "16" "32" "64" "128" "256" "512" "4Mb" "8Mb" "16Mb" "32Mb" "64Mb" "128Mb" "256Mb" "512Mb")
devArg=("mario" "zelda")
adapters=("J-Link" "Raspberry Pi" "ST-LINK" "Quit")
packages=("binutils-arm-none-eabi" "python3" "libhidapi-hidraw0" "libftdi1" "libftdi1-2" "git" "make" "python3-pip")
openocd=(openocd-git_*_amd64.deb)
options=("Backup & Restore Tools" "Retro-Go" "Custom Firmware" "Exit")
chips=("4Mb" "8Mb" "16Mb" "32Mb" "64Mb" "128Mb" "256Mb" "512Mb" "Quit")
gwVersion=("Mario" "Zelda" "Quit")
retroGoVersion=("Original" "NewUI" "Quit")
gwB="game-and-watch-backup"
gwP="game-and-watch-patch"
gwR="game-and-watch-retro-go"
cfwDir="$PWD/$gwP"
BACKUP_DIR="$gwB/backups"
NEW_BACKUP_DIR="GW-flash-backup"
backupDir="$PWD/$BACKUP_DIR"
backupErr="Can't find any backup files. In order to proceed you need to extract them from your gnw system, using 'Backup & Restore Tools'"
gccArmNoneEabi="https://developer.arm.com/-/media/Files/downloads/gnu-rm/10.3-2021.10/gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2"
# ! wget -q --spider "$gccArmNoneEabi" >/dev/null 2>&1 && gccArmNoneEabi="https://mega.nz/file/lbpgHB7S#NMRZgnNieoNG15idyv-187Cfn284yBV6fgcx8BTSAtQ"

installDependencies() {
  ## Prompt the user
  read -rp "Do you want to install missing libraries? [Y/n]: " answer
  ## Set the default value if no answer was given
  answer=${answer:Y}
  ## If the answer matches y or Y, install
  echo "Installing required tools..."
  [[ $answer =~ [Yy] ]] && sudo apt-get install "${packages[@]}"
}

errorMsg() {
  echo "$backupErr"
  exit
}

helpText() {
  # Display Help
  echo "Add description of the script functions here."
  echo
  echo "Syntax: $0 [-h|b|c|clean|backup]"
  echo "options:"
  echo "        -b     Backups internal flash files to a new folder outside the repository"
  echo "  --backup     Backups internal flash files to a new folder outside the repository"
  echo "        -c     Removes all repositories."
  echo "   --clean     Removes all repositories."
  echo "        -h     Print this Help."
  echo "    --help     Print this Help."
  # echo "        -V     Print software version and exit."
  echo
  echo "Usage: $0 <Adapter: jlink or stlink or rpi> <mario or zelda> <ChipSize: 4Mb or 8Mb or 16Mb or 32Mb or 64Mb or 128Mb or 256Mb or 512Mb>"
  echo "Usage: $0 --backup <To backups internal flash files to a new folder outside the repository>"
  echo "Usage: $0 --clean <To remove all repositories>"
  echo "Usage: $0 --clean <To remove all repositories>"
}

remove() {
  for f in $@; do
    [ -f "$f" ] || [ -d "$f" ] && rm -rf "$f"
  done
}

backupIntFlashFolder() {
  if [ -d "$BACKUP_DIR" ]; then
    if [ "$(ls -A $BACKUP_DIR)" ]; then
      [ ! -d "$NEW_BACKUP_DIR" ] && mkdir -p "$NEW_BACKUP_DIR"
      cp -r "$BACKUP_DIR" "$NEW_BACKUP_DIR/$(date +%Y%m%d%H%M%S)"
    fi
  fi
}

cleanDir() {
  backupIntFlashFolder
  remove "game-and-watch-backup" "game-and-watch-retro-go" "gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2" openocd-git_*_amd64.deb "openocd-git.deb.zip"

}

optionsDefaultValue() {
  local item i=0 numItems=$#

  # Print numbered menu items, based on the arguments passed.
  for item; do # Short for: for item in "$@"; do
    printf '%s\n' "$((++i))) $item"
  done >&2 # Print to stderr, as `select` does.

  # Prompt the user for the index of the desired item.
  while :; do
    printf %s "${PS3-#? }" >&2 # Print the prompt string to stderr, as `select` does.
    read -r index
    # Make sure that the input is either empty or that a valid index was entered.
    [[ -z $index ]] && break # empty input
    ((index >= 1 && index <= numItems)) 2>/dev/null || {
      echo "Invalid selection. Please try again." >&2
      continue
    }
    break
  done

  # Output the selected item, if any.
  [[ -n $index ]] && printf %s "${@:index:1}"

}

retroGo() {
  cd game-and-watch-retro-go || exit
  romChecker
  make clean

  OPENOCD="/opt/openocd-git/bin/openocd"
  GCC_PATH="../gcc-arm-none-eabi-10.3-2021.10/bin"

  if [ "$DEVICE" == "mario" ]; then
    [ "$CHIP" == "1" ] && make -j"$(nproc)" INTFLASH_BANK=2 flash
    [ "$CHIP" -ge "8" ] && make -j"$(nproc)" EXTFLASH_SIZE_MB="$CHIP" INTFLASH_BANK=2 flash
  fi

  if [ "$DEVICE" == "zelda" ]; then
    [ "$CHIP" == "4" ] && make -j"$(nproc)" INTFLASH_BANK=2 EXTFLASH_SIZE=1802240 EXTFLASH_OFFSET=851968 GNW_TARGET=zelda EXTENDED=1 flash
    [ "$CHIP" -ge "8" ] && make -j"$(nproc)" EXTFLASH_SIZE_MB="$EXTFLASH_SIZE" EXTFLASH_OFFSET=4194304 INTFLASH_BANK=2 flash
  fi
  cd ..
}

romChecker() {
  roms="col gb gg gw nes pce sg sms"
  has_games="false"

  for rom in $roms; do
    files=$(find "roms/$rom" -maxdepth 1 -type f -name "*.$rom" 2>/dev/null | wc -l)

    if [ "$files" != "0" ]; then
      has_games="true"
      break
    fi

  done

  if [ "${has_games}" = "false" ]; then
    echo "Didn't found any rom files!!"
    echo ""
    echo "Please place extracted roms on the correct directory and try again."
    echo ""
    for r in $roms; do
      rt="${r^^}"
      echo "$rt roms in '$gwR/roms/$r/';"
    done
    echo ""
    exit
  fi
}

installRetroGo() {
  if [ ! -d "game-and-watch-retro-go" ]; then
    echo "Cloning and building Retro-Go"
    git clone --recurse-submodules "${1}"
    cd game-and-watch-retro-go || exit
    pip3 install -r requirements.txt
    cd ..
  fi
}

getRequirements() {
  ## Run the installDependencies function if any of the libraries are missing.
  dpkg -s "${packages[@]}" >/dev/null 2>&1 || installDependencies

  [ ! -f "$PWD/openocd-git.deb.zip" ] && echo "Downloading OpenOCD..."
  [ ! -f "$PWD/openocd-git.deb.zip" ] && wget https://nightly.link/kbeckmann/ubuntu-openocd-git-builder/workflows/docker/master/openocd-git.deb.zip

  if [ ! -e "${openocd[0]}" ]; then
    echo "Unpacking download..."
    unzip -u openocd-git.deb.zip
  fi

  dpkg -s openocd-git >/dev/null 2>&1 || sudo dpkg -i openocd-git_*_amd64.deb
  dpkg -s openocd-git >/dev/null 2>&1 || echo "Installing OpenOCD..."
  dpkg -s openocd-git >/dev/null 2>&1 || sudo apt-get -y -f install

  if [ ! -d "$gwB" ]; then
    echo "Cloning and building the Backup & Restore Tools:"
    git clone https://github.com/ghidraninja/game-and-watch-backup
  fi

  if [ ! -d "$gwP" ]; then
    echo "Cloning Custom Firmware:"
    git clone https://github.com/BrianPugh/game-and-watch-patch
    cd game-and-watch-patch || exit
    pip3 install -r requirements.txt
    make download_sdk
    cd ..
  fi

  [ ! -f "$GCC_PATH/arm-none-eabi-gcc" ] && echo "Extracting gcc-arm-none-eabi"
  [ ! -f "$PWD/gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2" ] && wget "$gccArmNoneEabi"
  [ ! -f "$GCC_PATH/arm-none-eabi-gcc" ] && tar -xf gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2

  retroGoSelectionMenu

}

selectGWType() {
  selection="${1,,}"

  case "$selection" in
  "" | "mario")
    DEVICE="mario"
    GNW="Mario"
    CHIP="1"
    ;;
  "zelda")
    DEVICE="zelda"
    GNW="Zelda"
    [ -z "${2}" ] && chipSelectionMenu
    ;;
  "quit")
    exit
    ;;
  *) echo "invalid option $REPLY" ;;
  esac
}

selectRGType() {
  retroGoSelection="${1,,}"

  case "$retroGoSelection" in
  "" | "original")
    RETROGO="https://github.com/kbeckmann/game-and-watch-retro-go"
    ;;
  "newui")
    RETROGO="https://github.com/olderzeus/game-and-watch-retro-go"
    ;;
  "quit")
    exit
    ;;
  *) echo "invalid option $REPLY" ;;
  esac
  installRetroGo "$RETROGO"
}

selectDebugger() {
  adpSelection="${1,,}"

  case $adpSelection in
  "j-link" | "jlink")
    ADAPTER="jlink"
    DEBUGGER="J-Link"
    ;;
  "raspberry Pi" | "rpi")
    ADAPTER="rpi"
    DEBUGGER="Raspberry Pi"
    ;;
  "" | "st-link" | "stlink")
    ADAPTER="stlink"
    DEBUGGER="ST-LINK"
    ;;
  "quit")
    exit
    ;;
  esac
}

chipSize() {
  chpSelection="${1,,}"
  case "$chpSelection" in
  "" | "4mb" | "4")
    CHIP="4"
    ;;
  "8mb" | "8")
    CHIP="8"
    ;;
  "16mb" | "16")
    CHIP="16"
    ;;
  "32mb" | "32")
    CHIP="32"
    ;;
  "64mb" | "64")
    CHIP="64"
    ;;
  "128mb" | "128")
    CHIP="128"
    ;;
  "256mb" | "256")
    CHIP="256"
    ;;
  "512mb" | "512")
    CHIP="512"
    ;;
  "quit")
    exit
    ;;
  esac
  [ "$CHIP" -gt "4" ] && EXTFLASH_SIZE=$((CHIP - 4))
}

toolsSelectionMenu() {
  clear
  PS3='Please select what do you want to do: '

  echo ""
  echo "#################################################################################################"
  echo "     You're using a ${DEBUGGER} adapter on a Game and Watch ${GNW} version with ${CHIP}Mb chip "
  echo "#################################################################################################"
  echo ""

  select opt in "${options[@]}"; do
    case $opt in
    "Backup & Restore Tools")
      echo "Before continue please check the correct pinout https://imgur.com/6IxzPi9. Press return when ready!"
      read -rn 1
      echo "Running Backup & Restore Tools Sanity Checks:"
      echo ""
      cd game-and-watch-backup || exit
      OPENOCD="/opt/openocd-git/bin/openocd"
      ./1_sanity_check.sh "$ADAPTER" "$DEVICE"
      echo ""
      OPENOCD="/opt/openocd-git/bin/openocd"
      ./2_backup_flash.sh "$ADAPTER" "$DEVICE"
      echo ""
      OPENOCD="/opt/openocd-git/bin/openocd"
      ./3_backup_internal_flash.sh "$ADAPTER" "$DEVICE"
      echo ""
      OPENOCD="/opt/openocd-git/bin/openocd"
      ./4_unlock_device.sh "$ADAPTER" "$DEVICE"
      echo ""
      OPENOCD="/opt/openocd-git/bin/openocd"
      ./5_restore.sh "$ADAPTER" "$DEVICE"
      cd ..
      ;;
    "Retro-Go")
      echo "Running Retro-Go:"
      echo ""
      retroGo
      exit
      ;;
    "Custom Firmware")
      echo "Custom firmware for the newer Nintendo Game and Watch consoles."
      echo ""

      [ ! -f "$backupDir/internal_flash_backup_${DEVICE}.bin" ] || [ ! -f "$backupDir/flash_backup_${DEVICE}.bin" ] && errorMsg

      [ ! -f "$cfwDir/flash_backup_${DEVICE}.bin" ] && cp "$backupDir/flash_backup_${DEVICE}.bin" "$cfwDir/flash_backup_${DEVICE}.bin"
      [ ! -f "$cfwDir/internal_flash_backup_${DEVICE}.bin" ] && cp "$backupDir/internal_flash_backup_${DEVICE}.bin" "$cfwDir/internal_flash_backup_${DEVICE}.bin"

      cd game-and-watch-patch || exit

      make clean
      OPENOCD="/opt/openocd-git/bin/openocd"
      [ "$DEVICE" == "mario" ] && make PATCH_PARAMS="--device=mario --internal-only" ADAPTER="$ADAPTER" flash_patched

      if [ "$DEVICE" == "zelda" ]; then
        [ "$CHIP" == "4" ] && make PATCH_PARAMS="--device=zelda --extended --no-la --no-sleep-images --extended" ADAPTER="$ADAPTER" flash
        [ "$CHIP" -ge "64" ] && make PATCH_PARAMS="--device=zelda" ADAPTER="$ADAPTER" LARGE_FLASH=1 flash_patched
      fi

      cd ..
      retroGo
      exit
      ;;
    "Exit")
      exit
      ;;
    *) echo "invalid option $REPLY" ;;
    esac
  done
}

chipSelectionMenu() {
  echo ""
  echo "Select the size of your flash chip.
4 is the default:"
  echo ""
  chp=$(optionsDefaultValue "${chips[@]}")

  chipSize "$chp"

  echo ""
  echo "You selected a $((CHIP + 4))Mb Flash Chip"
}

adapterSelectionMenu() {
  echo ""
  echo "You must configure this for the debug adapter you're using!
stlink is the default:"
  echo ""
  adp=$(optionsDefaultValue "${adapters[@]}")

  selectDebugger "$adp"

  echo ""
  echo "You choose $ADAPTER as your ARM debug probe"
}

deviceSelectionMenu() {
  echo ""
  echo "Please select your Game & Watch type.
Mario is the default:"
  echo ""

  gw=$(optionsDefaultValue "${gwVersion[@]}")

  selectGWType "$gw"
  echo ""
  echo "You choose $DEVICE as your Game & Watch"
}

retroGoSelectionMenu() {
  echo ""
  echo "Please select your Game & Watch type.
Original is the default:"
  echo ""

  rg=$(optionsDefaultValue "${retroGoVersion[@]}")

  selectRGType "$rg"
  echo ""
  echo "You choose $DEVICE as your Game & Watch"
}

case "$1" in
"-h" | "--help") # display Help
  helpText
  exit
  ;;
"-r" | "--r") # Check Rom dir
  romChecker
  exit 1
  ;;
"-b" | "--backup") # Backup flash dumps
  backupIntFlashFolder
  exit 1
  ;;
"-c" | "--clean") # Clean repository
  cleanDir
  exit 1
  ;;
*) # Invalid option
  if [[ ! ${adpArgs[*]} =~ $1 ]] || [[ ! ${devArg[*]} =~ $2 ]] || [[ ! ${chpArg[*]} =~ $3 ]]; then
    helpText
    exit 1
  fi
  ;;
esac


if [ -n "${1}" ]; then
  selectDebugger "${1}"
fi

if [ -n "${2}" ]; then
  selectGWType "${2}" "${3}"
fi

if [ -n "${3}" ]; then
  chipSize "${3}"
fi
echo ""

[ ! -d "$gwB" ] || [ ! -d "$gwP" ] || [ ! -d "$gwR" ] && getRequirements

[ -z "${DEVICE}" ] && deviceSelectionMenu
[ -z "${ADAPTER}" ] && adapterSelectionMenu
[ "$DEVICE" == "zelda" ] && [ -z "${CHIP}" ] && chipSelectionMenu

[ -n "${DEVICE}" ] && [ -n "${ADAPTER}" ] && [ -n "${CHIP}" ] && toolsSelectionMenu
