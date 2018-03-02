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
			if [ ! -e config.status ]; then
				./autogen.sh
				./configure STRIP=$CROSS_COMPILE_DIR/aarch64-linux-gnu-strip --target=aarch64-linux-gnu --with-platform=efi --prefix=$TOP_DIR/$GRUB_PATH/output/ --disable-werror
			fi
			make -j8 install
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
create_cfgfiles ()
{
	local fatpart_name="$1"
	local cfgname="$2"
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
	sync
	if [ "$BUSYBOX_BUILD_ENABLED" != "1" ]; then
		if [ -d $TOP_DIR/prebuilts/oe ]; then
			mkdir -p $TOP_DIR/prebuilts/oe/oe-rootfs
			tar -zxvf $TOP_DIR/prebuilts/oe/$rootfs_file -C $TOP_DIR/prebuilts/oe/oe-rootfs
			chmod -R 750 $TOP_DIR/prebuilts/oe/oe-rootfs
			cp -r $TOP_DIR/prebuilts/oe/oe-rootfs/* ./mnt
			cp $PLATDIR/ramdisk-oe.img ./mnt
			rm -rf $TOP_DIR/prebuilts/oe/oe-rootfs
		else
			echo ===============================================================
			echo WARNING: OE RootFS not present, run ./prebuilts/get-binaries.sh
			echo ===============================================================
		fi
	else
		cp $PLATDIR/ramdisk-busybox.img ./mnt
	fi
	fusermount -u mnt
	rm -rf mnt
}
do_package ()
{
	if [ "$GRUB_BUILD_ENABLED" == "1" ]; then
		if [ -d $TOP_DIR/$GRUB_PATH ]; then
			pushd $TOP_DIR/$GRUB_PATH/output
			local IMG_BB=grub-busybox.img
			local IMG_OE=grub-oe.img
			local IMG_OE_SATA=grub-oe-sata.img
			local IMG_LAMP=grub-oe-lamp.img
			local IMG_LAMP_RAS=grub-oe-lamp-ras.img
			local IMG_LAMP_SATA=grub-oe-lamp-sata.img
			local BLOCK_SIZE=512
			local SEC_PER_MB=$((1024*2))
			#FAT Partition size of 20MB and EXT3 Partition size 200MB
			local FAT_SIZE_MB=20
			local EXT3_SIZE_MB=200
			local EXT3_LAMP_SIZE_MB=2500
			local PART_START=$((1*SEC_PER_MB))
			local FAT_SIZE=$((FAT_SIZE_MB*SEC_PER_MB-(PART_START)))
			local EXT3_SIZE=$((EXT3_SIZE_MB*SEC_PER_MB-(PART_START)))
			local EXT3_LAMP_SIZE=$((EXT3_LAMP_SIZE_MB*SEC_PER_MB-(PART_START)))

			cp grubaa64.efi bootaa64.efi
			grep -q -F 'mtools_skip_check=1' ~/.mtoolsrc || echo "mtools_skip_check=1" >> ~/.mtoolsrc
			#Create fat partition
			create_fatpart "fat_part"


			#Package images for Busybox
			if [ "$BUSYBOX_BUILD_ENABLED" == "1" ]; then
				rm -f $IMG_BB
				dd if=/dev/zero of=$IMG_BB bs=$BLOCK_SIZE count=$PART_START
				create_cfgfiles "fat_part" "busybox"
				#Create ext3 partition
				create_ext3part "ext3_part" $EXT3_SIZE ""
				# create image and copy into output folder
				create_imagepart $IMG_BB $EXT3_SIZE "ext3_part"
			fi
			#Pacakge images for OE
			if [ "$OE_RAMDISK_BUILD_ENABLED" == "1" ]; then
				#Package if test case is boot
				if [[ "$TEST_LIST" == "boot" || "$TEST_LIST" == "all" ]];then
					rm -f $IMG_OE
					dd if=/dev/zero of=$IMG_OE bs=$BLOCK_SIZE count=$PART_START
					#Copy cfg file as grub.cfg
					create_cfgfiles "fat_part" "oe"
					#Create ext3 partition iwth oe-minimal
					create_ext3part "ext3_part" $EXT3_SIZE  "oe-minimal-rootfs.tar.gz"
					# create image and copy into output folder
					create_imagepart $IMG_OE $EXT3_SIZE "ext3_part"
				fi
				#package if test case is statboot
				if [[ "$TEST_LIST" == "sataboot" || "$TEST_LIST" == "all" ]];then
					rm -f $IMG_OE_SATA
					dd if=/dev/zero of=$IMG_OE_SATA bs=$BLOCK_SIZE count=$PART_START
					#Copy cfg file as grub.cfg
					create_cfgfiles "fat_part" "oe-sata"
					if [ ! -e "$TOP_DIR/$GRUB_PATH/output/ext3_part" ]; then
						create_ext3part "ext3_part" $EXT3_SIZE  "oe-minimal-rootfs.tar.gz"
					fi
					# create image and copy into output folder
					create_imagepart $IMG_OE_SATA $EXT3_SIZE "ext3_part"
				fi

				#Build images for OE lamp FS
				if [[ "$TEST_LIST" == "kvmtest" || "$TEST_LIST" == "pmqa" || "$TEST_LIST" == "all" ]];then
					rm -f $IMG_LAMP
					dd if=/dev/zero of=$IMG_LAMP bs=$BLOCK_SIZE count=$PART_START
					#Copy cfg file as grub.cfg
					create_cfgfiles "fat_part" "oe"
					#create ext3_part with oe-lamp
					create_ext3part "ext3_part" $EXT3_LAMP_SIZE  "oe-lamp-rootfs.tar.gz"
					# create image and copy into output folder
					create_imagepart $IMG_LAMP $EXT3_LAMP_SIZE "ext3_part"
				fi

				# The current arm-tf code for RAS works only on the primary
				# cpu. Define a separate image for RAS which will boot only
				# the primary cpu. This is a temporary hack for this release
				# and can be removed once the arm-tf code is fixed.
				if [[ "$TEST_LIST" == "ras" || "$TEST_LIST" == "all" ]]; then
					rm -f $IMG_LAMP_RAS
					dd if=/dev/zero of=$IMG_LAMP_RAS bs=$BLOCK_SIZE count=$PART_START
					#Copy cfg file as grub.cfg
					create_cfgfiles "fat_part" "oe-ras"
					#create ext3_part with oe-lamp
					create_ext3part "ext3_part" $EXT3_LAMP_SIZE  "oe-lamp-rootfs.tar.gz"
					# create image and copy into output folder
					create_imagepart $IMG_LAMP_RAS $EXT3_LAMP_SIZE "ext3_part"
				fi
            fi
			#remove intermediate files
			rm -f fat_part
			rm -f ext3_part
		fi
	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $@

