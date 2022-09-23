#!/usr/bin/env bash

# Copyright (c) 2021-2022, ARM Limited and Contributors. All rights reserved.
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
# BUILDROOT_BUILD_ENABLED - Flag to enable building Buildroot
# BUILDROOT_PATH - sub-directory containing Buildroot code
# BUILDROOT_ARCH - Build architecture (arm)
# BUILDROOT_RAMDISK_PATH - path to where we build the ramdisk
# BUILDROOT_RAMDISK_BUILDROOT_PATH - path to the BB binary
# TARGET_BINS_PLATS - the platforms to create binaries for
# TARGET_{plat} - array of platform parameters, indexed by
# 	ramdisk - the address of the ramdisk per platform

do_build ()
{
	if [ "$BUILDROOT_BUILD_ENABLED" == "1" ]; then
		export ARCH=$BUILDROOT_ARCH

		pushd "$DIR/configs/$PLATFORM/buildroot"
		cp $BUILDROOT_DEFCONFIG $TOP_DIR/$BUILDROOT_PATH/configs/

		ARCH_VERSION=$(uname -m)

		# if the host build machine is x86_64, pick up the config
		# framgment specific to x86_64.
		if [ "$ARCH_VERSION" ==  "x86_64" ] && [ ! -z "$BUILDROOT_X86_64_HOST_CONFIG" ] ; then
			cp $BUILDROOT_X86_64_HOST_CONFIG $TOP_DIR/$BUILDROOT_PATH/configs/
		fi

		# if the host build machine is aarch64, pick up the config
		# framgment specific to aarch64.
		if [ "$ARCH_VERSION" ==  "aarch64" ] && [ ! -z "$BUILDROOT_AARCH64_HOST_CONFIG" ] ; then
			cp $BUILDROOT_AARCH64_HOST_CONFIG $TOP_DIR/$BUILDROOT_PATH/configs/
		fi
		popd

		pushd $TOP_DIR/$BUILDROOT_PATH
		mkdir -p $BUILDROOT_OUT_DIR

		# if the host build machine is x86_64, merge the x86 config with
		# the default config
		if [ "$ARCH_VERSION" ==  "x86_64" ] && [ ! -z "$BUILDROOT_X86_64_HOST_CONFIG" ] ; then
			./support/kconfig/merge_config.sh -m configs/$BUILDROOT_DEFCONFIG configs/$BUILDROOT_X86_64_HOST_CONFIG
			mv .config configs/$BUILDROOT_DEFCONFIG
			rm configs/$BUILDROOT_X86_64_HOST_CONFIG # not required anymore
		fi

		# if the host build machine is aarch64, merge the aarch64 config
		# with the default config
		if [ "$ARCH_VERSION" ==  "aarch64" ] && [ ! -z "$BUILDROOT_AARCH64_HOST_CONFIG" ] ; then
			./support/kconfig/merge_config.sh -m configs/$BUILDROOT_DEFCONFIG configs/$BUILDROOT_AARCH64_HOST_CONFIG
			mv .config configs/$BUILDROOT_DEFCONFIG
			rm configs/$BUILDROOT_AARCH64_HOST_CONFIG # not required anymore
		fi

		make O=$BUILDROOT_OUT_DIR $BUILDROOT_DEFCONFIG
		make O=$BUILDROOT_OUT_DIR -j $PARALLELISM
		rm configs/$BUILDROOT_DEFCONFIG
		popd
	fi
}

do_clean ()
{
	if [ "$BUILDROOT_BUILD_ENABLED" == "1" ]; then
		export ARCH=$BUILDROOT_ARCH

		pushd $TOP_DIR/$BUILDROOT_PATH
		mkdir -p $BUILDROOT_OUT_DIR
		make O=$BUILDROOT_OUT_DIR clean
		popd
		pushd $TOP_DIR/$BUILDROOT_RAMDISK_PATH
		rm -f ramdisk-bl.img
		popd
	fi
}

do_package ()
{
	if [ "$BUILDROOT_BUILD_ENABLED" == "1" ]; then
		echo "Packaging BUILDROOT... $VARIANT";
		# create the ramdisk
		pushd $TOP_DIR/$BUILDROOT_RAMDISK_PATH
		cp $TOP_DIR/$BUILDROOT_RAMDISK_BUILDROOT_PATH/rootfs.cpio ./ramdisk-bl.img
		popd
		# Copy binary to output folder
		pushd $TOP_DIR
		mkdir -p ${OUTDIR}
		cp $BUILDROOT_RAMDISK_PATH/ramdisk-bl.img \
			${PLATDIR}/ramdisk-buildroot.img
		# delete temp files
		rm -f $BUILDROOT_RAMDISK_PATH/ramdisk-bl.img

		popd
		if [ "$UBOOT_BUILD_ENABLED" == "1" ]; then
			pushd ${PLATDIR}
			for target in $TARGET_BINS_PLATS; do
				local addr=TARGET_$target[ramdisk]
				${UBOOT_MKIMG} -A $BUILDROOT_ARCH -O linux -C none \
					-T ramdisk -n ramdisk \
					-a ${!addr} -e ${!addr} \
					-n "Buildroot ramdisk" \
					-d ramdisk-buildroot.img \
					uInitrd-buildroot.${!addr}
			done
			popd
		fi
	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $@
