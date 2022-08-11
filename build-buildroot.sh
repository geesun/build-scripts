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
    info_echo "Building Buildroot"
    install -D $BUILDROOT_CFG/S09modload $BUILDROOT_ROOTFS_OVERLAY/etc/init.d/S09modload
    mkdir -p $BUILDROOT_OUT
    pushd $BUILDROOT_SRC
    make O=$BUILDROOT_OUT defconfig BR2_DEFCONFIG=$BUILDROOT_CFG/defconfig
    make O=$BUILDROOT_OUT all
    popd
}

do_clean() {
    info_echo "Cleaning Buildroot"
    pushd $BUILDROOT_SRC
    rm -rf $BUILDROOT_OUT
    popd
}

do_deploy() {
    # Create FIT Image
    $UBOOT_OUTDIR/tools/mkimage -f $BUILDROOT_CFG/fit-image.its $DEPLOY_DIR/$PLATFORM/tc-fitImage.bin
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
