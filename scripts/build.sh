#!/bin/bash

# Source Configs
source $CONFIG

# A Function to Send Posts to Telegram
telegram_message() {
	curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
	-d chat_id="${TG_CHAT_ID}" \
	-d parse_mode="HTML" \
	-d text="$1"
}

# Change to the Source Directry
cd $SYNC_PATH

# Sync Branch (will be used to fix legacy build system errors)
if [ -z "$SYNC_BRANCH" ]; then
    export SYNC_BRANCH=$(echo ${FOX_BRANCH} | cut -d_ -f2)
fi

# Set-up ccache
if [ -z "$CCACHE_SIZE" ]; then
    ccache -M 10G
else
    ccache -M ${CCACHE_SIZE}
fi

# Empty the VTS Makefile
if [ "$FOX_BRANCH" = "fox_11.0" ]; then
    rm -rf frameworks/base/core/xsd/vts/Android.mk
    touch frameworks/base/core/xsd/vts/Android.mk 2>/dev/null || echo
fi

# Send the Telegram Message

echo -e \
"
🦊 OrangeFox Recovery CI

✔️ The Build has been Triggered!

📱 Device: "${DEVICE}"
🖥 Build System: "${FOX_BRANCH}"
🌲 Logs: <a href=\"https://cirrus-ci.com/build/${CIRRUS_BUILD_ID}\">Here</a>
" > tg.html

TG_TEXT=$(< tg.html)

telegram_message "${TG_TEXT}"
echo " "

# Prepare the Build Environment
source build/envsetup.sh

# Run the Extra Command
$EXTRA_CMD

# export some Basic Vars
export ALLOW_MISSING_DEPENDENCIES=true
export FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER=1
export LC_ALL="C"
export OF_USE_GREEN_LED=0
export FOX_ENABLE_APP_MANAGER=0
export TW_DEFAULT_LANGUAGE="en"
export ALLOW_MISSING_DEPENDENCIES=true
export OF_USE_MAGISKBOOT_FOR_ALL_PATCHES=1
export OF_NO_TREBLE_COMPATIBILITY_CHECK=1
export OF_NO_MIUI_PATCH_WARNING=1
export FOX_USE_BASH_SHELL=1
export FOX_ASH_IS_BASH=1
export FOX_USE_TAR_BINARY=1
export FOX_USE_SED_BINARY=1
export FOX_USE_XZ_UTILS=1
export OF_ENABLE_LPTOOLS=1
export OF_QUICK_BACKUP_LIST="/boot;/data;"
export OF_PATCH_AVB20=1
export OF_MAINTAINER="allworkdone"
export FOX_DELETE_AROMAFM=1
export FOX_BUGGED_AOSP_ARB_WORKAROUND="1616300800"; # Sun 21 Mar 04:26:40 GMT 2021
export OF_SCREEN_H=2400
export OF_STATUS_H=100
export OF_STATUS_INDENT_LEFT=155
export OF_STATUS_INDENT_RIGHT=48
export OF_HIDE_NOTCH=1
export OF_CLOCK_POS=0
cd $SYNC_PATH/vendor/recovery/FoxFiles
rm Magisk.zip
wget https://github.com/topjohnwu/Magisk/releases/download/v25.2/Magisk-v25.2.apk
mv Magisk-v25.2.apk Magisk.zip
cd ../../..

# Default Build Type
if [ -z "$FOX_BUILD_TYPE" ]; then
    export FOX_BUILD_TYPE="R12.1-A13"
fi

# Default Maintainer's Name
[ -z "$OF_MAINTAINER" ] && export OF_MAINTAINER="Unknown"

# Set BRANCH_INT variable for future use
BRANCH_INT=$(echo $SYNC_BRANCH | cut -d. -f1)

# Magisk
if [[ $OF_USE_LATEST_MAGISK = "true" || $OF_USE_LATEST_MAGISK = "1" ]]; then
	echo "Using the Latest Release of Magisk..."
	export FOX_USE_SPECIFIC_MAGISK_ZIP=$("ls" ~/Magisk/Magisk*.zip)
fi

# Legacy Build Systems
if [ $BRANCH_INT -le 6 ]; then
    export OF_DISABLE_KEYMASTER2=1 # Disable Keymaster2
    export OF_LEGACY_SHAR512=1 # Fix Compilation on Legacy Build Systems
fi

# lunch the target
if [ "$BRANCH_INT" -ge 11 ]; then
    lunch twrp_${DEVICE}-eng || { echo "ERROR: Failed to lunch the target!" && exit 1; }
else
    lunch omni_${DEVICE}-eng || { echo "ERROR: Failed to lunch the target!" && exit 1; }
fi

# Build the Code
if [ -z "$J_VAL" ]; then
    mka -j$(nproc --all) $TARGET || { echo "ERROR: Failed to Build OrangeFox!" && exit 1; }
elif [ "$J_VAL"="0" ]; then
    mka $TARGET || { echo "ERROR: Failed to Build OrangeFox!" && exit 1; }
else
    mka -j${J_VAL} $TARGET || { echo "ERROR: Failed to Build OrangeFox!" && exit 1; }
fi

# Exit
exit 0
