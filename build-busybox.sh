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
    local -r gen_init_cpio="$WORKSPACE_DIR/linux/out/n1sdp_busybox/usr/gen_init_cpio"
    [[ -x "$gen_init_cpio" ]] ||
        die "Failed to locate kernel host executable artifact: $gen_init_cpio"
    cd "busybox"

    local -r busybox_cfg_dir="$SCRIPT_DIR/config/busybox"
    if [[ "$busybox_cfg_dir/config" -nt ".config" ]] ; then
        make \
            CROSS_COMPILE="$GCC_ARM64_PREFIX" \
            KBUILD_DEFCONFIG="$busybox_cfg_dir/config" \
            "-j$PARALLELISM" \
            defconfig
    fi
    make \
        CROSS_COMPILE="$GCC_ARM64_PREFIX" \
        "-j$PARALLELISM" \
        busybox

    echo "busybox: generate initramfs..."
    # paths in initramfs.list are relative to WORKSPACE_DIR
    cd "$WORKSPACE_DIR"
    "$gen_init_cpio" "$SCRIPT_DIR/config/busybox/initramfs.list" \
        > "$PLATFORM_OUT_DIR/intermediates/busybox.initramfs"

    : > "$PLATFORM_OUT_DIR/intermediates/busybox.root.img"
    truncate \
        --size="${BUSYBOX_FS_EXT4_SIZE}M" \
        "$PLATFORM_OUT_DIR/intermediates/busybox.root.img"
    mkfs.ext4 "$PLATFORM_OUT_DIR/intermediates/busybox.root.img"
}

do_clean() {
    make -C "busybox" mrproper
    rm -f \
        "$PLATFORM_OUT_DIR/intermediates/busybox.initramfs" \
        "$PLATFORM_OUT_DIR/intermediates/busybox.root.img" \
        "$PLATFORM_OUT_DIR/intermediates/busybox.esp.img"
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
