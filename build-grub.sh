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

readonly GRUB_MODULES=(
    boot
    chain
    configfile
    ext2
    fat
    gettext
    help
    hfsplus
    linux
    loadenv
    lsefi
    normal
    ntfs
    ntfscomp
    part_gpt
    part_msdos
    progress
    read
    search
    search_fs_file
    search_fs_uuid
    search_label
    terminal
    terminfo
)

do_build() {
    local -r grub_work_dir="$PLATFORM_OUT_DIR/intermediates/grub"
    local -r state_file="$grub_work_dir/grub.state.configured"
    mkdir -p "$grub_work_dir/build"
    cd "$grub_work_dir/build"

    if newer_ctime "$state_file" \
        "$SCRIPT_DIR/build-grub.sh" \
        "$SCRIPT_DIR/framework.sh" \
        "$WORKSPACE_DIR/grub" \
    ; then
        env \
            -C "$WORKSPACE_DIR/grub" \
            PYTHON="python3" \
            ./bootstrap

        "$WORKSPACE_DIR/grub/configure" \
            TARGET_CC="${GCC_ARM64_PREFIX}gcc" \
            TARGET_OBJCOPY="${GCC_ARM64_PREFIX}objcopy" \
            TARGET_STRIP="${GCC_ARM64_PREFIX}strip" \
            --target=aarch64-linux-gnu \
            --prefix="$grub_work_dir/output" \
            --with-platform=efi \
            --enable-dependency-tracking \
            --disable-efiemu \
            --disable-werror \
            --disable-grub-mkfont \
            --disable-grub-themes \
            --disable-grub-mount
    else
        echo "grub: skipping bootstrap/configure"
    fi

    make --no-print-directory "-j$PARALLELISM" install

    echo 'set prefix=($root)/grub/' > "$grub_work_dir/embedded.cfg"
    "$grub_work_dir/output/bin/grub-mkimage" \
        -c "$grub_work_dir/embedded.cfg" \
        -o "$PLATFORM_OUT_DIR/intermediates/grub/output/grubaa64.efi" \
        -O arm64-efi \
        -p "" \
        "${GRUB_MODULES[@]}"

    touch "$state_file"
}

do_clean() {
    rm -rf \
        "$PLATFORM_OUT_DIR/intermediates/grub/"
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
