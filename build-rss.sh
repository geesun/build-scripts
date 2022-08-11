#!/bin/bash

# Copyright (c) 2022, Arm Limited. All rights reserved.
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
# to endorse or promote products derived from this software without specific
# prior written permission.
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

sign_image() {
# $1 ... host binary name to sign
# $2 ... image load address
# $3 ... signed bin size
# Note: The signed binary is copied to ${DEPLOY_DIR}/${PLATFORM}

    host_bin="$DEPLOY_DIR/$PLATFORM/`basename ${1}`"
    signed_bin="$RSS_BINDIR/signed_`basename ${1}`"
    host_binary_layout="`basename -s .bin ${1}`_ns"

    cat << EOF > $RSS_OUTDIR/build/$host_binary_layout
enum image_attributes {
    RE_IMAGE_LOAD_ADDRESS = $2,
    RE_SIGN_BIN_SIZE = $3,
};
EOF

    if [ ! -f $host_bin ]
    then
        die "${host_bin} does not exist"
    fi

    info_echo "Signing `basename ${1}`"

    pushd $RSS_OUTDIR/build/lib/ext/mcuboot-src/scripts > /dev/null
    python3 $RSS_SRC/bl2/ext/mcuboot/scripts/wrapper/wrapper.py \
            -v $RSS_LAYOUT_WRAPPER_VERSION \
            --layout $RSS_OUTDIR/build/$host_binary_layout \
            -k $RSS_SIGN_PRIVATE_KEY \
            --public-key-format full \
            --align 1 \
            --pad \
            --pad-header \
            -H 0x1000 \
            -s $RSS_SEC_CNTR_INIT_VAL \
            $host_bin  \
            $signed_bin

    echo "created signed_`basename ${1}`"
    popd > /dev/null
}

do_build() {
    info_echo "Building RSS"
    mkdir -p "$RSS_OUTDIR"

    local makeopts=(
        -S $RSS_SRC
        -B $RSS_OUTDIR/build
        -DTFM_PLATFORM=$RSS_PLATFORM
        -DCROSS_COMPILE=$RSS_COMPILER
        -DTFM_TOOLCHAIN_FILE=$RSS_TOOLCHAIN_FILE
        -DCMAKE_BUILD_TYPE=$RSS_BUILD_TYPE
        -DTFM_TEST_REPO_PATH=$RSS_TEST_REPO_PATH
        -DMCUBOOT_IMAGE_NUMBER=$RSS_IMAGE_NUMBER
    )

    $CMAKE "${makeopts[@]}"
    $CMAKE --build "$RSS_OUTDIR/build" -- install
}

do_clean() {
    info_echo "Cleaning $RSS_OUTDIR"
    rm -rf $RSS_OUTDIR
}

do_patch() {
    info_echo "Patching RSS"
    PATCHES_DIR=$FILES_DIR/rss/${PLATFORM}
    with_default_shell_opts patching $PATCHES_DIR $RSS_SRC
}

do_deploy() {
    #sign SCP and AP images
    #Expects the mentioned bin from the deploy directory

    RSS_SIGN_AP_BL1_NAME=$RSS_SIGN_AP_BL1_NAME_BUILDROOT
    if [[ $FILESYSTEM == "android-swr" ]]; then
        RSS_SIGN_AP_BL1_NAME=$RSS_SIGN_AP_BL1_NAME_ANDROID
    fi
    sign_image $RSS_SIGN_AP_BL1_NAME \
	    $RSS_SIGN_AP_BL1_LOAD_ADDRESS $RSS_SIGN_AP_BL1_BIN_SIZE
    sign_image $RSS_SIGN_SCP_BL1_NAME \
	    $RSS_SIGN_SCP_BL1_LOAD_ADDRESS $RSS_SIGN_SCP_BL1_BIN_SIZE

    #create rom.bin and flash.bin
    srec_cat \
    $RSS_BINDIR/bl1_1.bin -Binary -offset 0x0 \
    $RSS_BINDIR/bl1_provisioning_bundle.bin -Binary -offset 0xE000 \
    -o $DEPLOY_DIR/$PLATFORM/rss_rom.bin -Binary

    info_echo "Created rss_rom.bin"

    srec_cat \
    $RSS_BINDIR/bl2_signed.bin -Binary -offset 0x0 \
    $RSS_BINDIR/bl2_signed.bin -Binary -offset 0x20000 \
    $RSS_BINDIR/tfm_s_ns_signed.bin -Binary -offset 0x40000 \
    $RSS_BINDIR/tfm_s_ns_signed.bin -Binary -offset 0x140000 \
    $RSS_BINDIR/signed_${RSS_SIGN_AP_BL1_NAME} -Binary -offset 0x240000 \
    $RSS_BINDIR/signed_${RSS_SIGN_SCP_BL1_NAME} -Binary -offset 0x2C0000 \
    $RSS_BINDIR/signed_${RSS_SIGN_AP_BL1_NAME} -Binary -offset 0x340000 \
    $RSS_BINDIR/signed_${RSS_SIGN_SCP_BL1_NAME} -Binary -offset 0x3C0000 \
    -o $DEPLOY_DIR/$PLATFORM/rss_flash.bin -Binary

    info_echo "Created rss_flash.bin"
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
