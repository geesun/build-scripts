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
    info_echo "Building OPTEE-OS"
    local makeopts=(
        CROSS_COMPILE_core=$OPTEE_COMPILER-
        CROSS_COMPILE_ta_arm64=$OPTEE_COMPILER-
        PLATFORM=$OPTEE_PLATFORM
        CFG_ARM64_core=y
        CFG_TEE_CORE_LOG_LEVEL=3
        CFG_TEE_BENCHMARK=n
        CFG_WITH_STATS=y
        CFG_CORE_SEL2_SPMC=y
        O=$OPTEE_OUT
    )
    mkdir -p $OPTEE_OUT
    pushd $OPTEE_SRC
    make -j $PARALLELISM ${makeopts[@]} all
    popd
    mkdir -p $TFA_SP_DIR
    cp $OPTEE_SRC/core/arch/arm/plat-totalcompute/fdts/optee_sp_manifest.dts $TFA_SP_DIR
    cp $OPTEE_OUT/core/tee-pager_v2.bin $TFA_SP_DIR
}

do_clean() {
    info_echo "Cleaning OPTEE-OS"
    rm -rf $OPTEE_OUT
}

do_deploy() {
    info_echo "OPTEE: Nothing to deploy"
}

do_patch() {
    info_echo "Patching OPTEE-OS"
    PATCHES_DIR=$FILES_DIR/optee_os/$PLATFORM/
    with_default_shell_opts patching $PATCHES_DIR $OPTEE_SRC
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
