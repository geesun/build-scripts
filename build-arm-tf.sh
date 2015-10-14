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
# ARM_TF_BUILD_ENABLED - Flag to enable building ARM Trusted Firmware
# ARM_TF_PATH - sub-directory containing ARM Trusted Firmware code
# ARM_TF_PLATS - List of platforms to be built (from available in arm-tf/plat)
# ARM_TF_DEBUG_ENABLED - 1 = debug, 0 = release build
# ARM_TF_BUILD_FLAGS - Additional build flags to pass on the build command line
#

do_build ()
{
	if [ "$ARM_TF_BUILD_ENABLED" == "1" ]; then
		#if trusted board boot(TBBR) enabled, set corresponding compiliation flags
		if [ "$ARM_TBBR_ENABLED" == "1" ]; then
			ARM_TF_BUILD_FLAGS="$ARM_TF_BUILD_FLAGS $ARM_TF_TBBR_BUILD_FLAGS"
		fi
		pushd $TOP_DIR/$ARM_TF_PATH
		for plat in $ARM_TF_PLATS; do
			local build_cmd="make -j $PARALLELISM PLAT=$plat DEBUG=$ARM_TF_DEBUG_ENABLED $ARM_TF_BUILD_FLAGS all"
			echo $build_cmd
			$build_cmd
		done

		# tool to create certificates
		if [ "$ARM_TBBR_ENABLED" == "1" ]; then
			make certtool
		fi

		make fiptool
		popd
	fi
}

do_clean ()
{
	if [ "$ARM_TF_BUILD_ENABLED" == "1" ]; then
		pushd $TOP_DIR/$ARM_TF_PATH

		for plat in $ARM_TF_PLATS; do
			make PLAT=$plat DEBUG=$ARM_TF_DEBUG_ENABLED clean
		done
		make -C tools/fip_create clean
		popd
	fi
}

do_package ()
{
	if [ "$ARM_TF_BUILD_ENABLED" == "1" ]; then
		echo "Packaging arm-tf... $VARIANT";
		# Copy binaries to output folder
		pushd $TOP_DIR
		for plat in $ARM_TF_PLATS; do
			mkdir -p ${OUTDIR}/$plat
			local mode=release
			[ "$ARM_TF_DEBUG_ENABLED" == "1" ] && mode=debug
			for bin in $TOP_DIR/$ARM_TF_PATH/build/$plat/${mode}/bl*.bin; do
				cp ${bin} ${OUTDIR}/$plat/tf-$(basename ${bin})
			done
		done
		popd
	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $1 $2
