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

update_ubuntu() {
    local OUTDIR="$PLATFORM_OUT_DIR/intermediates/linux-ubuntu"
    local UBUNTU_SETUP_DIR="$SCRIPT_DIR/config/ubuntu"
    local MNT_DIR="$PLATFORM_OUT_DIR/intermediates/mnt"

    # Clear the root password, so that we can actually log in.
    sed -ie 's/^root:x:0:/root::0:/' "$MNT_DIR/etc/passwd"
    # Set some nameserver, so apt-get will find its servers.
    echo "nameserver 8.8.8.8" >> "$MNT_DIR/etc/resolv.conf"
    # Change the hostname to n1sdp
    sed -ie 's/localhost.localdomain/n1sdp/' "$MNT_DIR/etc/hostname"
    # Copy Linux debian package
    cp "$OUTDIR/linux-image-n1sdp.deb" "$MNT_DIR"/
    cp "$OUTDIR/linux-headers-n1sdp.deb" "$MNT_DIR"/
    # Copy init for first boot of ubuntu
    cp "$UBUNTU_SETUP_DIR/init" "$MNT_DIR/bin/init"
    chmod a+x "$MNT_DIR/bin/init"
    # Create /etc/network/interfaces for networking
    mkdir -p "$MNT_DIR/etc/network"
    cp "$UBUNTU_SETUP_DIR/interfaces" "$MNT_DIR/etc/network/interfaces"
}

create_ext4part() {
    local ext4part_name="$1"
    local ext4size=$2
    local rootfs_file=$3
    local extract_dir=$4

    echo "create_ext4part: ext4part_name = $ext4part_name \
        ext4size = $ext4size rootfs_file = $rootfs_file"
    dd if=/dev/zero of="$PLATFORM_OUT_DIR/intermediates/$ext4part_name" \
        bs=$BLOCK_SIZE count=$ext4size
    mkdir -p "$PLATFORM_OUT_DIR/intermediates/mnt"
    cp "$PLATFORM_OUT_DIR/intermediates/kernel_Image_ubuntu" \
        "$PLATFORM_OUT_DIR/intermediates/mnt/Image"
    sync
    if [[ "$rootfs_file" != "" ]]; then
        mkdir -p "$PLATFORM_OUT_DIR/intermediates/$extract_dir"

        tar \
            --preserve-permissions \
            -xz \
            -f "$rootfs_file" \
            -C "$PLATFORM_OUT_DIR/intermediates/$extract_dir"
        cp -r "$PLATFORM_OUT_DIR/intermediates/$extract_dir"/* "$PLATFORM_OUT_DIR/intermediates/mnt/"
        sync
        rm -rf "$PLATFORM_OUT_DIR/intermediates/$extract_dir"
    fi
    cp "$PLATFORM_OUT_DIR/intermediates/ramdisk.img" "$PLATFORM_OUT_DIR/intermediates/mnt"
    update_ubuntu
    mkfs.ext4 -L Ubuntu-18.04 -F "$PLATFORM_OUT_DIR/intermediates/$ext4part_name" -d "$PLATFORM_OUT_DIR/intermediates/mnt"
    rm -rf "$PLATFORM_OUT_DIR/intermediates/mnt"
}

create_ramdisk() {
    local ramdisk_img="$PLATFORM_OUT_DIR/intermediates/ramdisk.img"
    rm -f "$ramdisk_img"

    mkdir -p "$PLATFORM_OUT_DIR/intermediates/"
    (
        for src in "$@" ; do
            cd "$SCRIPT_DIR/config/ubuntu/ramdisk/$src"
            if test -e "gen_init_cpio.sh" ; then
                ( . ./gen_init_cpio.sh ) | \
                    "$WORKSPACE_DIR/linux/out/n1sdp_ubuntu/usr/gen_init_cpio" -
            else
                 echo "ERROR: Unable to process ramdisk stage: $PWD" >&2
                 exit 1
            fi
        done
    ) > "$ramdisk_img"
}

do_build() {
    local -r \
        gen_init_cpio="$WORKSPACE_DIR/linux/out/n1sdp_ubuntu/usr/gen_init_cpio"
    [[ -x "$gen_init_cpio" ]] ||
        die "Failed to locate kernel host executable artifact: $gen_init_cpio"

    export ARCH=arm64

    # Generate Busybox filesystem required for first boot
    local BUSYBOX_OUT_DIR="$PLATFORM_OUT_DIR/intermediates/busybox-ubuntu"
    local BUSYBOX_PATH=busybox
    mkdir -p "$BUSYBOX_OUT_DIR"
    pushd "$WORKSPACE_DIR/$BUSYBOX_PATH"
    make mrproper
    make \
        CROSS_COMPILE="$GCC_ARM64_PREFIX" \
        O="$BUSYBOX_OUT_DIR" \
        defconfig
    sed -i \
      's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/g' $BUSYBOX_OUT_DIR/.config
    make \
        CROSS_COMPILE="$GCC_ARM64_PREFIX" \
        O="$BUSYBOX_OUT_DIR" \
        "-j$PARALLELISM" \
        install
    popd

    # Generate ubuntu filesystem
    if [ -d "$WORKSPACE_DIR/grub" ]; then
        local BLOCK_SIZE=512
        local SEC_PER_MB=$((1024*2))
        local EXT4_IMG_SIZE_MB=2048
        local PART_START=$((1*SEC_PER_MB))
        local EXT4_IMG_SIZE=$((EXT4_IMG_SIZE_MB*SEC_PER_MB-(PART_START)))

        # create root filesystem components
        create_ramdisk busybox firmware ubuntu

        create_ext4part "ubuntu.root.img" $EXT4_IMG_SIZE \
            "$WORKSPACE_DIR/tools/ubuntu_minimal_rootfs/focal-base-arm64.tar.gz" "ubuntu"
    fi
}

do_clean() {
    make -C "busybox" mrproper
    rm -rf \
        "$PLATFORM_OUT_DIR/intermediates/ubuntu.root.img" \
        "$PLATFORM_OUT_DIR/intermediates/ramdisk.img" \
        "$PLATFORM_OUT_DIR/intermediates/busybox-ubuntu"
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
