#!/usr/bin/env bash

# Copyright (c) 2019, ARM Limited and Contributors. All rights reserved.
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

do_build()
{
	pushd $TOP_DIR/uefi
	if [[ ! -e ./edk2-test ]] ; then
		git clone https://github.com/tianocore/edk2-test.git
	fi
	if [[ ! -e ./SctPkg ]] ; then
		ln -s edk2-test/uefi-sct/SctPkg SctPkg
	fi
	echo Building UEFI SCT...
	./SctPkg/build.sh AARCH64 GCC $SCT_BUILD_MODE
	popd
}

do_package()
{
	mkdir -p $SCT_OUT_DIR
	cp -rf $TOP_DIR/uefi/Build/UefiSct/DEBUG_GCC5/SctPackageAARCH64 $SCT_OUT_DIR
}

do_clean()
{
	rm -rf $SCT_OUT_DIR
	rm -rf $TOP_DIR/uefi/Build/*Sct
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $@
