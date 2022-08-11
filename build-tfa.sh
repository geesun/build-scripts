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

do_build() {

    info_echo "Building TF-A"

    # Copy sp_layout.json to TFA_SP_DIR
    cp $TFA_FILES/$PLATFORM/sp_layout.json $TFA_SP_DIR

    pushd $TFA_SRC
    make "${make_opts[@]}" "${make_opts_tfa[@]}" all fip

    # Build additional tools
    make -j $PARALLELISM certtool
    make -j $PARALLELISM fiptool

    popd

    if [[ $TFA_GPT_SUPPORT -eq 1 ]]; then
        do_generate_gpt
    fi

}

do_generate_gpt() {
    BUILD_TYPE=release
    if [[ $TFA_DEBUG -eq 1 ]]; then
        BUILD_TYPE=debug
    fi

    OUTDIR=$TFA_OUTDIR/build/tc/$BUILD_TYPE
    gpt_image="${OUTDIR}/fip_gpt.bin"
    fip_bin="${OUTDIR}/fip.bin"
    # the FIP partition type is not standardized, so generate one
    fip_type_uuid=`uuidgen --sha1 --namespace @dns --name "fip_type_uuid"`
    # metadata partition type UUID, specified by the document:
    # Platform Security Firmware Update for the A-profile Arm Architecture
    # version: 1.0BET0
    metadata_type_uuid="8a7a84a0-8387-40f6-ab41-a8b9a5a60d23"
    location_uuid=`uuidgen`
    FIP_A_uuid=`uuidgen`
    FIP_B_uuid=`uuidgen`

    # maximum FIP size 4MB. This is the current size of the FIP rounded up to an integer number of MB.
    fip_max_size=4194304
    fip_bin_size=$(stat -c %s $fip_bin)
    if [ $fip_max_size -lt $fip_bin_size ]; then
        bberror "FIP binary ($fip_bin_size bytes) is larger than the GPT partition ($fip_max_size bytes)"
    fi

    # maximum metadata size 512B. This is the current size of the metadata rounded up to an integer number of sectors.
    metadata_max_size=512
    metadata_file="${OUTDIR}/metadata.bin"
    python3 $TFA_FILES/generate_metadata.py --metadata_file $metadata_file \
                                            --img_type_uuids $fip_type_uuid \
                                            --location_uuids $location_uuid \
                                            --img_uuids $FIP_A_uuid $FIP_B_uuid

    # create GPT image. The GPT contains 2 FIP partitions: FIP_A and FIP_B, and 2 metadata partitions: FWU-Metadata and Bkup-FWU-Metadata.
    # the GPT layout is the following:
    # -----------------------
    # Protective MBR
    # -----------------------
    # Primary GPT Header
    # -----------------------
    # FIP_A
    # -----------------------
    # FIP_B
    # -----------------------
    # FWU-Metadata
    # -----------------------
    # Bkup-FWU-Metadata
    # -----------------------
    # Secondary GPT Header
    # -----------------------

    sector_size=512
    gpt_header_size=33 # valid only for 512-byte sectors
    num_sectors_fip=`expr $fip_max_size / $sector_size`
    num_sectors_metadata=`expr $metadata_max_size / $sector_size`
    start_sector_1=`expr 1 + $gpt_header_size` # size of MBR is 1 sector
    start_sector_2=`expr $start_sector_1 + $num_sectors_fip`
    start_sector_3=`expr $start_sector_2 + $num_sectors_fip`
    start_sector_4=`expr $start_sector_3 + $num_sectors_metadata`
    num_sectors_gpt=`expr $start_sector_4 + $num_sectors_metadata + $gpt_header_size`
    gpt_size=`expr $num_sectors_gpt \* $sector_size`

    # create raw image
    dd if=/dev/zero of=$gpt_image bs=$gpt_size count=1

    # create the GPT layout
    sgdisk $gpt_image \
           --set-alignment 1 \
           --disk-guid $location_uuid \
           \
           --new 1:$start_sector_1:+$num_sectors_fip \
           --change-name 1:FIP_A \
           --typecode 1:$fip_type_uuid \
           --partition-guid 1:$FIP_A_uuid \
           \
           --new 2:$start_sector_2:+$num_sectors_fip \
           --change-name 2:FIP_B \
           --typecode 2:$fip_type_uuid \
           --partition-guid 2:$FIP_B_uuid \
           \
           --new 3:$start_sector_3:+$num_sectors_metadata \
           --change-name 3:FWU-Metadata \
           --typecode 3:$metadata_type_uuid \
           \
           --new 4:$start_sector_4:+$num_sectors_metadata \
           --change-name 4:Bkup-FWU-Metadata \
           --typecode 4:$metadata_type_uuid

    # populate the GPT partitions
    dd if=$fip_bin of=$gpt_image bs=$sector_size seek=$start_sector_1 count=$num_sectors_fip conv=notrunc
    dd if=$fip_bin of=$gpt_image bs=$sector_size seek=$start_sector_2 count=$num_sectors_fip conv=notrunc
    dd if=$metadata_file of=$gpt_image bs=$sector_size seek=$start_sector_3 count=$num_sectors_metadata conv=notrunc
    dd if=$metadata_file of=$gpt_image bs=$sector_size seek=$start_sector_4 count=$num_sectors_metadata conv=notrunc
}


do_clean() {
    info_echo "Cleaning TF-A"
    pushd $TFA_SRC
    make "${make_opts[@]}" "${make_opts_tfa[@]}" clean
    popd
    rm -rf $TFA_SP_DIR
}

do_deploy() {
    # Copy binaries to deploy directory
    BUILD_TYPE=release
    if [[ $TFA_DEBUG -eq 1 ]]; then
        BUILD_TYPE=debug
    fi

    ln -s $TFA_OUTDIR/build/$TFA_PLATFORM/$BUILD_TYPE/bl1.bin $DEPLOY_DIR/$PLATFORM/bl1-tc.bin 2>/dev/null || :
    ln -s $TFA_OUTDIR/build/$TFA_PLATFORM/$BUILD_TYPE/bl1/bl1.elf $DEPLOY_DIR/$PLATFORM/bl1-tc.elf 2>/dev/null || :
    ln -s $TFA_OUTDIR/build/$TFA_PLATFORM/$BUILD_TYPE/fip.bin $DEPLOY_DIR/$PLATFORM/fip-tc.bin 2>/dev/null || :
    if [[ $TFA_GPT_SUPPORT -eq 1 ]]; then
        ln -s $TFA_OUTDIR/build/$TFA_PLATFORM/$BUILD_TYPE/fip_gpt.bin $DEPLOY_DIR/$PLATFORM/fip_gpt-tc.bin 2>/dev/null || :
    fi
}

do_patch() {
    info_echo "Patching TF-A"
    PATCHES_DIR=$FILES_DIR/tfa/$PLATFORM/
    with_default_shell_opts patching $PATCHES_DIR $TFA_SRC
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
