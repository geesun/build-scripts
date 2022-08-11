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

    info_echo "Building Trusted Services"

    CFLAGS="-mgeneral-regs-only"
    export CFLAGS

    export PATH=$AARCH64_BARE_METAL:$PATH
    mkdir -p $TFA_SP_DIR
    for sp in $SECURE_PARTITIONS; do
        pushd $TS_SRC/deployments/$sp/$TS_ENVIRONMENT
        $CMAKE -S . -B build -DCROSS_COMPILE=$TS_COMPILER-
        $CMAKE --build build --parallel "$PARALLELISM"
        cp $TS_SRC/deployments/$sp/$TS_ENVIRONMENT/*.dts $TFA_SP_DIR
        cp $TS_SRC/deployments/$sp/$TS_ENVIRONMENT/build/*.bin $TFA_SP_DIR
        popd
    done

    export PATH=$AARCH64_LINUX:$PATH
    for test_app in $TS_TEST_APPS; do
        pushd $TS_SRC/deployments/$test_app/arm-linux
        $CMAKE -S . -B build -DCROSS_COMPILE=$TS_APPS_COMPILER-
        $CMAKE --build build
        install -D $TS_SRC/deployments/$test_app/arm-linux/build/$test_app $BUILDROOT_ROOTFS_OVERLAY/bin/$test_app
        install -D $TS_SRC/deployments/$test_app/arm-linux/build/libts_install/arm-linux/lib/libts.so $BUILDROOT_ROOTFS_OVERLAY/lib/libts.so
        popd
    done
}

do_clean() {
    info_echo "Cleaning Trusted Services"
    for sp in $SECURE_PARTITIONS; do
        rm -rf $TS_SRC/deployments/$sp/$TS_ENVIRONMENT/build/
    done
    for test_app in $TS_TEST_APPS; do
        rm -rf $TS_SRC/deployments/$test_app/arm-linux/build
    done
}

do_deploy() {
    info_echo "Trusted Services: Nothing to deploy"
}

do_patch() {
    info_echo "Patching Trusted Services"
    PATCHES_DIR=$FILES_DIR/ts/$PLATFORM/
    with_default_shell_opts patching $PATCHES_DIR $TS_SRC
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
