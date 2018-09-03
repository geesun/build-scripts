#!/usr/bin/env bash

# Copyright (c) 2018, ARM Limited and Contributors. All rights reserved.
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

__print_supported_sgi_platforms()
{
	echo "Supported platforms are -"
	for plat in "${!sgi_platforms[@]}" ;
		do
			printf "\t $plat\n"
		done
	echo
}

__print_usage()
{
	echo "Usage: ./build-scripts/build-sgiboot.sh -p <platform> <command>"
	echo
	echo "build-sgiboot.sh: Builds the disk image for busybox boot. The disk image consists of"
	echo "a EFI paritition with grub in it and a ext3 paritition with linux kernel image it it."
	echo
	__print_supported_sgi_platforms
	echo "Supported build commands are - clean/build/package/all"
	echo
	echo "Example 1: ./build-scripts/build-sgiboot.sh -p sgi575 all"
	echo "   This command builds the software stack for sgi575 platform and prepares a disk"
	echo "   image to boot upto busybox filesystem"
	echo
	echo "Example 2: ./build-scripts/build-sgiboot.sh -p sgi575 clean"
	echo "   This command cleans the previous build of the sgi575 platform software stack"
	echo
	exit
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

#------------------------------------------
# Generate the disk image for busybox boot
#------------------------------------------

#variables for image generation
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
TOP_DIR=`pwd`
PLATDIR=${TOP_DIR}/output/$SGI_PLATFORM
OUTDIR=${PLATDIR}/components
GRUB_FS_CONFIG_FILE=${TOP_DIR}/build-scripts/platforms/sgi575/grub_config/busybox.cfg
GRUB_FS_VALIDATION_CONFIG_FILE=${TOP_DIR}/build-scripts/platforms/sgi575/grub_config/busybox-dhcp.cfg

create_cfgfiles ()
{
	local fatpart_name="$1"

	if [ "$VALIDATION_LVL" == 1 ]; then
		mcopy -i  $fatpart_name -o ${GRUB_FS_CONFIG_FILE} ::/grub/grub.cfg
	else
		mcopy -i $fatpart_name -o ${GRUB_FS_VALIDATION_CONFIG_FILE} ::/grub/grub.cfg
	fi
}

create_fatpart ()
{
	local fatpart="$1"

	dd if=/dev/zero of=$fatpart bs=$BLOCK_SIZE count=$FAT_SIZE
	mkfs.vfat $fatpart
	mmd -i $fatpart ::/EFI
	mmd -i $fatpart ::/EFI/BOOT
	mmd -i $fatpart ::/grub
	mcopy -i $fatpart bootaa64.efi ::/EFI/BOOT
}

create_imagepart ()
{
	local image_name="$1"
	local image_size="$2"
	local ext3part_name="$3"

	cat fat_part >> $image_name
	cat $ext3part_name >> $image_name
	(echo n; echo p; echo 1; echo $PART_START; echo +$((FAT_SIZE-1)); echo t; echo 6; echo n; echo p; echo 2; echo $((PART_START+FAT_SIZE)); echo +$(($image_size-1)); echo w) | fdisk $image_name
	cp $image_name $PLATDIR
}

create_ext3part ()
{
	local ext3part_name="$1"
	local ext3size=$2
	local rootfs_file=$3

	echo "create_ext3part: ext3part_name = $ext3part_name ext3size = $ext3size rootfs_file = $rootfs_file"
	dd if=/dev/zero of=$ext3part_name bs=$BLOCK_SIZE count=$ext3size
	mkdir -p mnt
	#umount if it has been mounted
	if [[ $(findmnt -M "mnt") ]]; then
		fusermount -u mnt
	fi
	mkfs.ext3 -F $ext3part_name
	fuse-ext2 $ext3part_name mnt -o rw+
	cp $OUTDIR/linux/Image ./mnt
	cp $PLATDIR/ramdisk-busybox.img ./mnt
	sync
	fusermount -u mnt
	rm -rf mnt
}

prepare_disk_image ()
{
	echo
	echo
	echo "-------------------------------------"
	echo "Preparing disk image for busybox boot"
	echo "-------------------------------------"

	pushd $TOP_DIR/$GRUB_PATH/output
	local IMG_BB=grub-busybox.img
	local BLOCK_SIZE=512
	local SEC_PER_MB=$((1024*2))
	#FAT Partition size of 20MB and EXT3 Partition size 200MB
	local FAT_SIZE_MB=20
	local EXT3_SIZE_MB=200
	local PART_START=$((1*SEC_PER_MB))
	local FAT_SIZE=$((FAT_SIZE_MB*SEC_PER_MB-(PART_START)))
	local EXT3_SIZE=$((EXT3_SIZE_MB*SEC_PER_MB-(PART_START)))

	cp grubaa64.efi bootaa64.efi
	grep -q -F 'mtools_skip_check=1' ~/.mtoolsrc || echo "mtools_skip_check=1" >> ~/.mtoolsrc
	#Create fat partition
	create_fatpart "fat_part"

	#Package images for Busybox
	rm -f $IMG_BB
	dd if=/dev/zero of=$IMG_BB bs=$BLOCK_SIZE count=$PART_START
	create_cfgfiles "fat_part" "busybox"
	#Create ext3 partition
	create_ext3part "ext3_part" $EXT3_SIZE ""
	# create image and copy into output folder
	create_imagepart $IMG_BB $EXT3_SIZE "ext3_part"

	#remove intermediate files
	rm -f fat_part
	rm -f ext3_part

	echo "Completed preparation of disk image for busybox boot"
	echo "----------------------------------------------------"
}

if [ "$CMD" == "all" ] || [ "$CMD" == "package" ]; then
	#prepare the disk image
	prepare_disk_image
fi