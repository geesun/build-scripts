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

UBUNTU_COMMIT_ID="ea2285daccaa73a7e9189a079ec7c581ff18e682"
UBUNTU_URL="git://git.launchpad.net/~ubuntu-kernel-test/ubuntu/+source/linux/+git/mainline-crack"

do_build() {
    cd "linux"

    local make_opts=(
        ARCH=arm64
        "-j$PARALLELISM"
    )

    case "${LINUX_TOOLCHAIN}" in
    ("GNU")
        make_opts+=(
            CROSS_COMPILE="$GCC_ARM64_PREFIX"
        )
        ;;
    (*)
        echo "Bad LINUX_TOOLCHAIN value: $LINUX_TOOLCHAIN" >&2
        return 1
    esac

    local -r kernel_config_coresight=(
        # enable coresight configurations
        --enable CORESIGHT
        --enable CORESIGHT_LINKS_AND_SINKS
        --enable CORESIGHT_LINK_AND_SINK_TMC
        --enable CORESIGHT_CATU
        --enable CORESIGHT_SINK_TPIU
        --enable CORESIGHT_SINK_ETBV10
        --enable CORESIGHT_SOURCE_ETM4X
        --enable CORESIGHT_STM
        --enable CORESIGHT_CPU_DEBUG
        --enable STM_SOURCE_CONSOLE
        --enable DEBUG_INFO_NONE
    )

    local -r ubuntu_kernel_5_18_4_config=(
        --disable SYSTEM_TRUSTED_KEYS
        --disable SYSTEM_REVOCATION_LIST
    )

    if [ "$(git rev-parse --abbrev-ref HEAD)" != "n1sdp-branch" ] ; then
        git checkout HEAD -b n1sdp-branch
    fi
    local GIT_HASH="$(git rev-parse HEAD)"
    local GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

    LINUX_OUT_DIR="out/${PLATFORM}_${FILESYSTEM}"
    mkdir -p "$LINUX_OUT_DIR"
    mkdir -p "$PLATFORM_OUT_DIR/intermediates/"

    make O="$LINUX_OUT_DIR" "${make_opts[@]}" defconfig
    ./scripts/config --file "$LINUX_OUT_DIR/.config" --enable REALTEK_PHY
    ./scripts/config --file "$LINUX_OUT_DIR/.config" --enable R8169
    ./scripts/config --file "$LINUX_OUT_DIR/.config" --enable USB_CONN_GPIO
    ./scripts/config --file "$LINUX_OUT_DIR/.config" --disable USB_XHCI_PCI_RENESAS

    make O="$LINUX_OUT_DIR" "${make_opts[@]}" Image

    cp "$LINUX_OUT_DIR/arch/arm64/boot/Image" \
        "$PLATFORM_OUT_DIR/intermediates/kernel_Image_$FILESYSTEM"

    if [ "$FILESYSTEM" = "ubuntu" ]; then
        # Pull and merge the debian patches from ubuntu repository
        mkdir -p "$PLATFORM_OUT_DIR/intermediates/linux-ubuntu"
        git fetch "$UBUNTU_URL" "$UBUNTU_COMMIT_ID"
        git checkout FETCH_HEAD -b ubuntu-branch
        git checkout "$GIT_BRANCH"
        git merge --no-ff --no-edit ubuntu-branch

        UBUNTU_OUT_DIR="out/n1sdp_debian"
        mkdir -p "$UBUNTU_OUT_DIR"

        cat debian.master/config/config.common.ubuntu \
            debian.master/config/arm64/config.common.arm64 \
            > $UBUNTU_OUT_DIR/.config

        # avoid relinking due to timestamp on .config when its contents didn't
        # change
        export KCONFIG_CONFIG_UBUNTU="$UBUNTU_OUT_DIR/.config"
        ./scripts/config --file "$KCONFIG_CONFIG_UBUNTU" "${kernel_config_coresight[@]}"
        ./scripts/config --file "$KCONFIG_CONFIG_UBUNTU" "${ubuntu_kernel_5_18_4_config[@]}"

        make "${make_opts[@]}" O="$UBUNTU_OUT_DIR" olddefconfig
        make "${make_opts[@]}" O="$UBUNTU_OUT_DIR" bindeb-pkg

        unset KCONFIG_CONFIG_UBUNTU
        rm -f "$PLATFORM_OUT_DIR/intermediates/linux-ubuntu"/*
        cp -a out/linux-image*.deb \
           "$PLATFORM_OUT_DIR/intermediates/linux-ubuntu/linux-image-n1sdp.deb"
        cp -a out/linux-headers*.deb \
           "$PLATFORM_OUT_DIR/intermediates/linux-ubuntu/linux-headers-n1sdp.deb"

        git stash
        git reset --hard "$GIT_HASH"
        git stash apply || true
        git branch -D ubuntu-branch
    fi
}

do_clean() {
    pushd "$(pwd)/linux"
    make distclean
    rm -f "$PLATFORM_OUT_DIR/intermediates/kernel_Image_$FILESYSTEM"
    rm -rf "out/n1sdp_$FILESYSTEM"
    if [ "$FILESYSTEM" = "ubuntu" ]; then
        rm -rf "$PLATFORM_OUT_DIR/intermediates/linux-ubuntu"
        rm -rf "out/n1sdp_debian"
        rm -rf "out/linux"*
	if [ `git branch | egrep "^[[:space:]]+ubuntu-branch$"` ]; then
            git branch -D ubuntu-branch
        fi
    fi
    popd
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
