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
    info_echo "Building Hafnium"
    pushd $HAFNIUM_SRC
    mkdir -p $HAFNIUM_OUTDIR
    export PATH=$HAFNIUM_SRC/prebuilts/linux-x64/clang/bin/:$PATH
    make OUT_DIR=$HAFNIUM_OUTDIR PROJECT="reference"
    popd
}

do_clean() {
    info_echo "Cleaning Hafnium"
    export PATH=$HAFNIUM_SRC/prebuilts/linux-x64/clang/bin/:$PATH
    pushd $HAFNIUM_SRC
    make clobber
    popd
    rm -rf $HAFNIUM_OUTDIR
}

do_deploy() {
    ln -s $HAFNIUM_OUTDIR/secure_tc_clang/hafnium.bin $DEPLOY_DIR/$PLATFORM 2>/dev/null || :
    ln -s $HAFNIUM_OUTDIR/secure_tc_clang/hafnium.elf $DEPLOY_DIR/$PLATFORM 2>/dev/null || :
}

do_patch() {
    info_echo "Patching Hafnium"
    PATCHES_DIR=$FILES_DIR/hafnium/$PLATFORM/
    with_default_shell_opts patching $PATCHES_DIR $HAFNIUM_SRC

    cd $HAFNIUM_SRC/project/reference && \
    with_default_shell_opts patching $PATCHES_DIR/project/reference $HAFNIUM_SRC/project/reference
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
