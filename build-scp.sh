#!/usr/bin/env bash

# Copyright (c) 2021-2022, ARM Limited and Contributors. All rights reserved.
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
# to endorse or promote products derived from this software without
# specific prior written permission.
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
    local build_path="output/$PLATFORM/intermediates/scp/cmake-build/product/n1sdp"
    for scp_fw in mcp_romfw scp_romfw scp_ramfw mcp_ramfw; do
        local makeopts=(
            -S "bsp/scp"
            -B "$build_path/$scp_fw"
            -DCMAKE_ASM_COMPILER="${GCC_ARM32_PREFIX}gcc"
            -DCMAKE_C_COMPILER="${GCC_ARM32_PREFIX}gcc"
            -DSCP_ENABLE_DEBUGGER="$SCP_CLI_DEBUGGER"
            -DSCP_FIRMWARE_SOURCE_DIR:PATH="n1sdp/$scp_fw"
            -DSCP_TOOLCHAIN:STRING="GNU"
            -DDISABLE_CPPCHECK="$SCP_DISABLE_CPPCHECK"
        )

        if [[ "$scp_fw" == "scp_ramfw" ]] ; then
           makeopts+=( "-DSCP_N1SDP_SENSOR_LIB_PATH=$WORKSPACE_DIR/bsp/n1sdp-board-firmware/LIB/sensor.a" )
        fi

        case "${SCP_BUILD_MODE,,}" in
        ("release") makeopts+=( "-DCMAKE_BUILD_TYPE=Release" ) ;;
        ("debug") makeopts+=( "-DCMAKE_BUILD_TYPE=Debug" ) ;;
        (*) die "Unsupported value for SCP_BUILD_MODE: $SCP_BUILD_MODE"
        esac

        if [[ -v "SCP_LOG_LEVEL" ]] ; then
            makeopts+=( "-DSCP_LOG_LEVEL=${SCP_LOG_LEVEL^^}" )
        fi

        cmake "${makeopts[@]}"
        cmake --build "$build_path/$scp_fw" --parallel "$PARALLELISM"
    done

    mkdir -p "$PLATFORM_OUT_DIR/intermediates"
    cp "$build_path/scp_ramfw/bin/n1sdp-bl2.bin"     "$PLATFORM_OUT_DIR/intermediates/scp-ram.bin"
    cp "$build_path/scp_romfw/bin/n1sdp-bl1.bin"     "$PLATFORM_OUT_DIR/intermediates/scp_rom.bin"
    cp "$build_path/mcp_ramfw/bin/n1sdp-mcp-bl2.bin" "$PLATFORM_OUT_DIR/intermediates/mcp-ram.bin"
    cp "$build_path/mcp_romfw/bin/n1sdp-mcp-bl1.bin" "$PLATFORM_OUT_DIR/intermediates/mcp_rom.bin"
}

do_clean() {
    rm -rf \
        "$PLATFORM_OUT_DIR/intermediates/scp/cmake-build/product/n1sdp" \
        "$PLATFORM_OUT_DIR/intermediates/mcp-ram.bin" \
        "$PLATFORM_OUT_DIR/intermediates/mcp_rom.bin" \
        "$PLATFORM_OUT_DIR/intermediates/scp-ram.bin" \
        "$PLATFORM_OUT_DIR/intermediates/scp_rom.bin"

}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
