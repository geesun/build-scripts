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
    info_echo "Building SCP-firmware"
    mkdir -p "$SCP_OUTDIR"
    for scp_fw in $FW_TARGETS; do
        for scp_type in $FW_INSTALL; do
            local makeopts=(
                -S "$SCP_SRC"
                -B "$SCP_OUTDIR/$scp_fw"
                -DCMAKE_ASM_COMPILER="${SCP_COMPILER}-gcc"
                -DCMAKE_C_COMPILER="${SCP_COMPILER}-gcc"
                -DSCP_TOOLCHAIN:STRING="GNU"
                -DCMAKE_OBJCOPY="${SCP_COMPILER}-objcopy"
                -DSCP_LOG_LEVEL=${SCP_LOG_LEVEL}
            )

            case "${SCP_BUILD_MODE}" in
            ("release") makeopts+=( "-DCMAKE_BUILD_TYPE=Release" ) ;;
            ("debug") makeopts+=( "-DCMAKE_BUILD_TYPE=Debug" ) ;;
            (*) die "Unsupported value for SCP_BUILD_MODE: $SCP_BUILD_MODE"
            esac

            if [ ! -d  "$SCP_OUTDIR/$scp_fw/product/$PLATFORM/${scp_fw}_${scp_type}" ]; then
                makeopts+=("-DSCP_FIRMWARE_SOURCE_DIR:PATH="$PLATFORM/${scp_fw}_${scp_type}"")
                $CMAKE -GNinja "${makeopts[@]}"
            fi

            $CMAKE --build "$SCP_OUTDIR/$scp_fw" --parallel "$PARALLELISM"
        done
    done
}

do_clean() {
    info_echo "Cleaning SCP-firmware"
    rm -rf $SCP_OUTDIR
}

do_patch() {
    info_echo "Patching SCP-firmware"
    PATCHES_DIR=$FILES_DIR/scp/$PLATFORM/
    with_default_shell_opts patching $PATCHES_DIR $SCP_SRC
}

do_deploy() {
    # Copy binaries to deploy dir
    for scp_fw in $FW_TARGETS; do
        if [[ "$FW_INSTALL" == *"romfw"* ]]; then
            ln -s $SCP_OUTDIR/$scp_fw/bin/$SCP_PLATFORM-bl1 $DEPLOY_DIR/$PLATFORM/${scp_fw}_romfw.elf 2>/dev/null || :
            ln -s $SCP_OUTDIR/$scp_fw/bin/$SCP_PLATFORM-bl1.bin $DEPLOY_DIR/$PLATFORM/${scp_fw}_romfw.bin 2>/dev/null || :
        fi
        if [[ "$FW_INSTALL" == *"ramfw"* ]]; then
            ln -s $SCP_OUTDIR/$scp_fw/bin/$SCP_PLATFORM-bl2 $DEPLOY_DIR/$PLATFORM/${scp_fw}_ramfw.elf 2>/dev/null || :
            ln -s $SCP_OUTDIR/$scp_fw/bin/$SCP_PLATFORM-bl2.bin $DEPLOY_DIR/$PLATFORM/${scp_fw}_ramfw.bin 2>/dev/null || :
        fi
    done
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
