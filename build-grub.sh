#!/usr/bin/env bash

# Copyright (c) 2017, ARM Limited and Contributors. All rights reserved.
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
# PLATDIR - Platform Output directory
# GRUB_PATH - path to GRUB source
# CROSS_COMPILE - PATH to GCC including CROSS-COMPILE prefix
# PARALLELISM - number of cores to build across
# GRUB_BUILD_ENABLED - Flag to enable building Linux
# BUSYBOX_BUILD_ENABLED - Building Busybox
# OE_RAMDISK_BUILD_ENABLED - Building OE
#

do_build ()
{
	if [ "$GRUB_BUILD_ENABLED" == "1" ]; then
		if [ -d $TOP_DIR/$GRUB_PATH ]; then
			pushd $TOP_DIR/$GRUB_PATH
			CROSS_COMPILE_DIR=$(dirname $CROSS_COMPILE)
	                PATH="$PATH:$CROSS_COMPILE_DIR"
			mkdir -p $TOP_DIR/$GRUB_PATH/output
			# On the master branch of grub, commit '35b90906' ("gnulib: Upgrade Gnulib and switch to bootstrap tool")
			# required the bootstrap tool to be executed before the configure step.
			if [ -e bootstrap ]; then
				if [ ! -e grub-core/lib/gnulib/stdlib.in.h ]; then
					./bootstrap
				fi
			fi
			if [ ! -e config.status ]; then
				./autogen.sh
				./configure STRIP=$CROSS_COMPILE_DIR/aarch64-none-linux-gnu-strip --target=aarch64-none-linux-gnu --with-platform=efi --prefix=$TOP_DIR/$GRUB_PATH/output/ --disable-werror
			fi
			make -j $PARALLELISM install
			output/bin/grub-mkimage -v -c ${GRUB_PLAT_CONFIG_FILE} -o output/grubaa64.efi -O arm64-efi -p "" part_gpt part_msdos ntfs ntfscomp hfsplus fat ext2 normal chain boot configfile linux help part_msdos terminal terminfo configfile lsefi search normal gettext loadenv read search_fs_file search_fs_uuid search_label
		fi
	fi
}

do_clean ()
{
	if [ "$GRUB_BUILD_ENABLED" == "1" ]; then
		if [ -d $TOP_DIR/$GRUB_PATH ]; then
                        pushd $TOP_DIR/$GRUB_PATH
			rm -rf output
			git clean -fdX
		fi
	fi
}
do_package ()
{
	:
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $@

