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

readonly FIRMWARE_DIR="n1sdp-board-firmware"
readonly PRIMARY_DIR="n1sdp-board-firmware_primary"
readonly SECONDARY_DIR="n1sdp-board-firmware_secondary"

readonly SOC_BINARIES=( mcp_fw.bin scp_fw.bin mcp_rom.bin scp_rom.bin )

prepare_package() {
    cd ${WORKSPACE_DIR}

    mkdir -p "${PLATFORM_OUT_DIR}/intermediates/${PRIMARY_DIR}"
    mkdir -p "${PLATFORM_OUT_DIR}/intermediates/${SECONDARY_DIR}"

    # Primary
    cp -av "${WORKSPACE_DIR}/bsp/${FIRMWARE_DIR}"/* \
        "${PLATFORM_OUT_DIR}/intermediates/${PRIMARY_DIR}"
    rm -rf "${PLATFORM_OUT_DIR}/intermediates/${PRIMARY_DIR}/SOFTWARE"/*

    # Copy fip binary
    cp -v "${PLATFORM_OUT_DIR}/firmware/fip.bin" \
            "${PLATFORM_OUT_DIR}/intermediates/${PRIMARY_DIR}/SOFTWARE/"

    # Copy SOC binaries
    for f in "${SOC_BINARIES[@]}" ; do
        cp -v "${PLATFORM_OUT_DIR}/firmware/${f}" \
            "${PLATFORM_OUT_DIR}/intermediates/${PRIMARY_DIR}/SOFTWARE/"
    done

    sed -i -e 's|^C2C_ENABLE.*|C2C_ENABLE: TRUE            ;C2C enable TRUE/FALSE|' \
        "${PLATFORM_OUT_DIR}/intermediates/${PRIMARY_DIR}/MB/HBI0316A/io_v123f.txt"
    sed -i -e 's|^C2C_SIDE.*|C2C_SIDE: MASTER            ;C2C side SLAVE/MASTER|' \
        "${PLATFORM_OUT_DIR}/intermediates/${PRIMARY_DIR}/MB/HBI0316A/io_v123f.txt"
    sed -i -e 's|.*SOCCON: 0x1170.*PLATFORM_CTRL.*|SOCCON: 0x1170 0x00000100   ;SoC SCC PLATFORM_CTRL|' \
        "${PLATFORM_OUT_DIR}/intermediates/${PRIMARY_DIR}/MB/HBI0316A/io_v123f.txt"

    # Secondary
    cp -av "${WORKSPACE_DIR}/bsp/${FIRMWARE_DIR}"/* \
        "${PLATFORM_OUT_DIR}/intermediates/${SECONDARY_DIR}"
    rm -rf "${PLATFORM_OUT_DIR}/intermediates/${SECONDARY_DIR}/SOFTWARE"/*

    # Copy SOC binaries
    for f in "${SOC_BINARIES[@]}" ; do
        cp -v "${PLATFORM_OUT_DIR}/firmware/${f}" \
            "${PLATFORM_OUT_DIR}/intermediates/${SECONDARY_DIR}/SOFTWARE/"
    done

    sed -i -e 's|^C2C_ENABLE.*|C2C_ENABLE: TRUE            ;C2C enable TRUE/FALSE|' \
        "${PLATFORM_OUT_DIR}/intermediates/${SECONDARY_DIR}/MB/HBI0316A/io_v123f.txt"
    sed -i -e 's|^C2C_SIDE.*|C2C_SIDE: SLAVE             ;C2C side SLAVE/MASTER|' \
        "${PLATFORM_OUT_DIR}/intermediates/${SECONDARY_DIR}/MB/HBI0316A/io_v123f.txt"
    sed -i -e 's|.*SOCCON: 0x1170.*PLATFORM_CTRL.*|SOCCON: 0x1170 0x00000101   ;SoC SCC PLATFORM_CTRL|' \
        "${PLATFORM_OUT_DIR}/intermediates/${SECONDARY_DIR}/MB/HBI0316A/io_v123f.txt"
    sed -i -e '/^TOTALIMAGES:/ s|5|4|' \
        "${PLATFORM_OUT_DIR}/intermediates/${SECONDARY_DIR}/MB/HBI0316A/images.txt"
    sed -i -e 's|^IMAGE4|;&|' \
        "${PLATFORM_OUT_DIR}/intermediates/${SECONDARY_DIR}/MB/HBI0316A/images.txt"

    # Compress the files
    tar -C "${PLATFORM_OUT_DIR}/intermediates/${PRIMARY_DIR}" -zcvf \
        "${PLATFORM_OUT_DIR}/firmware/n1sdp-board-firmware_primary.tar.gz" ./
    tar -C "${PLATFORM_OUT_DIR}/intermediates/${SECONDARY_DIR}" -zcvf \
        "${PLATFORM_OUT_DIR}/firmware/n1sdp-board-firmware_secondary.tar.gz" ./
}

do_build() {
    "bsp/arm-tf/tools/fiptool/fiptool" \
        create \
        --scp-fw "$PLATFORM_OUT_DIR/intermediates/scp-ram.bin" \
        --blob uuid=cfacc2c4-15e8-4668-82be-430a38fad705,file="$PLATFORM_OUT_DIR/intermediates/tf-bl1.bin" \
        "$PLATFORM_OUT_DIR/intermediates/scp_fw.bin"

    "bsp/arm-tf/tools/fiptool/fiptool" \
        create \
        --blob uuid=54464222-a4cf-4bf8-b1b6-cee7dade539e,file="$PLATFORM_OUT_DIR/intermediates/mcp-ram.bin" \
        "$PLATFORM_OUT_DIR/intermediates/mcp_fw.bin"


local fip_tool_opts=(
        --tb-fw "$PLATFORM_OUT_DIR/intermediates/tf-bl2.bin"
        --nt-fw "$PLATFORM_OUT_DIR/intermediates/uefi.bin"
        --soc-fw "$PLATFORM_OUT_DIR/intermediates/tf-bl31.bin"
        --fw-config "$PLATFORM_OUT_DIR/intermediates/"$PLATFORM"_fw_config.dtb"
        --tb-fw-config "$PLATFORM_OUT_DIR/intermediates/"$PLATFORM"_tb_fw_config.dtb"
        --nt-fw-config "$PLATFORM_OUT_DIR/intermediates/"$PLATFORM"_nt_fw_config.dtb"
        --trusted-key-cert "$PLATFORM_OUT_DIR/intermediates/tfa-certs/trusted_key.crt"
        --soc-fw-key-cert "$PLATFORM_OUT_DIR/intermediates/tfa-certs/bl31_key.crt"
        --nt-fw-key-cert "$PLATFORM_OUT_DIR/intermediates/tfa-certs/bl33_key.crt"
        --soc-fw-cert "$PLATFORM_OUT_DIR/intermediates/tfa-certs/bl31.crt"
        --nt-fw-cert "$PLATFORM_OUT_DIR/intermediates/tfa-certs/bl33.crt"
        --tb-fw-cert "$PLATFORM_OUT_DIR/intermediates/tfa-certs/bl2.crt"
    )

    mkdir -p "$PLATFORM_OUT_DIR/intermediates/tfa-certs"
    "bsp/arm-tf/tools/cert_create/cert_create" "${fip_tool_opts[@]}" -n --tfw-nvctr 0 --ntfw-nvctr 0 \
        --rot-key "bsp/arm-tf/plat/arm/board/common/rotpk/arm_rotprivk_rsa.pem"

    "bsp/arm-tf/tools/fiptool/fiptool" update "${fip_tool_opts[@]}" "$PLATFORM_OUT_DIR/intermediates/fip.bin"

    mkdir -p "$PLATFORM_OUT_DIR/firmware"
    install --mode=644 "$PLATFORM_OUT_DIR/intermediates/scp_fw.bin"   "$PLATFORM_OUT_DIR/firmware/scp_fw.bin"
    install --mode=644 "$PLATFORM_OUT_DIR/intermediates/mcp_fw.bin"   "$PLATFORM_OUT_DIR/firmware/mcp_fw.bin"
    install --mode=644 "$PLATFORM_OUT_DIR/intermediates/fip.bin"      "$PLATFORM_OUT_DIR/firmware/fip.bin"
    install --mode=644 "$PLATFORM_OUT_DIR/intermediates/scp_rom.bin"  "$PLATFORM_OUT_DIR/firmware/scp_rom.bin"
    install --mode=644 "$PLATFORM_OUT_DIR/intermediates/mcp_rom.bin"  "$PLATFORM_OUT_DIR/firmware/mcp_rom.bin"
    prepare_package
}

do_clean() {
    rm -f \
        "$PLATFORM_OUT_DIR/intermediates/mcp_fw.bin" \
        "$PLATFORM_OUT_DIR/intermediates/scp_fw.bin" \
        "$PLATFORM_OUT_DIR/intermediates/fip.bin" \
        "$PLATFORM_OUT_DIR/firmware/mcp_fw.bin" \
        "$PLATFORM_OUT_DIR/firmware/mcp_rom.bin" \
        "$PLATFORM_OUT_DIR/firmware/scp_fw.bin" \
        "$PLATFORM_OUT_DIR/firmware/scp_rom.bin" \
        "$PLATFORM_OUT_DIR/firmware/n1sdp-board-firmware_primary.tar.gz" \
        "$PLATFORM_OUT_DIR/firmware/n1sdp-board-firmware_secondary.tar.gz" \
        "$PLATFORM_OUT_DIR/firmware/fip.bin"

    rm -rf \
        "${PLATFORM_OUT_DIR}/intermediates/${PRIMARY_DIR}" \
        "${PLATFORM_OUT_DIR}/intermediates/${SECONDARY_DIR}" \
        "${PLATFORM_OUT_DIR}/intermediates/tfa-certs"

    if [[ -e "$PLATFORM_OUT_DIR/firmware" ]] ; then
        rmdir --ignore-fail-on-non-empty "$PLATFORM_OUT_DIR/firmware"
    fi
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
