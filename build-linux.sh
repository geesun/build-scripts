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
# LINUX_BUILD_ENABLED - Flag to enable building Linux
# LINUX_PATH - sub-directory containing Linux code
# LINUX_ARCH - Build architecture (arm64)
# LINUX_DEFCONFIG - Single Linux defconfig to build. Ignored if LINUX_CONFIGS set
# LINUX_CONFIGS - List of Linaro config fragments to use to build
# TARGET_BINS_PLATS - the platforms to create binaries for
# TARGET_{plat} - array of platform parameters, indexed by
#	fdts - the fdt pattern used by the platform
# UBOOT_UIMAGE_ADDRS - address at which to link UBOOT image
# UBOOT_MKIMAGE - path to uboot mkimage
# LINUX_ARCH - the arch
# UBOOT_BUILD_ENABLED - flag to indicate the need for uimages.
#
# LINUX_IMAGE_TYPE - Image or zImage (Image is the default if not specified)

LINUX_IMAGE_TYPE=${LINUX_IMAGE_TYPE:-Image}

do_build ()
{
	if [ "$LINUX_BUILD_ENABLED" == "1" ]; then
		export ARCH=$LINUX_ARCH

		pushd $TOP_DIR/$LINUX_PATH
		if [ "$LINUX_CONFIGS" != "" ] && [ -d "linaro/configs" ]; then
			echo "Building using config fragments..."
			CONFIG=""
			for config in $LINUX_CONFIGS; do
				CONFIG=$CONFIG"linaro/configs/${config}.conf "
			done
			mkdir -p $LINUX_OUT_DIR
			scripts/kconfig/merge_config.sh -O $LINUX_OUT_DIR $CONFIG
		else
			echo "Building using defconfig..."
			make O=$LINUX_OUT_DIR $LINUX_DEFCONFIG
		fi
		make O=$LINUX_OUT_DIR -j$PARALLELISM $LINUX_IMAGE_TYPE dtbs
		popd
	fi
}

do_clean ()
{
	if [ "$LINUX_BUILD_ENABLED" == "1" ]; then
		export ARCH=$LINUX_ARCH

		pushd $TOP_DIR/$LINUX_PATH

		make O=$LINUX_OUT_DIR distclean
		popd
	fi
}

do_package ()
{
	if [ "$LINUX_BUILD_ENABLED" == "1" ]; then
		echo "Packaging Linux... $VARIANT";
		# Copy binary to output folder
		pushd $TOP_DIR
		mkdir -p ${OUTDIR}/$LINUX_PATH/

		for plat in $TARGET_BINS_PLATS; do
			local fd=TARGET_$plat[fdts]
			for target in ${!fd}; do
				for item in $target; do
					discoveredDTB=$(find $LINUX_PATH/$LINUX_OUT_DIR/arch/$LINUX_ARCH/boot/dts/ -name ${item}.dtb)
					if [ "${discoveredDTB}" = "" ]; then
						echo "skipping dtb $item"
					else
						cp ${discoveredDTB} ${OUTDIR}/$LINUX_PATH/.
					fi
				done
			done
		done

		cp $LINUX_PATH/$LINUX_OUT_DIR/arch/$LINUX_ARCH/boot/$LINUX_IMAGE_TYPE ${OUTDIR}/$LINUX_PATH/.
		popd
		if [ "$UBOOT_BUILD_ENABLED" == "1" ]; then
			pushd ${OUTDIR}/$LINUX_PATH/
			for addr in $UBOOT_UIMAGE_ADDRS; do
				${UBOOT_MKIMG} -A $LINUX_ARCH -O linux -C none \
					-T kernel -n Linux \
					-a $addr -e $addr \
					-n "Linux" -d $LINUX_IMAGE_TYPE uImage.$addr
			done
			popd
		fi
	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $1 $2
