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

do_configure() {
    source $TRUSTY_ENV/envsetup.sh
    export BUILDROOT=$TRUSTY_TOP/build-root
    export TARGET=tc-test-debug
    export HOST_FLAGS+=-Wno-error=deprecated-declarations
}

do_build() {
    info_echo "Building Trusty"
    do_configure
    cd $TRUSTY_TOP && nice make $TARGET
}

do_clean() {
    info_echo "Cleaning Trusty"
    do_configure
    make -C $TRUSTY_SRC $TARGET clean
    rm -rf $TRUSTY_OUTDIR
}

do_patch() {
    info_echo "Patching Trusty"
    PATCHES_DIR="$FILES_DIR/trusty/${PLATFORM}"

    FILES=(
    	    "$TRUSTY_DEV_FILES"
	    "$TRUSTY_LK_FILES"
	    "$TRUSTY_KERNEL_FILES"
	    "$TRUSTY_BASE_FILES"
	    "$TRUSTY_APP_FILES"
	    )

    for file in "${FILES[@]}"
        do
            with_default_shell_opts patching $PATCHES_DIR/$file $TRUSTY_SRC/$file
    done
}

do_deploy() {
    cp $TRUSTY_BIN/lk.bin $DEPLOY_DIR/$PLATFORM/lk.bin
    cp $TRUSTY_BIN/lk.elf $DEPLOY_DIR/$PLATFORM/lk.elf
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
