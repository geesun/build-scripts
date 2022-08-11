#!/usr/bin/env bash

# Copyright (c) 2022, Arm Limited. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# Neither the name of ARM nor the names of its contributors may be used
# to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

do_build() {

    info_echo "Building Android"
    pushd $ANDROID_SRC

    # Source the main envsetup script.
    if [[ ! -f "build/envsetup.sh" ]]; then
        error_echo "Could not find build/envsetup.sh. Please call this file from root of android directory."
    fi

    # check if file exists and exit if it doesnt
    check_file_exists_and_exit () {
        if [ ! -f $1 ]
        then
            error_echo "$1 does not exist"
            exit 1
        fi
    }

    make_ramdisk_android_image () {
        $SCRIPT_DIR/add_uboot_header.sh
        $SCRIPT_DIR/create_android_image.sh -a $AVB
    }

    TC_MICRODROID_DEMO_SRC="packages/modules/Virtualization/tc_microdroid_demo"
    make_tc_microdroid_demo_app () {
        # If the demo app exists, then build else return 0
        if [ ! -d ${TC_MICRODROID_DEMO_SRC} ]
        then
            return 0
        fi

        info_echo "Building TC Microdroid Demo App"
        UNBUNDLED_BUILD_SDKS_FROM_SOURCE=true   \
        TARGET_BUILD_APPS=TCMicrodroidDemoApp   \
        m apps_only dist

        return $?
    }

    DISTRO=$FILESYSTEM

    [ -z "$DISTRO" ] && incorrect_script_use || echo "DISTRO=$DISTRO"
    echo "AVB=$AVB"

    KERNEL_IMAGE=$LINUX_OUTDIR/arch/arm64/boot/Image
    . build/envsetup.sh || true
    case $DISTRO in
        android-swr)
            if [ "$AVB" == true ]
            then
                check_file_exists_and_exit $KERNEL_IMAGE
                info_echo "Using $KERNEL_IMAGE for kernel"
                cp $KERNEL_IMAGE device/arm/tc
                lunch tc_swr-userdebug;
            else
                lunch tc_swr-eng;
            fi
            ;;
        *) error_echo "bad option for distro $3"; incorrect_script_use
            ;;
    esac

    # Build microdroid_demo_app before building tc_swr stack. This makes the demo
    # app to be included in the system image
    make_tc_microdroid_demo_app
    if [[ $? != 0 ]]; then
        error_echo "Building Microdroid demo App failed"
        exit 1
    fi

    if make -j "$PARALLELISM";
    then
        make_ramdisk_android_image
    else
        error_echo "Errors when building - will not create file system images"
    fi

    popd
}

do_deploy() {
    ln -s $ANDROID_SRC/out/target/product/tc_swr/android.img $DEPLOY_DIR/$PLATFORM
    ln -s $ANDROID_SRC/out/target/product/tc_swr/ramdisk_uboot.img $DEPLOY_DIR/$PLATFORM
    ln -s $ANDROID_SRC/out/target/product/tc_swr/system.img $DEPLOY_DIR/$PLATFORM
    ln -s $ANDROID_SRC/out/target/product/tc_swr/userdata.img $DEPLOY_DIR/$PLATFORM

    if [[ $AVB == "true" ]]; then
        ln -s $ANDROID_SRC/out/target/product/tc_swr/boot.img $DEPLOY_DIR/$PLATFORM
        ln -s $ANDROID_SRC/out/target/product/tc_swr/vbmeta.img $DEPLOY_DIR/$PLATFORM
    fi

}

do_clean() {
    info_echo "Cleaning Android"
    rm -rf $ANDROID_SRC/out
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
