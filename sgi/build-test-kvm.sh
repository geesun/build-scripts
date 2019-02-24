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

#List of supported
declare -A sgi_platforms
sgi_platforms[sgi575]=1
sgi_platforms[sgiclarka]=1

__print_supported_sgi_platforms()
{
	echo "Supported platforms are -"
	for plat in "${!sgi_platforms[@]}" ;
		do
			printf "\t $plat \n"
		done
	echo
}

__print_usage()
{
	echo "Usage: ./build-scripts/build-kvm.sh -p <platform> <command>"
	__print_supported_sgi_platforms
	echo "Supported build commands are - clean/build/package/all"
	echo
	exit
}

#callback from build-all.sh to override any build config
__do_override_build_configs()
{
	echo "build-kvm.sh: overriding BUILD_SCRIPTS"
	BUILD_SCRIPTS="build-arm-tf.sh build-linux.sh build-uefi.sh build-scp.sh build-target-bins.sh "
	echo "BUILD_SCRIPTS="$BUILD_SCRIPTS
}

parse_params() {
	#Parse the named parameters
	while getopts "p:" opt; do
		case $opt in
			p)
				SGI_PLATFORM="$OPTARG"
				;;
		esac
	done

	#The clean/build/package/all should be after the other options
	#So grab the parameters after the named param option index
	BUILD_CMD=${@:$OPTIND:1}

	#Ensure that the platform is supported
	if [ -z "$SGI_PLATFORM" ] ; then
		__print_usage
	fi
	if [ -z "${sgi_platforms[$SGI_PLATFORM]}" ] ; then
		echo "[ERROR] Could not deduce which platform to build."
		__print_supported_sgi_platforms
		exit
	fi

	#Ensure a build command is specified
	if [ -z "$BUILD_CMD" ] ; then
		__print_usage
	fi
}

#parse the command line parameters
parse_params $@

#override the command line parameters for build-all.sh
set -- "-p $SGI_PLATFORM -f busybox $BUILD_CMD"
source ./build-scripts/build-all.sh

#-----------------------------------------------------------------------------
# Copy the kernel image for SGI platforms into the pre-built fedora disk image
#-----------------------------------------------------------------------------

#variables for image generation
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
TOP_DIR=`pwd`
PLATDIR=${TOP_DIR}/output/$SGI_PLATFORM
PREBUILTS=${TOP_DIR}/prebuilts
OUTDIR=${PLATDIR}/components

update_kernel_image ()
{
	local disk_image="${PREBUILTS}/sgi/fedora.sgi.satadisk"
	local boot_part="${PREBUILTS}/sgi/fedora.sgi.satadisk2"
	local bootpart_image="boot.img"

	if [ ! -f $disk_image ] ; then
		echo -e "$RED_FONT Error: file $disk_image not found $NORMAL_FONT" >&2
		exit 1
	fi

	local boot_part_offset=$( fdisk -l $disk_image | grep ^$boot_part | awk -F" " '{ print $2 }' )
	local boot_part_size=$( fdisk -l $disk_image | grep ^$boot_part | awk -F" " '{ print $4 }' )

	mkdir -p mnt
	dd if=$disk_image of=$bootpart_image skip=$boot_part_offset count=$boot_part_size
	fuse-ext2 $bootpart_image mnt -o rw+
	cp $OUTDIR/linux/Image ./mnt/vmlinux-sgi
	sync
	fusermount -u mnt
	rm -rf mnt
	dd if=$bootpart_image of=$disk_image seek=$boot_part_offset count=$boot_part_size conv=notrunc,fsync
	rm -rf $bootpart_image
}

#prepare the disk image
if [ "$CMD" == "all" ] || [ "$CMD" == "package" ]; then
	update_kernel_image
fi
