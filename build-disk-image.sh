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

readonly ESP_SIZE="64M"
readonly ESP_SIZE_UBUNTU="32M"

do_build() {
    local grub_cfg
    local initramfs
    local -a partitions
    case "$FILESYSTEM" in
    ("none")
        ;;
    ("ubuntu")
        partitions=(
            "$PLATFORM_OUT_DIR/intermediates/$FILESYSTEM.root.img"
        )
        "$SCRIPT_DIR/tools/mk-part-fat" \
            -o "$PLATFORM_OUT_DIR/intermediates/$FILESYSTEM.esp.img" \
            -s "$ESP_SIZE_UBUNTU" \
            -l "ESP" \
            "$PLATFORM_OUT_DIR/intermediates/grub/output/grubaa64.efi" \
                "/EFI/BOOT/BOOTAA64.EFI" \
            "$SCRIPT_DIR/config/ubuntu/ubuntu.cfg" \
                "/GRUB/grub.cfg"

        "$SCRIPT_DIR/tools/mk-disk-msdos" \
            -o "$PLATFORM_OUT_DIR/intermediates/$FILESYSTEM.img" \
            "$PLATFORM_OUT_DIR/intermediates/$FILESYSTEM.esp.img" \
            "${partitions[@]}"

        mv "$PLATFORM_OUT_DIR/intermediates/$FILESYSTEM.img" "$PLATFORM_OUT_DIR/"
        ;;
    (*)
        grub_cfg="$SCRIPT_DIR/config/$FILESYSTEM/grub_$PLATFORM.cfg"
        initramfs="$PLATFORM_OUT_DIR/intermediates/$FILESYSTEM.initramfs"
        partitions=(
            "$PLATFORM_OUT_DIR/intermediates/$FILESYSTEM.root.img"
        )

        "$SCRIPT_DIR/tools/mk-part-fat" \
            -o "$PLATFORM_OUT_DIR/intermediates/$FILESYSTEM.esp.img" \
            -s "$ESP_SIZE" \
            -l "ESP" \
            "$PLATFORM_OUT_DIR/intermediates/grub/output/grubaa64.efi" \
                "/EFI/BOOT/BOOTAA64.EFI" \
            "$grub_cfg" \
                "/GRUB/GRUB.CFG" \
            "$PLATFORM_OUT_DIR/intermediates/n1sdp-single-chip.dtb" \
                "/N1SDP_SINGLE_CHIP.DTB" \
            "$PLATFORM_OUT_DIR/intermediates/n1sdp-multi-chip.dtb" \
                "/N1SDP_MULTI_CHIP.DTB" \
            "$PLATFORM_OUT_DIR/intermediates/kernel_Image_$FILESYSTEM" "/IMAGE" \
            "$initramfs" "/INITRAMFS"

        "$SCRIPT_DIR/tools/mk-disk-msdos" \
            -o "$PLATFORM_OUT_DIR/intermediates/$FILESYSTEM.img" \
            "$PLATFORM_OUT_DIR/intermediates/$FILESYSTEM.esp.img" \
            "${partitions[@]}"

        mv "$PLATFORM_OUT_DIR/intermediates/$FILESYSTEM.img" "$PLATFORM_OUT_DIR/"
        ;;
    esac
}

do_clean() {
    rm -f "$PLATFORM_OUT_DIR/${FILESYSTEM}.img"
    case "$FILESYSTEM" in
    ("none")
        ;;
    ("ubuntu"*)
        rm -f \
            "$PLATFORM_OUT_DIR/intermediates/ubuntu.esp.img" \
            "$PLATFORM_OUT_DIR/intermediates/ubuntu.img"
        ;;
    ("busybox"*)
        rm -f \
            "$PLATFORM_OUT_DIR/intermediates/busybox.esp.img" \
            "$PLATFORM_OUT_DIR/intermediates/busybox.img"
        ;;
    (*) false
    esac
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
