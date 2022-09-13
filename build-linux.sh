#!/usr/bin/env bash

# Copyright (c) 2015-2022, ARM Limited and Contributors. All rights reserved.
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
# LINUX_CONFIG_LIST - List of Linaro configs to use to build
# LINUX_CONFIG_DEFAULT - the default from the list (for tools)
# LINUX_{config} - array of linux config options, indexed by
# 	path - the path to the linux source
#	defconfig - a defconfig to build
#	config - the list of config fragments which would get
#	appended to the .config generated from base defconfig
# LINUX_TOOLS_IOMMU_BUILD - Build tools/iommu in Linux
# TARGET_BINS_PLATS - the platforms to create binaries for
# TARGET_{plat} - array of platform parameters, indexed by
#	fdts - the fdt pattern used by the platform
# UBOOT_UIMAGE_ADDRS - address at which to link UBOOT image
# UBOOT_MKIMAGE - path to uboot mkimage
# LINUX_ARCH - the arch
# UBOOT_BUILD_ENABLED - flag to indicate the need for uimages.
#
# LINUX_IMAGE_TYPE - Image or zImage (Image is the default if not specified)

do_build ()
{
	if [ "$LINUX_BUILD_ENABLED" == "1" ]; then
		export ARCH=$LINUX_ARCH
		for name in $LINUX_CONFIG_LIST; do
			local lpath=LINUX_$name[path];
			local lconfig=LINUX_$name[config];
			local lmodules=LINUX_$name[modules];

			echo "config: $name"
			pushd $TOP_DIR/${!lpath};
			mkdir -p $LINUX_OUT_DIR/$name
			confs=LINUX_$name[config]
			echo "confs: ${!confs}"

			ldefconfig=LINUX_$name[defconfig];
			echo
			echo -e "${GREEN}Building linux using ${!ldefconfig} on [`date`]${NORMAL}"
			echo
			set -x
			make O=$LINUX_OUT_DIR/$name ${!ldefconfig}
			{ set +x;  } 2> /dev/null

			# pull in fragments if available
			if [ "${!lconfig}" != "" ]; then
				echo "Building using config fragments..."
				CONFIG=""
				# Iterate through all the configs in the list
				# and append them to .config
				for config in ${!lconfig}; do
					set -x
					CONFIG=$DIR"/configs/"$FLAVOUR"/fragments/${config}"
					scripts/kconfig/merge_config.sh -O $LINUX_OUT_DIR/$name/ $LINUX_OUT_DIR/$name/.config $CONFIG
					set +x
				done
			fi

			echo
			echo -e "${GREEN}Building linux $LINUX_IMAGE_TYPE and dtbs on [`date`]${NORMAL}"
			echo
			set -x
			make O=$LINUX_OUT_DIR/$name -j$PARALLELISM $LINUX_IMAGE_TYPE dtbs
			{ set +x;  } 2> /dev/null

			if [ "$LINUX_TOOLS_IOMMU_BUILD" == "1" ]; then
				echo
				echo -e "${GREEN}Building linux headers_install on [`date`]${NORMAL}"
				echo
				set -x
				make O=$LINUX_OUT_DIR/$name headers_install
				{ set +x;  } 2> /dev/null

				echo
				echo -e "${GREEN}Building linux iommu tools on [`date`]${NORMAL}"
				echo
				set -x
				make O=$LINUX_OUT_DIR/$name tools/iommu
				{ set +x;  } 2> /dev/null
			fi

			if [ "${!lmodules}" == "true" ]; then
				echo
				echo -e "${GREEN}Building ${!lconfig} for linux on [`date`]${NORMAL}"
				echo
				set -x
				make O=$LINUX_OUT_DIR/$name/modules ${!lconfig}
				{ set +x;  } 2> /dev/null

				echo
				echo -e "${GREEN}Building linux modules on [`date`]${NORMAL}"
				echo
				set -x
				make O=$LINUX_OUT_DIR/$name/modules -j$PARALLELISM modules
				{ set +x;  } 2> /dev/null
			fi
			popd
		done
	fi
}

do_clean ()
{
	if [ "$LINUX_BUILD_ENABLED" == "1" ]; then
		export ARCH=$LINUX_ARCH

		for name in $LINUX_CONFIG_LIST; do
			local lpath=LINUX_$name[path];
			local outpath=LINUX_$name[outpath];
			rm -rf ${OUTDIR}/${!outpath}/tools/iommu/smmute
			pushd $TOP_DIR/${!lpath};
			echo
			echo -e "${RED}Cleaning linux $name on [`date`]${NORMAL}"
			echo
			set -x
			make O=$LINUX_OUT_DIR/$name distclean
			{ set +x;  } 2> /dev/null
			popd
		done

		rm -rf $TOP_DIR/$LINUX_PATH/$LINUX_OUT_DIR
	fi
}

do_package ()
{
	if [ "$LINUX_BUILD_ENABLED" == "1" ]; then
		echo "Packaging Linux... $VARIANT";
		# Copy binary to output folder
		pushd $TOP_DIR

		for name in $LINUX_CONFIG_LIST; do
			local lpath=LINUX_$name[path];
			local outpath=LINUX_$name[outpath];
			local lmodules=LINUX_$name[modules];
			mkdir -p ${OUTDIR}/${!outpath}

			cp $TOP_DIR/${!lpath}/$LINUX_OUT_DIR/$name/arch/$LINUX_ARCH/boot/$LINUX_IMAGE_TYPE ${OUTDIR}/${!outpath}/$LINUX_IMAGE_TYPE.$name
			if [ ${!lmodules} == "true" ]; then
				cp -R $TOP_DIR/${!lpath}/$LINUX_OUT_DIR/$name/modules ${OUTDIR}/${!outpath}/modules
			fi

			if [ "$LINUX_CONFIG_DEFAULT" = "$name" ]; then
				for plat in $TARGET_BINS_PLATS; do
					local fd=TARGET_$plat[fdts]
					for target in ${!fd}; do
						for item in $target; do
							discoveredDTB=$(find $TOP_DIR/${!lpath}/$LINUX_OUT_DIR/$name/arch/$LINUX_ARCH/boot/dts -name ${item}.dtb)
							if [ "${discoveredDTB}" = "" ]; then
								echo "skipping dtb $item"
							else
								cp ${discoveredDTB} ${OUTDIR}/${!outpath}/.
							fi
						done
					done
				done
				cp ${OUTDIR}/${!outpath}/$LINUX_IMAGE_TYPE.$name ${OUTDIR}/${!outpath}/$LINUX_IMAGE_TYPE

				if [ "$LINUX_TOOLS_IOMMU_BUILD" == "1" ]; then
					mkdir -p ${OUTDIR}/${!outpath}/tools/iommu/smmute
					cp $TOP_DIR/${!lpath}/$LINUX_OUT_DIR/$name/tools/iommu/smmute/smmute ${OUTDIR}/${!outpath}/tools/iommu/smmute/
				fi
			fi

			if [ "$UBOOT_BUILD_ENABLED" == "1" ]; then
				pushd ${OUTDIR}/${!outpath}
				for addr in $UBOOT_UIMAGE_ADDRS; do
					${UBOOT_MKIMG} -A $LINUX_ARCH -O linux -C none \
						-T kernel -n Linux \
						-a $addr -e $addr \
						-n "Linux" -d $LINUX_IMAGE_TYPE.$name uImage.$addr.$name
					if [ "$LINUX_CONFIG_DEFAULT" = "$name" ]; then
						cp uImage.$addr.$name uImage.$addr
					fi
				done
				popd
			fi
		done
	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $@
