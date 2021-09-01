#!/usr/bin/env bash

# Copyright (c) 2021, ARM Limited and Contributors. All rights reserved.
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
    local makeopts=(
        --no-print-directory
        -C "bsp/scp"
        -j "$PARALLELISM"
        CC="${GCC_ARM32_PREFIX}gcc"
        DEBUGGER="n"
        PRODUCT="n1sdp"
    )

    if [[ -v "SCP_LOG_LEVEL" ]] ; then
        makeopts+=( "LOG_LEVEL=${SCP_LOG_LEVEL^^}" )
    fi

    local -r build_mode="${SCP_BUILD_MODE,,}"
    case "$build_mode" in
    ("release"|"debug")
        makeopts+=( "MODE=$build_mode" )
        ;;
    (*) die "Unsupported value for SCP_BUILD_MODE: $SCP_BUILD_MODE"
    esac

    make "${makeopts[@]}"

    mkdir -p "$PLATFORM_OUT_DIR/intermediates"
    cp "bsp/scp/build/product/n1sdp/scp_ramfw/$build_mode/bin/firmware.bin" \
        "$PLATFORM_OUT_DIR/intermediates/scp-ram.bin"
    cp "bsp/scp/build/product/n1sdp/scp_romfw/$build_mode/bin/firmware.bin" \
        "$PLATFORM_OUT_DIR/intermediates/scp_rom.bin"
    cp "bsp/scp/build/product/n1sdp/mcp_ramfw/$build_mode/bin/firmware.bin" \
        "$PLATFORM_OUT_DIR/intermediates/mcp-ram.bin"
    cp "bsp/scp/build/product/n1sdp/mcp_romfw/$build_mode/bin/firmware.bin" \
        "$PLATFORM_OUT_DIR/intermediates/mcp_rom.bin"
}

do_clean() {
    make --no-print-directory -C "bsp/scp" clean

    rm -f \
        "$PLATFORM_OUT_DIR/intermediates/mcp-ram.bin" \
        "$PLATFORM_OUT_DIR/intermediates/mcp_rom.bin" \
        "$PLATFORM_OUT_DIR/intermediates/scp-ram.bin" \
        "$PLATFORM_OUT_DIR/intermediates/scp_rom.bin"
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
