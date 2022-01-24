#!/bin/bash
# PATHS
export OPENOCD="/opt/openocd-git/bin/openocd"
export GCC_PATH="$PWD/gcc-arm-none-eabi-10.3-2021.10/bin"
export PATH=$GCC_PATH:$PATH
export PATH=$OPENOCD:$PATH

# VARIABLES
#For best compatibility, please use Ubuntu 20.04 (0.10.0) or greater!
adapters=("J-Link" "Raspberry Pi" "ST-LINK" "Quit")
packages=("binutils-arm-none-eabi" "python3" "libhidapi-hidraw0" "libftdi1" "libftdi1-2" "git" "make" "python3-pip")
openocd=(openocd-git_*_amd64.deb)
options=("Backup & Restore Tools" "Retro-Go" "Custom Firmware" "Exit")
chips=("4Mb" "64Mb" "Quit")
gwVersion=("Mario" "Zelda" "Quit")
cfwDir="$PWD/game-and-watch-patch"
backupDir="$PWD/game-and-watch-backup/backups"
backupErr="Can't find any backup files. In order to proceed you need to extract them from your gnw system, using 'Backup & Restore Tools'"

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

retroGo() {
  [ "$DEVICE" == "mario" ] && make -j"$(nproc)" INTFLASH_BANK=2 flash

  if [ "$DEVICE" == "zelda" ]; then
    [ "$CHIP" == "4Mb" ] && make -j"$(nproc)" INTFLASH_BANK=2 EXTFLASH_SIZE=1802240 EXTFLASH_OFFSET=851968 GNW_TARGET=zelda EXTENDED=1 flash
    [ "$CHIP" == "64Mb" ] && make -j"$(nproc)" EXTFLASH_SIZE_MB=60 EXTFLASH_OFFSET=4194304 INTFLASH_BANK=2 flash
  fi
}

toolsStep() {
  clear
  PS3='Please select what do you want to do: '
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

      cd game-and-watch-retro-go || exit
      romChecker
      make clean
      OPENOCD="/opt/openocd-git/bin/openocd"
      GCC_PATH="../gcc-arm-none-eabi-10.3-2021.10/bin"
      retroGo
      cd ..
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
        [ "$CHIP" == "4Mb" ] && make PATCH_PARAMS="--device=zelda --extended --no-la --no-sleep-images --extended" ADAPTER="$ADAPTER" flash
        [ "$CHIP" == "64Mb" ] && make PATCH_PARAMS="--device=zelda" ADAPTER="$ADAPTER" LARGE_FLASH=1 flash_patched
      fi

      cd ..

      cd game-and-watch-retro-go || exit
      romChecker
      make clean
      OPENOCD="/opt/openocd-git/bin/openocd"
      GCC_PATH="../gcc-arm-none-eabi-10.3-2021.10/bin"
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

romChecker() {
  roms="col gb gg gw nes pce sg sms"
  for rom in $roms; do
    files=$(find "roms/$rom" -maxdepth 1 -type f -name "*.$rom" 2>/dev/null | wc -l)
    has_games="false"
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
    echo "COL roms in 'game-and-watch-retro-go/roms/col/';"
    echo "GB roms in 'game-and-watch-retro-go/roms/gb/';"
    echo "GG roms in 'game-and-watch-retro-go/roms/gg/';"
    echo "GW roms in 'game-and-watch-retro-go/roms/gw/';"
    echo "NES roms in 'game-and-watch-retro-go/roms/nes/';"
    echo "PCE roms in 'game-and-watch-retro-go/roms/pce/';"
    echo "SG roms in 'game-and-watch-retro-go/roms/sg/';"
    echo "SMS roms in 'game-and-watch-retro-go/roms/sms/';"
    echo ""
    exit
  fi
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

chipSize() {
  echo ""
  echo "Select the size of your flash chip.
4 is the default:"
  echo ""

  chp=$(optionsDefaultValue "${chips[@]}")

  case $chp in
  "" | "4Mb")
    CHIP="4Mb"
    ;;
  "64Mb")
    CHIP="64Mb"
    ;;
  "Quit")
    exit
    ;;
  esac
  echo ""
  echo "You selected a $CHIP Flash Chip"
  selectDebugger
}

selectDebugger() {
  echo ""
  echo "You must configure this for the debug adapter you're using!
stlink is the default:"
  echo ""
  adp=$(optionsDefaultValue "${adapters[@]}")

  case $adp in
  "J-Link")
    ADAPTER="jlink"
    ;;
  "Raspberry Pi")
    ADAPTER="rpi"
    ;;
  "" | "ST-LINK")
    ADAPTER="stlink"
    ;;
  "Quit")
    exit
    ;;
  esac
  echo ""
  echo "You choose $ADAPTER as your ARM debug probe"
  toolsStep
}

selectGWType() {
  echo ""
  echo "Please select your Game & Watch type.
Mario is the default:"
  echo ""

  gw=$(optionsDefaultValue "${gwVersion[@]}")

  case $gw in
  "" | "Mario")
    DEVICE="mario"
    ;;
  "Zelda")
    DEVICE="zelda"
    chipSize
    ;;
  "Quit")
    exit
    ;;
  *) echo "invalid option $REPLY" ;;
  esac
  echo ""
  echo "You choose $DEVICE as your Game & Watch"
  selectDebugger
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

  if [ ! -d "game-and-watch-backup" ]; then
    echo "Cloning and building the Backup & Restore Tools:"
    git clone https://github.com/ghidraninja/game-and-watch-backup
    cd game-and-watch-backup || exit
    cd ..
  fi

  if [ ! -d "game-and-watch-patch" ]; then
    echo "Cloning Custom Firmware:"
    git clone https://github.com/BrianPugh/game-and-watch-patch
    cd game-and-watch-patch || exit
    pip3 install -r requirements.txt
    make download_sdk
    cd ..
  fi

  [ ! -f "$GCC_PATH/arm-none-eabi-gcc" ] && echo "Extracting gcc-arm-none-eabi"
  [ ! -f "$PWD/gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2" ] && wget https://developer.arm.com/-/media/Files/downloads/gnu-rm/10.3-2021.10/gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2
  [ ! -f "$GCC_PATH/arm-none-eabi-gcc" ] && tar -xf gcc-arm-none-eabi-10.3-2021.10-x86_64-linux.tar.bz2

  if [ ! -d "game-and-watch-retro-go" ]; then
    echo "Cloning and building Retro-Go"
    git clone --recurse-submodules https://github.com/kbeckmann/game-and-watch-retro-go
  fi
}

getRequirements

selectGWType
