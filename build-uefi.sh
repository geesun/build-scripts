#!/usr/bin/env bash

# Copyright (c) 2022, ARM Limited and Contributors. All rights reserved.
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
# UEFI_BUILD_ENABLED - Flag to enable building UEFI
# UEFI_PATH - sub-directory containing UEFI code
# UEFI_BUILD_MODE - DEBUG or RELEASE
# UEFI_TOOLCHAIN - Toolchain supported by Linaro uefi-tools: GCC49, GCC48 or GCC47
# UEFI_PLATFORMS - List of platforms to build
# UEFI_PLAT_{platform name} - array of platform parameters:
#     - platname - the name of the platform used by the build
#     - makefile - the makefile to execute for this platform
#     - output - where to store the files in packaging phase
#     - defines - extra platform defines during the build
#     - binary - what to call the final output binary
# UEFI_ACPICA_PATH - Path to ACPICA tools containing the iasl command

do_build ()
{
	if [ "$UEFI_BUILD_ENABLED" == "1" ]; then
		# build acpica
		pushd $TOP_DIR/$UEFI_ACPICA_PATH
		unset HOST
		echo
		echo -e "${GREEN}Building UEFI ACPICA tools on [`date`]${NORMAL}"
		echo
		set -x
		make -j $PARALLELISM iasl
		{ set +x;  } 2> /dev/null
		popd

		# prepare to build edk2 targets
		pushd $TOP_DIR/$UEFI_PATH
		echo
		echo -e "${BLUE}Setting cross compiler path${NORMAL}"
		echo
		set -x
		if [ "$BUILD_MACHINE_ARCH" == "x86_64" ]; then
			CROSS_COMPILE_DIR=$(dirname $CROSS_COMPILE)
			PATH="$PATH:$CROSS_COMPILE_DIR"
		fi
		{ set +x;  } 2> /dev/null

		#Temporary fix to resolve repo tool issue with fetching git submodules
		#https://gerrit.googlesource.com/git-repo/+/d177609cb0283e41e23d4c19b94e17f42bdbdacb
		git submodule update --init

		echo
		echo -e "${BLUE}Exporting environment variables and sourcing edk2setup.sh script${NORMAL}"
		echo
		set -x
		export WORKSPACE=$TOP_DIR/$UEFI_PATH
		export PACKAGES_PATH=$PWD/:$PWD/edk2-platforms
		export EDK2_TOOLCHAIN=$UEFI_TOOLCHAIN
		export ${UEFI_TOOLCHAIN}_AARCH64_PREFIX=$CROSS_COMPILE
		{ set +x;  } 2> /dev/null
		echo "++ source ./edksetup.sh" # not setting -x for ./edksetup.sh to avoid prints within the script
		source ./edksetup.sh

		# build basetools
		echo
		echo -e "${GREEN}Building UEFI BaseTools on [`date`]${NORMAL}"
		echo
		set -x
		make -j $PARALLELISM -C BaseTools
		{ set +x;  } 2> /dev/null

		local vars=
		for item in $UEFI_PLATFORMS; do
			makefile=UEFI_PLAT_$item[makefile]
			if [ "${!makefile}" != "" ]; then
				vars=UEFI_PLAT_$item[defines]
				export EDK2_MACROS="-n $PARALLELISM ${!vars}"
				vars=UEFI_PLAT_$item[platname]
				export EDK2_PLATFORM=${!vars}
				IASL_PREFIX=${TOP_DIR}/${UEFI_ACPICA_PATH}/bin/ make -f ${!makefile} EDK2_BUILD=$UEFI_BUILD_MODE
			else
				vars=UEFI_PLAT_$item[defines]
				dsc=UEFI_PLAT_$item[dsc]
				echo
				echo "EDK2 build parameters: " $UEFI_EXTRA_BUILD_PARAMS ${!vars}
				echo
				echo -e "${GREEN}Building UEFI for $item on [`date`]${NORMAL}"
				echo
				set -x
				build -n $PARALLELISM -a "AARCH64" -t GCC5 $UEFI_EXTRA_BUILD_PARAMS -b $UEFI_BUILD_MODE -s -p ${!dsc} ${!vars}
				{ set +x;  } 2> /dev/null
			fi
		done
		popd
	fi
}

do_clean ()
{
	if [ "$UEFI_BUILD_ENABLED" == "1" ]; then
		pushd $TOP_DIR/$UEFI_PATH
		echo
		echo -e "${BLUE}Exporting environment variables and sourcing edk2setup.sh script${NORMAL}"
		echo
		set -x
		if [ "$BUILD_MACHINE_ARCH" == "x86_64" ]; then
			CROSS_COMPILE_DIR=$(dirname $CROSS_COMPILE)
			PATH="$PATH:$CROSS_COMPILE_DIR"
		fi
		{ set +x;  } 2> /dev/null
		echo "++ source ./edksetup.sh" # not setting -x for ./edksetup.sh to avoid prints within the script
		source ./edksetup.sh

		echo
		echo -e "${RED}Cleaning UEFI BaseTools on [`date`]${NORMAL}"
		echo
		set -x
		make -C BaseTools clean
		{ set +x;  } 2> /dev/null
		for item in $UEFI_PLATFORMS; do
			name=UEFI_PLAT_$item[platname]
			echo
			echo -e "${RED}Removing UEFI build for $item on [`date`]${NORMAL}"
			echo
			set -x
			rm -rf Build/${!name}
			{ set +x;  } 2> /dev/null
		done
		popd
		pushd $TOP_DIR/$UEFI_ACPICA_PATH
		echo
		echo -e "${RED}Cleaning ACPICA tools on [`date`]${NORMAL}"
		echo
		make veryclean
		popd
	fi
}

do_package ()
{
	if [ "$UEFI_BUILD_ENABLED" == "1" ]; then
		echo "Packaging uefi... $VARIANT";
		# Copy binaries to output folder
		pushd $TOP_DIR
		local name=
		local outp=
		local bins=
		for item in $UEFI_PLATFORMS; do
			bins=UEFI_PLAT_$item[binary]
			outp=UEFI_PLAT_$item[output]
			name=UEFI_PLAT_$item[platname]
			obin=UEFI_PLAT_$item[outbin]

			# Use "uefi.bin" as the default build file name if the platform config
			# file has not provided a name for the uefi build.
			if [ -z "$obin" ]; then
				obin="uefi.bin"
			fi

			mkdir -p ${OUTDIR}/${!outp}
			cp ./$UEFI_PATH/Build/${!name}/${UEFI_BUILD_MODE}_${UEFI_TOOLCHAIN}/FV/${!bins} \
				${OUTDIR}/${!outp}/${!obin}
		done
		popd

	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $@
