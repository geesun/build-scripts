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
# ARM_TF_PATH - for the fip tool / output images
# UBOOT_PATH - for mkimage / output images
# TARGET_BINS_PLATS - the platforms to create binaries for
# TARGET_ARM_TF_### - the arm-tf output directory, where ### is the arm-tf plat name
# TARGET_SCP_### - the scp output directory, where ### is the scp plat name
# TARGET_UBOOT_### - the uboot output directory, where ### is the boot plat name
# TARGET_UEFI_### - the uefi output directory, where ### is the uefi plat name.
# TARGET_BINS_UIMAGE_ADDRS - the uImage load addresses
# TARGET_BINS_UINITRD_ADDRS - the uInitrd load addresses
# TARGET_BINS_HAS_ANDROID - whether we have android enabled
# TARGET_BINS_HAS_OE - whether we have OE enabled
# TARGET_BINS_HAS_DTB_RAMDISK - whether create dtbs with ramdisk chosen node
# TARGET_BINS_RAMDISK_ADDR - address in RAM that ramdisk is loaded. Required if TARGET_BINS_HAS_DTB_RAMDISK=1
# LINUX_ARCH - the architecure to build the output for (arm or arm64)
# DEVTREE_LINUX_PATH - Path to Linux tree containing DT compiler

populate_variant()
{
	local outdir=$1
	local boot_type=$2

	# copy ramdisk to the variant
	if [ "$TARGET_BINS_HAS_OE" = "1" ]; then
		cp ${OUTDIR}/uInitrd-oe.$TARGET_BINS_UINITRD_ADDRS $outdir/ramdisk.img
	elif [ "$TARGET_BINS_HAS_BUSYBOX" = "1" ]; then
		if [ "$boot_type" = "uboot" ]; then
			cp ${OUTDIR}/uInitrd-busybox.$TARGET_BINS_UINITRD_ADDRS $outdir/ramdisk.img
		else
			cp ${OUTDIR}/ramdisk.img $outdir/ramdisk.img
		fi
	elif [ "$TARGET_BINS_HAS_ANDROID" = "1" ]; then
		if [ "$boot_type" = "uboot" ]; then
			cp ${OUTDIR}/uInitrd-android.$TARGET_BINS_UINITRD_ADDRS $outdir/ramdisk.img
		else
			cp ${TOP_DIR}/ramdisk.img $outdir/ramdisk.img
		fi
	fi

	# copy the kernel Image and *.dtb to the variant
	if [ "$TARGET_BINS_UIMAGE_ADDRS" != "" ]; then
		for addr in $TARGET_BINS_UIMAGE_ADDRS; do
			cp ${OUTDIR}/$LINUX_PATH/$VARIANT/uImage.$addr $outdir
		done
	else
		cp ${OUTDIR}/$LINUX_PATH/$VARIANT/Image $outdir
	fi
	for item in $DEVTREE_TREES; do
		cp ${TOP_DIR}/$LINUX_PATH/arch/arm64/boot/dts/arm/${item}.dtb $outdir 2>/dev/null || :
		cp ${TOP_DIR}/$LINUX_PATH/arch/arm64/boot/dts/${item}.dtb $outdir 2>/dev/null || :
	done

}

do_build()
{
	if [ "$TARGET_BINS_BUILD_ENABLED" == "1" ]; then
		echo "Build"
	fi
}

do_clean()
{
	if [ "$TARGET_BINS_BUILD_ENABLED" == "1" ]; then
		echo "clean"
	fi
}

append_chosen_node()
{
	# $1 = dtb name
	# $2 = ramdisk file
	local ramdisk_end=$(($TARGET_BINS_RAMDISK_ADDR + $(wc -c < $2)))
	local DTC=$TOP_DIR/$LINUX_PATH/scripts/dtc/dtc
	local tmp=linux/tmp
	local devtree_path=$TOP_DIR/$LINUX_PATH/arch/arm64/boot/dts/arm
	local devtree=$devtree_path/$1

	if [ ! -e $devtree_path ]; then
		# take into account that the DTS dir added and "arm" sub-dir between 3.10 and 4.1
		devtree_path=$TOP_DIR/$LINUX_PATH/arch/arm64/boot/dts
		devtree=$devtree_path/$1
	fi

	cp ${devtree}.dtb ${tmp}.dtb

	# Decode the DTB
	${DTC} -Idtb -Odts -o${tmp}.dts ${devtree}.dtb

	echo "" >> ${tmp}.dts
	echo "/ {" >> ${tmp}.dts
	echo "	chosen {" >> ${tmp}.dts
	echo "		linux,initrd-start = <$TARGET_BINS_RAMDISK_ADDR>;" >> ${tmp}.dts
	echo "		linux,initrd-end = <${ramdisk_end}>;" >> ${tmp}.dts
	echo "	};" >> ${tmp}.dts
	echo "};" >> ${tmp}.dts

	# Recode the DTB - over-writing the current one
	${DTC} -Idts -Odtb -o${devtree}.dtb ${tmp}.dts

	# And clean up
	rm ${tmp}.dts
}

do_package()
{
	if [ "$TARGET_BINS_BUILD_ENABLED" == "1" ]; then
		# Create uImages and uInitrds
		local uboot_mkimage=${TOP_DIR}/${UBOOT_PATH}/tools/mkimage
		local common_flags="-A $LINUX_ARCH -O linux -C none"
		pushd ${OUTDIR}/$LINUX_PATH
		for addr in $TARGET_BINS_UIMAGE_ADDRS; do
			${uboot_mkimage} ${common_flags} -T kernel -n Linux -a $addr -e $addr -n "Linux" -d Image uImage.$addr
		done
		popd
		pushd ${OUTDIR}
		if [ "$TARGET_BINS_HAS_ANDROID" = "1" ]; then
			for addr in $TARGET_BINS_UINITRD_ADDRS; do
				${uboot_mkimage} ${common_flags} -T ramdisk -n ramdisk -a $addr -e $addr -n "Android ramdisk" -d ${TOP_DIR}/ramdisk.img uInitrd-android.$addr
			done
		fi
		if [ "$TARGET_BINS_HAS_OE" = "1" ]; then
			mkdir -p oe
			touch oe/initrd ; echo oe/initrd | cpio -ov > ramdisk-oe.img
			for addr in $TARGET_BINS_UINITRD_ADDRS; do
				${uboot_mkimage} ${common_flags} -T ramdisk -n ramdisk -a $addr -e $addr -n "Dummy ramdisk" -d ramdisk-oe.img uInitrd-oe.$addr
			done
		fi
		if [ "$TARGET_BINS_HAS_BUSYBOX" = "1" ]; then
			mkdir -p busybox
			for addr in $TARGET_BINS_UINITRD_ADDRS; do
				${uboot_mkimage} ${common_flags} -T ramdisk -n ramdisk -a $addr -e $addr -n "BusyBox ramdisk" -d ${OUTDIR}/ramdisk.img uInitrd-busybox.$addr
			done
		fi
		popd

		# Add chosen node for ramdisk to dtbs

		if [ "$TARGET_BINS_HAS_DTB_RAMDISK" = "1" ]; then
			pushd ${OUTDIR}
			for item in $DEVTREE_TREES; do
				if [ "$TARGET_BINS_HAS_ANDROID" = "1" ]; then
					append_chosen_node ${item} ${TOP_DIR}/ramdisk.img
				fi
				if [ "$TARGET_BINS_HAS_OE" = "1" ]; then
					append_chosen_node ${item} ramdisk-oe.img
				fi
				if [ "$TARGET_BINS_HAS_BUSYBOX" = "1" ]; then
					append_chosen_node ${item} ramdisk.img
				fi
			done
			popd
		fi

		echo "Packaging target binaries $VARIANT";
		# Create FIPs
		for target in $TARGET_BINS_PLATS; do
			local tf_out="TARGET_ARM_TF_"$target
			local scp_out="TARGET_SCP_"$target
			local uboot_out="TARGET_UBOOT_"$target
			local uefi_out="TARGET_UEFI_"$target
			local bl2_fip_param="--bl2  ${OUTDIR}/${!tf_out}/tf-bl2.bin"
			local bl31_fip_param="--bl31 ${OUTDIR}/${!tf_out}/tf-bl31.bin"
			local bl30_fip_param=

			if [ "${!scp_out}" != "" ]; then
				bl30_fip_param="--bl30 ${TOP_DIR}/${!scp_out}/bl30.bin"
			fi

			if [ "${!uboot_out}" != "" ]; then
				# remove existing fip
				local outdir=${OUTDIR}/${VARIANT}/uboot
				local outfile=${outdir}/fip.bin
				rm -f $outfile
				mkdir -p ${outdir}
				$TOP_DIR/$ARM_TF_PATH/tools/fip_create/fip_create --dump  \
					${bl2_fip_param} \
					${bl31_fip_param} \
					${bl30_fip_param} \
					--bl33 ${OUTDIR}/${!uboot_out}/uboot.bin \
					$outfile
				cp ${OUTDIR}/${!tf_out}/tf-bl1.bin $outdir/bl1.bin
				populate_variant $outdir uboot
			fi
			if [ "${!uefi_out}" != "" ]; then
				# remove existing fip
				local outdir=${OUTDIR}/${VARIANT}/uefi
				local outfile=${outdir}/fip.bin
				rm -f $outfile
				mkdir -p ${outdir}
				$TOP_DIR/$ARM_TF_PATH/tools/fip_create/fip_create --dump  \
					${bl2_fip_param} \
					${bl31_fip_param} \
					${bl30_fip_param} \
					--bl33 ${OUTDIR}/${!uefi_out}/uefi.bin \
					$outfile
				cp ${OUTDIR}/${!tf_out}/tf-bl1.bin $outdir/bl1.bin
				populate_variant $outdir uefi
			fi
		done

		# clean up unwanted artifacts left in output directory
		pushd ${OUTDIR}
		rm uInitrd-android.* || :
		rm uInitrd-oe.* || :
		rm ramdisk-oe.img || :
		rm -rf linux || :
		rm -rf juno || :
		rm -rf oe || :
		popd
	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $1 $2
