#!/usr/bin/env bash

# Copyright (c) 2021, ARM Limited and Contributors. All rights reserved.
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

source ./build-scripts/sgi/sgi_common_util.sh

TOP_DIR=`pwd`

# List of all the supported platforms.
declare -A platforms_rdinfra
platforms_rdinfra[rdv1]=1

__print_examples()
{
	echo "Example 1: ./build-scripts/$refinfra/build-test-linuxboot.sh -p $1 all"
	echo "   This command builds the software stack for $1 platform and prepares a"
	echo "   disk image to boot upto u-root filesystem and then boots the stage-2"
	echo "   linux kernel with a busybox prompt"
	echo
	echo "Example 2: ./build-scripts/$refinfra/build-test-linuxboot.sh -p $1 build"
	echo "   This command builds the $1 platform software stack for linuxboot"
}

__print_usage()
{
	echo
	echo "Usage: ./build-scripts/$refinfra/build-test-linuxboot.sh -p <platform> <command>"
	echo
	echo "build-test-linuxboot.sh: Builds the platform software stack required for testing"
	echo "Linuxboot. Builds stage-1 linuxboot kernel with an embedded uroot userspace and "
	echo "stage-2 linux kernel with busybox ramdisk. The stage-2 linux kernel and the ramdisk"
	echo "are placed in a disk image which is then attached to the FVP Model as a satadisk."
	echo
	__print_supported_platforms_$refinfra
	echo "Supported build commands are - clean/build/package/all"
	echo
	__print_examples_$refinfra
	echo
	exit 1
}

parse_params()
{
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

	__parse_params_validate
}

# Go Version to download
VERSION=1.16.5
# Host OS
OS=linux
# Host Architecture
ARCH=amd64

# Path to directory where GO source files will be extracted
GO_INSTALL_PATH=${TOP_DIR}/tools/go/go_source
# Output path for u-root initramfs creation

INITRAMFS_OUTPUT_PATH=${TOP_DIR}/tools/go/output/u-root.initramfs.linux_arm64.cpio

# Path to directory where u-root package for go  will be downloaded and installed
# This is different from $GO_INSTALL_PATH
GO_PATH=${TOP_DIR}/tools/go/go_workspace

# Set GOPATH for u-root
export GOPATH=$GO_PATH

#---------------------------------
# Download and install Go & u-root
#---------------------------------
setup_go_and_uroot()
{
	# Download Go
	echo "Downloading Go..."
	echo
	wget -nc https://golang.org/dl/go$VERSION.$OS-$ARCH.tar.gz -P ${TOP_DIR}/tools/go/

	# Extract Go
	mkdir -p $GO_INSTALL_PATH
	tar -C $GO_INSTALL_PATH -xzf ${TOP_DIR}/tools/go/go$VERSION.$OS-$ARCH.tar.gz

	# Add go/bin to $PATH if not present already
	[[ ":$PATH:" != *":$GO_INSTALL_PATH/go/bin:"* ]] && PATH="${PATH}:$GO_INSTALL_PATH/go/bin"

	export GO111MODULE=off

	echo
	echo "Downloading u-root..."
	echo
	go get github.com/u-root/u-root

	echo "Go and u-root setup complete!"
}

#--------------------------------------------
# Build u-root initramfs for linuxboot kernel
#--------------------------------------------
build_uroot()
{
	export GO111MODULE=off

	echo "-------------------------"
	echo "Building u-root initramfs"
	echo "-------------------------"

	mkdir $TOP_DIR/tools/go/output
	export GOARCH=arm64

	${GOPATH}/bin/u-root -files "build-scripts/scripts/linuxboot-uroot-automation.sh:/linuxboot-uroot-automation.sh" -uinitcmd="/bin/sh /linuxboot-uroot-automation.sh" -o $INITRAMFS_OUTPUT_PATH

	echo "u-root initramfs created at $INITRAMFS_OUTPUT_PATH"
}

#parse the command line parameters
parse_params $@

#---------------------------------------
# Clean the uroot & stage-1 linux kernel
#---------------------------------------
if [[ $BUILD_CMD == "clean" ]] || [[ $BUILD_CMD == "all"  ]]
then
	if [[ -d $TOP_DIR/tools/go/output/ ]]
	then
		echo "----------------------------"
		echo " Cleaning uroot initramfs   "
		echo "----------------------------"
		rm -rf "$TOP_DIR/tools/go/output"
	fi

	if [[ -d ${TOP_DIR}/linux/out/${SGI_PLATFORM}/linuxboot_defconfig ]]
	then
		echo "-------------------------------------"
		echo " Cleaning stage-1 linuxboot kernel   "
		echo "-------------------------------------"
		rm -rf ${TOP_DIR}/linux/out/${SGI_PLATFORM}/linuxboot_defconfig
	fi

	if [[ -d ${TOP_DIR}/uefi/edk2/edk2-platforms/Platform/ARM/SgiPkg/LinuxBootPkg/AArch64/ ]]
	then
		rm -rf ${TOP_DIR}/uefi/edk2/edk2-platforms/Platform/ARM/SgiPkg/LinuxBootPkg/AArch64/
	fi
fi

#---------------------------------
# Build stage-1 linux kernel image
#---------------------------------
if [[ $BUILD_CMD == "build" ]] || [[ $BUILD_CMD == "all" ]]
then
	# Check if tools/go exists, if not, install go and u-root
	if [ ! -d "${TOP_DIR}/tools/go" ]
	then
		# call the install_root function to download and install u-root
		setup_go_and_uroot
	fi

	# check if u-root initramfs is built already
	if [ ! -d  "$TOP_DIR/tools/go/output" ]
	then
		# build uroot initramfs
		build_uroot
	fi

	echo "-------------------------------------------"
	echo "Building linuxboot stage-1 linux kernel...."
	echo "-------------------------------------------"
	# Build the linuxboot kernel
	# override the command line parameters for build-linux.sh
	set -- "-p $SGI_PLATFORM -f linuxboot build"
	source ./build-scripts/build-linux.sh

	echo "-----------------------------------------------------"
	echo "Copying stage-1 linux kernel to LinuxBootPkg/AArch64 "
	echo "-----------------------------------------------------"

	# create SgiPkg/LinuxBootPkg/AArch64 directory
	if [[ ! -d ${TOP_DIR}/uefi/edk2/edk2-platforms/Platform/ARM/SgiPkg/LinuxBootPkg/AArch64/ ]]
	then
		mkdir ${TOP_DIR}/uefi/edk2/edk2-platforms/Platform/ARM/SgiPkg/LinuxBootPkg/AArch64/
	fi

	# Copy the stage-1 linux kernel image to SgiPkg/LinuxBootPkg/AArch64
	cp ${TOP_DIR}/linux/out/${SGI_PLATFORM}/linuxboot_defconfig/arch/arm64/boot/Image ${TOP_DIR}/uefi/edk2/edk2-platforms/Platform/ARM/SgiPkg/LinuxBootPkg/AArch64/
fi

__do_override_build_configs()
{
	echo "build-test-linuxboot.sh: adding UEFI_EXTRA_BUILD_PARAMS build configuration"
	export UEFI_EXTRA_BUILD_PARAMS="-D LINUXBOOT_BUILD_ENABLED=TRUE"
	echo $UEFI_EXTRA_BUILD_PARAMS
}

#------------------------------
# Build Platform software stack
#------------------------------
# override the command line parameters for build-linux.sh
set -- "-p $SGI_PLATFORM -f busybox $BUILD_CMD"
export LINUXBOOT_BUILD_ENABLED=TRUE
source ./build-scripts/build-all.sh

# variables for image generation
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
TOP_DIR=`pwd`
PLATDIR=${TOP_DIR}/output/$SGI_PLATFORM
OUTDIR=${PLATDIR}/components
BLOCK_SIZE=10M
BLOCK_COUNT=5
DISK_IMAGE_NAME="linuxboot-stage-2-disk.img"

#-----------------------------------------------------------------------------
# Function to create test disk image containing stage-2 linux kernel image and
# an Initrd
#-----------------------------------------------------------------------------
create_disk_image ()
{
	dd if=/dev/zero of=$DISK_IMAGE_NAME  bs=$BLOCK_SIZE count=$BLOCK_COUNT
	mkdir -p mnt
	# use randomly generated UUID
	EXT3PART_UUID=$(uuidgen)

	# umount if it has been mounted
	if [[ $(findmnt -M "mnt") ]]; then
		fusermount -u mnt
	fi
	# mkfs.ext3 -F $DISK_IMAGE_NAME
	mkfs -t ext3 $DISK_IMAGE_NAME
	tune2fs -U $EXT3PART_UUID $DISK_IMAGE_NAME

	fuse-ext2 $DISK_IMAGE_NAME mnt -o rw+

	# copy the stage-2 linux kernel image and initrd
	cp $OUTDIR/linux/Image ./mnt
	cp $PLATDIR/ramdisk-busybox.img ./mnt
	sync
	fusermount -u mnt
	rm -rf mnt
	echo "$DISK_IMAGE_NAME disk image created"
	mv ${DISK_IMAGE_NAME} ./output/$SGI_PLATFORM
}

if [ "$BUILD_CMD" == "all" ] || [ "$BUILD_CMD" == "package" ]; then
	#create the disk image
	create_disk_image
fi
