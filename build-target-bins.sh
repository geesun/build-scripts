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
# LINUX_IMAGE_TYPE - Image or zImage (defaults to Image if not specified)
LINUX_IMAGE_TYPE=${LINUX_IMAGE_TYPE:-Image}

populate_variant()
{
	local outdir=$1
	local boot_type=$2

	# copy ramdisk to the variant
	if [ "$TARGET_BINS_HAS_OE" = "1" ]; then
		if [ "$boot_type" = "uboot" ]; then
			cp ${OUTDIR}/uInitrd-oe.$TARGET_BINS_UINITRD_ADDRS $outdir/ramdisk.img
		else
			cp ${OUTDIR}/ramdisk.img $outdir/ramdisk.img
		fi
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

	if [ "$LINUX_BUILD_ENABLED" == "1" ]; then
		# copy the kernel Image and *.dtb to the variant
		if [ "$TARGET_BINS_UIMAGE_ADDRS" != "" ]; then
			for addr in $TARGET_BINS_UIMAGE_ADDRS; do
				cp ${OUTDIR}/$LINUX_PATH/$VARIANT/uImage.$addr $outdir
			done
		else
			cp ${OUTDIR}/$LINUX_PATH/$VARIANT/$LINUX_IMAGE_TYPE $outdir
		fi
		for ((i=0;i<${#DEVTREE_TREES[@]};++i)); do
			if [ "$TARGET_BINS_HAS_DTB_RAMDISK" = "1" ]; then
				chosen="-chosen"
			fi
			if [ "${DEVTREE_TREES_RENAME[i]}" == "" ]; then
				newname=${DEVTREE_TREES[i]}.dtb
			else
				newname=${DEVTREE_TREES_RENAME[i]}
			fi
			dts_dir=${TOP_DIR}/$LINUX_PATH/$LINUX_OUT_DIR/arch/${LINUX_ARCH}/boot/dts/arm/
			if [ ! -e ${TOP_DIR}/$LINUX_PATH/$LINUX_OUT_DIR/arch/${LINUX_ARCH}/boot/dts/arm/ ]; then
				dts_dir=${TOP_DIR}/$LINUX_PATH/$LINUX_OUT_DIR/arch/${LINUX_ARCH}/boot/dts/
			fi

			cp ${dts_dir}/${DEVTREE_TREES[i]}${chosen}.dtb $outdir/${newname} 2>/dev/null || :
		done
	fi
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
	local DTC=$TOP_DIR/$LINUX_PATH/$LINUX_OUT_DIR/scripts/dtc/dtc
	local tmp=linux/tmp
	local devtree_path=$TOP_DIR/$LINUX_PATH/$LINUX_OUT_DIR/arch/arm64/boot/dts/arm
	local devtree=$devtree_path/$1

	if [ ! -e $devtree_path ]; then
		# take into account that the DTS dir added and "arm" sub-dir between 3.10 and 4.1
		devtree_path=$TOP_DIR/$LINUX_PATH/$LINUX_OUT_DIR/arch/arm64/boot/dts
		devtree=$devtree_path/$1
	fi

	if [ -e ${devtree}.dtb ]; then
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

		# Recode the DTB
		${DTC} -Idts -Odtb -o${devtree}-chosen.dtb ${tmp}.dts

		# And clean up
		rm ${tmp}.dts
	else
		echo ""
		echo ""
		echo "********************************************************************************"
		echo "ERROR: Missing file: ${devtree}.dtb"
		echo "       Continuing to process other .dtb files"
		echo "********************************************************************************"
		echo ""
		echo ""
	fi
}

do_package()
{
	if [ "$TARGET_BINS_BUILD_ENABLED" == "1" ]; then
		# Create uImages and uInitrds
		local uboot_mkimage=${TOP_DIR}/${UBOOT_PATH}/output/tools/mkimage
		local common_flags="-A $LINUX_ARCH -O linux -C none"
		if [ "$LINUX_BUILD_ENABLED=" == "1" ]; then
			pushd ${OUTDIR}/$LINUX_PATH
			for addr in $TARGET_BINS_UIMAGE_ADDRS; do
				${uboot_mkimage} ${common_flags} -T kernel -n Linux -a $addr -e $addr -n "Linux" -d $LINUX_IMAGE_TYPE uImage.$addr
			done
			popd
		fi
		pushd ${OUTDIR}
		if [ "$TARGET_BINS_HAS_ANDROID" = "1" ]; then
			for addr in $TARGET_BINS_UINITRD_ADDRS; do
				${uboot_mkimage} ${common_flags} -T ramdisk -n ramdisk -a $addr -e $addr -n "Android ramdisk" -d ${TOP_DIR}/ramdisk.img uInitrd-android.$addr
			done
		fi
		if [ "$TARGET_BINS_HAS_OE" = "1" ]; then
			mkdir -p oe
			touch oe/initrd ; echo oe/initrd | cpio -ov > ramdisk.img
			for addr in $TARGET_BINS_UINITRD_ADDRS; do
				${uboot_mkimage} ${common_flags} -T ramdisk -n ramdisk -a $addr -e $addr -n "Dummy ramdisk" -d ramdisk.img uInitrd-oe.$addr
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
			for ((i=0;i<${#DEVTREE_TREES[@]};++i)); do
				item=${DEVTREE_TREES[i]}
				if [ "$TARGET_BINS_HAS_ANDROID" = "1" ]; then
					append_chosen_node ${item} ${TOP_DIR}/ramdisk.img
				fi
				if [ "$TARGET_BINS_HAS_OE" = "1" ]; then
					append_chosen_node ${item} ramdisk.img
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
			local bl2_param="--tb-fw  ${OUTDIR}/${!tf_out}/tf-bl2.bin"
			local bl31_param="--soc-fw ${OUTDIR}/${!tf_out}/tf-bl31.bin"
			local bl30_param=
			local bl32_param=

			if [ "${!scp_out}" != "" ]; then
				bl30_param="--scp-fw ${TOP_DIR}/${!scp_out}/bl30.bin"
			fi

			if [ -e "${OUTDIR}/${!tf_out}/tf-bl32.bin" ]; then
				bl32_param="--tos-fw ${OUTDIR}/${!tf_out}/tf-bl32.bin"
			fi
			local common_param="${bl2_param} ${bl31_param}  ${bl30_param} ${bl32_param}"
			if [ "$ARM_TBBR_ENABLED" == "1" ]; then
				local trusted_key_cert_param="--trusted-key-cert ${OUTDIR}/${!tf_out}/trusted_key.crt"
				local bl30_tbbr_param="--scp-fw-key-cert ${OUTDIR}/${!tf_out}/bl30_key.crt --scp-fw-cert ${OUTDIR}/${!tf_out}/bl30.crt"
				local bl31_tbbr_param="--soc-fw-key-cert ${OUTDIR}/${!tf_out}/bl31_key.crt --soc-fw-cert ${OUTDIR}/${!tf_out}/bl31.crt"
				local bl32_tbbr_param=
				local bl33_tbbr_param="--nt-fw-key-cert ${OUTDIR}/${!tf_out}/bl33_key.crt --nt-fw-cert ${OUTDIR}/${!tf_out}/bl33.crt"
				local bl2_tbbr_param="--tb-fw-cert ${OUTDIR}/${!tf_out}/bl2.crt"

				#only if a TEE implementation is available and built
				if [ -e "${OUTDIR}/${!tf_out}/tf-bl32.bin" ]; then
					bl32_tbbr_param="--tos-fw-key-cert ${OUTDIR}/${!tf_out}/bl32_key.crt --tos-fw-cert ${OUTDIR}/${!tf_out}/bl32.crt"
				fi
				# add the cert related params to be used by fip_create as well as cert_create
				common_param="${common_param} ${trusted_key_cert_param} \
					   ${bl30_tbbr_param} ${bl31_tbbr_param} \
					   ${bl32_tbbr_param} ${bl33_tbbr_param} \
					   ${bl2_tbbr_param}"

				#fip_create tool and cert_create tool take almost identical params
				local cert_tool_param="${common_param} --rot-key ${ROT_KEY} -n"

			fi

			if [ "$BOOTMON_BUILD_ENABLED" == "1" ]; then
					local outdir=${OUTDIR}/${VARIANT}/bootmon
					local outfile=${outdir}/${BOOTMON_SCRIPT}
					rm -f $outfile
					mkdir -p ${outdir}
					echo "fl linux fdt board.dtb" > $outfile
					echo "fl linux initrd ramdisk.img" >> $outfile
					echo "fl linux boot zImage console=ttyAMA0,38400 earlyprintk debug verbose rootwait root=/dev/sda2 androidboot.hardware=arm-versatileexpress-usb" >> $outfile
					populate_variant $outdir bootmon
			fi

			if [ "$UBOOT_BUILD_ENABLED" == "1" ]; then
				if [ "${!uboot_out}" != "" ]; then
					# remove existing fip
					local outdir=${OUTDIR}/${VARIANT}/uboot
					local outfile=${outdir}/fip.bin
					rm -f $outfile
					mkdir -p ${outdir}
					# if TBBR is enabled, generate certificates
					if [ "$ARM_TBBR_ENABLED" == "1" ]; then
						$TOP_DIR/$ARM_TF_PATH/tools/cert_create/cert_create  \
							${cert_tool_param} \
							--nt-fw ${OUTDIR}/${!uboot_out}/uboot.bin

					fi
					if [ "$ARM_TF_BUILD_ENABLED" == "1" ]; then
						$TOP_DIR/$ARM_TF_PATH/tools/fip_create/fip_create --dump  \
							${common_param} \
							--nt-fw ${OUTDIR}/${!uboot_out}/uboot.bin \
							$outfile
						cp ${OUTDIR}/${!tf_out}/tf-bl1.bin $outdir/bl1.bin
					else
						cp ${OUTDIR}/${!uboot_out}/uboot.bin ${OUTDIR}/${VARIANT}/uboot/$UBOOT_OUTPUT_FILENAME
					fi
					populate_variant $outdir uboot
				fi
			fi
			if [ "$UEFI_BUILD_ENABLED" == "1" ]; then
				if [ "${!uefi_out}" != "" ]; then
					# remove existing fip
					local outdir=${OUTDIR}/${VARIANT}/uefi
					local outfile=${outdir}/fip.bin
					rm -f $outfile
					mkdir -p ${outdir}
					# if TBBR is enabled, generate certificates
					if [ "$ARM_TBBR_ENABLED" == "1" ]; then
						$TOP_DIR/$ARM_TF_PATH/tools/cert_create/cert_create  \
							${cert_tool_param} \
							--nt-fw ${OUTDIR}/${!uefi_out}/uefi.bin

					fi
					if [ "$ARM_TF_BUILD_ENABLED" == "1" ]; then
						$TOP_DIR/$ARM_TF_PATH/tools/fip_create/fip_create --dump  \
							${common_param} \
							--nt-fw ${OUTDIR}/${!uefi_out}/uefi.bin \
							$outfile
						cp ${OUTDIR}/${!tf_out}/tf-bl1.bin $outdir/bl1.bin
					else
						cp ${OUTDIR}/${!uefi_out}/uefi.bin ${OUTDIR}/${VARIANT}/uefi/$UEFI_OUTPUT_FILENAME
					fi
					populate_variant $outdir uefi
				fi
			fi
		done

		# clean up unwanted artifacts left in output directory
		pushd ${OUTDIR}
		rm -f uInitrd-* || :
		rm -f ramdisk*.img || :
		rm -rf linux || :
		rm -rf ${TARGET_BINS_PLATS} || :
		rm -rf oe || :
		rm -rf busybox || :
		popd
	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $1 $2
