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
    make --no-print-directory -C "bsp/arm-tf/tools/fiptool"
    make --no-print-directory -C "bsp/arm-tf/tools/cert_create"

    local make_opts=(
        --no-print-directory
        -C "bsp/arm-tf"
        -j "$PARALLELISM"
        PLAT=n1sdp
        ARCH=aarch64
        E=0
        PLAT=n1sdp
        ARM_ROTPK_LOCATION="devel_rsa"
        CREATE_KEYS=1
        GENERATE_COT=1
        MBEDTLS_DIR="$WORKSPACE_DIR/bsp/deps/mbedtls"
        ROT_KEY="plat/arm/board/common/rotpk/arm_rotprivk_rsa.pem"
        TRUSTED_BOARD_BOOT=1
        all
    )

    artifact_dir="bsp/arm-tf/build/n1sdp/"
    case "${ARM_TF_BUILD_MODE^^}" in
    ("DEBUG")
        make_opts+=("DEBUG=1")
        artifact_dir+="debug"
        ;;
    ("RELEASE")
        make_opts+=("DEBUG=0")
        artifact_dir+="release"
        ;;
    (*) die "Unsupported value for ARM_TF_BUILD_MODE: $ARM_TF_BUILD_MODE"
    esac

    case "${ARM_TF_TOOLCHAIN^^}" in
    ("GNU")
        make_opts+=(
            CROSS_COMPILE="$GCC_ARM64_PREFIX"
        )
        ;;
    (*) die "Unsupported value for ARM_TF_TOOLCHAIN: $ARM_TF_TOOLCHAIN"
    esac

    make "${make_opts[@]}"
    mkdir -p "$PLATFORM_OUT_DIR/intermediates"
    cp "$artifact_dir/bl1.bin" \
                "$PLATFORM_OUT_DIR/intermediates/tf-bl1.bin"
    cp "$artifact_dir/bl2.bin" \
                "$PLATFORM_OUT_DIR/intermediates/tf-bl2.bin"
    cp "$artifact_dir/bl31.bin" \
                "$PLATFORM_OUT_DIR/intermediates/tf-bl31.bin"
    cp "$artifact_dir/fdts/$PLATFORM-single-chip.dtb" \
               "$PLATFORM_OUT_DIR/intermediates/$PLATFORM-single-chip.dtb"
    cp "$artifact_dir/fdts/$PLATFORM-multi-chip.dtb" \
               "$PLATFORM_OUT_DIR/intermediates/$PLATFORM-multi-chip.dtb"
    cp "$artifact_dir/fdts/"$PLATFORM"_fw_config.dtb" \
               "$PLATFORM_OUT_DIR/intermediates/"$PLATFORM"_fw_config.dtb"
    cp "$artifact_dir/fdts/"$PLATFORM"_tb_fw_config.dtb" \
               "$PLATFORM_OUT_DIR/intermediates/"$PLATFORM"_tb_fw_config.dtb"
}

do_clean() {
    rm -f \
        "$PLATFORM_OUT_DIR/intermediates/$PLATFORM-single-chip.dtb" \
        "$PLATFORM_OUT_DIR/intermediates/$PLATFORM-multi-chip.dtb" \
        "$PLATFORM_OUT_DIR/intermediates/tf-bl1.bin" \
        "$PLATFORM_OUT_DIR/intermediates/tf-bl2.bin" \
        "$PLATFORM_OUT_DIR/intermediates/tf-bl31.bin" \
        "$PLATFORM_OUT_DIR/intermediates/"$PLATFORM"_fw_config.dtb" \
        "$PLATFORM_OUT_DIR/intermediates/"$PLATFORM"_tb_fw_config.dtb"

    make --no-print-directory -C "bsp/arm-tf" distclean
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
