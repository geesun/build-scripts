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
    info_echo "Building optee-test"
    local makeopts_client=(
        CROSS_COMPILE=$OPTEE_COMPILER-
        O=$OPTEE_CLIENT_OUT
    )
    local makeopts_test=(
        CROSS_COMPILE_HOST=$OPTEE_COMPILER-
        CROSS_COMPILE_TA=$OPTEE_COMPILER-
        TA_DEV_KIT_DIR=$OPTEE_OUT/export-ta_arm64
        OPTEE_CLIENT_EXPORT=$OPTEE_CLIENT_OUT/export/usr
        O=$OPTEE_TEST_OUT
    )
    pushd $OPTEE_CLIENT_SRC
    make -j $PARALLELISM ${makeopts_client[@]}
    popd
    install -D $OPTEE_CLIENT_OUT/tee-supplicant/tee-supplicant $BUILDROOT_ROOTFS_OVERLAY/bin/tee-supplicant
    install -D $OPTEE_CLIENT_OUT/libteec/libteec.so $BUILDROOT_ROOTFS_OVERLAY/lib/libteec.so.1
    pushd $OPTEE_TEST_SRC
    make -j $PARALLELISM ${makeopts_test[@]} all
    popd
    install -D $OPTEE_TEST_OUT/xtest/xtest $BUILDROOT_ROOTFS_OVERLAY/bin/xtest
    mkdir -p $BUILDROOT_ROOTFS_OVERLAY/lib/optee_armtz
    install -D $OPTEE_TEST_OUT/ta/*/*.ta $BUILDROOT_ROOTFS_OVERLAY/lib/optee_armtz/
    mkdir -p $BUILDROOT_ROOTFS_OVERLAY/usr/lib/tee-supplicant/plugins
    install -D $OPTEE_TEST_OUT/supp_plugin/*.plugin $BUILDROOT_ROOTFS_OVERLAY/usr/lib/tee-supplicant/plugins/
}

do_clean() {
    info_echo "Cleaning optee-test"
    rm -rf $OPTEE_CLIENT_OUT
    rm -rf $OPTEE_TEST_OUT
}

do_deploy() {
    info_echo "optee-test: Nothing to deploy"
}

do_patch() {
    info_echo "Patching optee-test"
    PATCHES_DIR=$FILES_DIR/optee_test/$PLATFORM/
    with_default_shell_opts patching $PATCHES_DIR $OPTEE_TEST_SRC
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
