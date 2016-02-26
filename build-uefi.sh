#!/usr/bin/env bash

# Copyright (c) 2015, ARM Limited and Contributors. All rights reserved.
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

#
# This script uses the following environment variables from the variant
#
# VARIANT - build variant name
# TOP_DIR - workspace root directory
# CROSS_COMPILE - PATH to GCC including CROSS-COMPILE prefix
# PARALLELISM - number of cores to build across
# UEFI_BUILD_ENABLED - Flag to enable building UEFI
# UEFI_PATH - sub-directory containing UEFI code
# UEFI_PLATFORMS - List of platform Makefiles to run
# UEFI_BUILD_MODE - DEBUG or RELEASE
# UEFI_TOOLCHAIN - supported Toolchain, eg: GCC49, GCC48 or GCC47
# UEFI_OUTPUT_PLATFORMS - list of outputs to export
# UEFI_BINARY - the filename of the UEFI binary 
do_build ()
{
	if [ "$UEFI_BUILD_ENABLED" == "1" ]; then
		pushd $TOP_DIR/$UEFI_ACPICA_PATH
		make iasl
		popd
		pushd $TOP_DIR/$UEFI_PATH
		for item in $UEFI_PLATFORMS; do
			IASL_PREFIX=${TOP_DIR}/${UEFI_ACPICA_PATH}/bin/ ${TOP_DIR}/${UEFI_TOOLS_PATH}/uefi-build.sh -b $UEFI_BUILD_MODE -D EDK_OUT_DIR=$UEFI_OUTPUT_PLATFORMS $item
		done
		popd
	fi
}

do_clean ()
{
	if [ "$UEFI_BUILD_ENABLED" == "1" ]; then
		pushd $TOP_DIR/$UEFI_PATH
		source ./edksetup.sh
		make -C BaseTools clean
		export EDK2_TOOLCHAIN=$UEFI_TOOLCHAIN
		export ${UEFI_TOOLCHAIN}_AARCH64_PREFIX=$CROSS_COMPILE
		export EDK2_MACROS="-n $PARALLELISM"
		for item in $UEFI_PLATFORMS; do
			rm -rf Build/$UEFI_OUTPUT_PLATFORMS
		done
		rm -rf Build
		popd
		pushd $TOP_DIR/$UEFI_ACPICA_PATH
		make veryclean
		popd
	fi
}

do_package ()
{
	if [ "$UEFI_BUILD_ENABLED" == "1" ]; then
		echo "Packaging uefi... $VARIANT";
		# Copy binaries to output folder
		pushd $TOP_DIR
		for item in $UEFI_OUTPUT_PLATFORMS; do
			mkdir -p ${OUTDIR}/${UEFI_OUTPUT_DESTS[$item]}
			cp ./$UEFI_PATH/Build/$item/${UEFI_BUILD_MODE}_${UEFI_TOOLCHAIN}/FV/${UEFI_BINARY} \
				${OUTDIR}/${UEFI_OUTPUT_DESTS[$item]}/uefi.bin
		done
		popd

	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $1 $2
