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
# LINUX_COMPILER - PATH to GCC including CROSS-COMPILE prefix
# PARALLELISM - number of cores to build across
# LINUX_BUILD_ENABLED - Flag to enable building Linux
# LINUX_PATH - sub-directory containing Linux code
# LINUX_ARCH - Build architecture (arm64)
# LINUX_DEFCONFIG - Single Linux defconfig to build. Ignored if LINUX_CONFIGS set
# LINUX_CONFIGS - List of Linaro config fragments to use to build

do_build ()
{
	if [ "$LINUX_BUILD_ENABLED" == "1" ]; then
		export CROSS_COMPILE=$TOP_DIR/$LINUX_COMPILER
		export ARCH=$LINUX_ARCH

		pushd $TOP_DIR/$LINUX_PATH
		if [ "$LINUX_CONFIGS" != "" ] && [ -d "linaro/configs" ]; then
			echo "Building using config fragments..."
			CONFIG=""
			for config in $LINUX_CONFIGS; do
				CONFIG=$CONFIG"linaro/configs/${config}.conf "
			done
			scripts/kconfig/merge_config.sh $CONFIG
		else
			echo "Building using defconfig..."
			make $LINUX_DEFCONFIG
		fi
		make -j$PARALLELISM Image dtbs
		popd
	fi
}

do_clean ()
{
	if [ "$LINUX_BUILD_ENABLED" == "1" ]; then
		export CROSS_COMPILE=$TOP_DIR/$LINUX_COMPILER
		export ARCH=$LINUX_ARCH

		pushd $TOP_DIR/$LINUX_PATH

		make distclean
		popd
	fi
}

do_package ()
{
	if [ "$LINUX_BUILD_ENABLED" == "1" ]; then
		echo "Packaging Linux... $VARIANT";
		# Copy binary to output folder
		pushd $TOP_DIR
		mkdir -p ${OUTDIR}/$LINUX_PATH
		cp $LINUX_PATH/arch/$LINUX_ARCH/boot/Image ${OUTDIR}/$LINUX_PATH/.
		popd
	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $1 $2
