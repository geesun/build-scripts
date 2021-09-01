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
    local make_opts=(
        -a AARCH64
        -s
        -p "edk2-platforms/Platform/ARM/N1Sdp/N1SdpPlatform.dsc"
    )
    local artifact_dir="$WORKSPACE_DIR/bsp/uefi/edk2/Build/n1sdp/"

    case "${UEFI_BUILD_MODE^^}" in
    ("DEBUG"|"RELEASE")
        make_opts+=( -b "${UEFI_BUILD_MODE^^}" )
        artifact_dir+="${UEFI_BUILD_MODE^^}"
        ;;
    (*) die "Unsupported value for UEFI_BUILD_MODE: $UEFI_BUILD_MODE"
    esac
    artifact_dir+="_"

    case "${UEFI_TOOLCHAIN^^}" in
    ("GNU")
        make_opts+=( -t GCC5 )
        artifact_dir+="GCC5"
        ;;
    (*)
        echo "Bad UEFI_TOOLCHAIN value: $UEFI_TOOLCHAIN" >&2
        return 1
    esac
    artifact_dir+="/FV"

    export GCC5_AARCH64_PREFIX="$GCC_ARM64_PREFIX"
    export IASL_PREFIX="$WORKSPACE_DIR/tools/acpica/generate/unix/bin/"
    export PACKAGES_PATH="$WORKSPACE_DIR/bsp/uefi/edk2/edk2-platforms"
    export PYTHON_COMMAND="python3"

    make -C "tools/acpica" "-j$PARALLELISM" iasl
    make -C "bsp/uefi/edk2/BaseTools" "-j$PARALLELISM"

    cd "bsp/uefi/edk2"
    with_default_shell_opts source ./edksetup.sh --reconfig
    BaseTools/BinWrappers/PosixLike/build "${make_opts[@]}"

    mkdir -p "$PLATFORM_OUT_DIR/intermediates"
    cp "$artifact_dir/BL33_AP_UEFI.fd" "$PLATFORM_OUT_DIR/intermediates/uefi.bin"
}

do_clean() {
    rm -rf \
        "bsp/uefi/edk2/Build" \
        "bsp/uefi/edk2/Conf/BuildEnv.sh" \
        "$PLATFORM_OUT_DIR/intermediates/uefi.bin"

    make --no-print-directory -C "tools/acpica" veryclean
    make --no-print-directory -C "bsp/uefi/edk2/BaseTools" clean
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
