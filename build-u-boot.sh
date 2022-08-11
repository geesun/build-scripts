#!/bin/bash

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
    info_echo "Building U-Boot"
    CFG_DIR=$FILES_DIR/u-boot/$PLATFORM

    pushd $UBOOT_SRC
    # Create default platform config
    make O=$UBOOT_OUTDIR CROSS_COMPILE=$UBOOT_COMPILER- $PLATFORM_CFG
    popd

    pushd $UBOOT_OUTDIR
    # Merge with config fragments if there are any
    if [[ ! -z $EXTRA_CFG ]]; then
        info_echo "Merging with config fragments.."
        CONFIG=""
        for cfg in $EXTRA_CFG; do
            CONFIG=$CONFIG"$CFG_DIR/$cfg "
        done
        $LINUX_SRC/scripts/kconfig/merge_config.sh -m -O ./ .config $CONFIG
    fi
    popd

    pushd $UBOOT_SRC
    # Build new config
    make -j $PARALLELISM O=$UBOOT_OUTDIR CROSS_COMPILE=$UBOOT_COMPILER- oldconfig

    # Build U-Boot
    make -j $PARALLELISM O=$UBOOT_OUTDIR CROSS_COMPILE=$UBOOT_COMPILER- all
    popd
}

do_clean() {
    info_echo "Cleaning U-Boot"
    pushd $UBOOT_SRC
    make O=$UBOOT_OUTDIR distclean
    popd

    rm -rf $UBOOT_OUTDIR
}

do_deploy() {
    ln -s $UBOOT_OUTDIR/u-boot.bin $DEPLOY_DIR/$PLATFORM/ 2>/dev/null || :
}

do_patch() {
    info_echo "Patching U-Boot"
    PATCHES_DIR=$FILES_DIR/u-boot/$PLATFORM/
    with_default_shell_opts patching $PATCHES_DIR $UBOOT_SRC
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
