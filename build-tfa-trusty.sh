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

    info_echo "Building TF-A for trusty"

    mkdir -p $TRUSTY_SP_DIR
    # Copy sp layout and manifest files to TRUSTY_SP_DIR
    cp $TRUSTY_FILES/$PLATFORM/trusty_sp/* $TRUSTY_SP_DIR
    # copy lk.bin to TRUSTY_SP_DIR to be used by sp
    cp $TRUSTY_BIN/lk.bin $TRUSTY_SP_DIR/lk.bin

    pushd $TFA_SRC
    make "${make_opts[@]}" "${make_opts_trusty[@]}" all fip
    popd
}

do_clean() {
    pushd $TFA_SRC
    make "${make_opts[@]}" "${make_opts_trusty[@]}" clean
    popd
    rm -rf $TRUSTY_SP_DIR
}

do_deploy() {
    # Copy binaries to deploy directory
    cp $TRUSTY_OUTDIR/build/tc/debug/fip.bin $DEPLOY_DIR/$PLATFORM/fip-trusty-tc.bin
    cp $TRUSTY_OUTDIR/build/tc/debug/bl1.bin $DEPLOY_DIR/$PLATFORM/bl1-trusty-tc.bin
}

do_patch() {
    info_echo "Patching TF-A"
    PATCHES_DIR=$FILES_DIR/tfa/$PLATFORM/
    with_default_shell_opts patching $PATCHES_DIR $TFA_SRC
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
