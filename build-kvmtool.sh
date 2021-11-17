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

#
# This script uses the following environment variables from the variant
#
# TOP_DIR - workspace root directory
# OUTDIR - output dir for final packaging
# PLATDIR - Platform Output directory
# PLATFORM - Requested Platform
# CROSS_COMPILE - PATH to GCC including CROSS-COMPILE prefix
# PARALLELISM - number of cores to build across
# KVMTOOL_BUILD_ENABLED - Flag to enable building kvmtool
# KVM_UNIT_TESTS_BUILD_ENABLED - Flag to enable building kvm-unit-tests
# KVMTOOL_SUPPORT_PLATFORM - Base supported platform for the binary


do_build ()
{
	# Check if required architecture supported by compiler
	if [ "$KVMTOOL_BUILD_ENABLED" == "1" ] ||
		[ "$KVM_UNIT_TESTS_BUILD_ENABLED" == "1" ]; then
		local CC CC_ARCH SCRIPT_NAME

		SCRIPT_NAME=$(basename "$0")

		#Check if the cross compiler supports AArch64 target
		CC=${CROSS_COMPILE}gcc
		CC_ARCH=$($CC -dumpmachine)
		if [[ $CC_ARCH != *"aarch64"* ]]; then
			echo -en "${RED}${SCRIPT_NAME}:${LINENO}:${NORMAL}"
			echo -e " Requires an AArch64 based compiler"
			return 1
		fi
	fi

	if [ "$KVMTOOL_BUILD_ENABLED" == "1" ]; then
		# Build kvmtool
		pushd "${TOP_DIR}/kvmtool"
		echo
		echo -e "${GREEN}Building kvmtool for ${PLATFORM} on [$(date)]${NORMAL}"
		echo
		set -x
		make -j $PARALLELISM ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE}
		{ set +x;  } 2> /dev/null
		echo
		echo -e "${GREEN}kvmtool build successful for ${PLATFORM} on [$(date)]${NORMAL}"
		echo
		popd
	fi

	if [ "$KVM_UNIT_TESTS_BUILD_ENABLED" == "1" ]; then
		# Build kvm-unit-tests
		pushd "${TOP_DIR}/kvm-unit-tests"
		echo
		echo -e "${GREEN}Building kvm-unit-tests for ${PLATFORM} on [$(date)]${NORMAL}"
		echo
		set -x
		./configure --arch=arm64 --cross-prefix=${CROSS_COMPILE} \
				--target=kvmtool --earlycon=uart,mmio,0x1000000
		make -j $PARALLELISM
		{ set +x;  } 2> /dev/null
		echo
		echo -e "${GREEN}kvm-unit-tests build successful for ${PLATFORM} on [$(date)]${NORMAL}"
		echo
		popd
	fi
	return 0
}

do_clean ()
{
	if [ "$KVMTOOL_BUILD_ENABLED" == "1" ]; then
		local bin_dir link_dir

		# Remove kvmtool links and bins
		bin_dir=${OUTDIR}/${KVMTOOL_SUPPORT_PLATFORM}
		link_dir=${PLATDIR}/${PLATFORM}
		rm -f "${link_dir}/lkvm"
		rm -f "${bin_dir}/lkvm"

		# Clean kvmtool build directory
		pushd "${TOP_DIR}/kvmtool"
		echo
		echo -e "${GREEN}Cleaning kvmtool for ${PLATFORM} on [$(date)]${NORMAL}"
		echo
		set -x
		make clean
		{ set +x;  } 2> /dev/null
		echo
		echo -e "${GREEN}Cleaned kvmtool for ${PLATFORM} on [$(date)]${NORMAL}"
		echo
		popd
	fi

	if [ "$KVM_UNIT_TESTS_BUILD_ENABLED" == "1" ]; then
		local kvm_ut_dir

		# Remove kvm-unit-tests related directory
		kvm_ut_dir="${TOP_DIR}/kvm-unit-tests/kvm-ut"
		rm -rf "${OUTDIR}/kvm-ut"
		rm -rf ${kvm_ut_dir}

		# Clean kvm-unit-tests build directory
		pushd "${TOP_DIR}/kvm-unit-tests"
		echo
		echo -e "${GREEN}Cleaning kvm-unit-tests for ${PLATFORM} on [$(date)]${NORMAL}"
		echo
		set -x
		./configure --arch=arm64 --cross-prefix=${CROSS_COMPILE} \
				--target=kvmtool --earlycon=uart,mmio,0x1000000
		make clean
		{ set +x;  } 2> /dev/null
		echo
		echo -e "${GREEN}Cleaned kvm-unit-tests for ${PLATFORM} on [$(date)]${NORMAL}"
		echo
		popd
	fi
}

do_package ()
{

	if [ "$KVMTOOL_BUILD_ENABLED" == "1" ]; then
		local bin_dir

		# Copy kvmtool bin to appropriate directory and create symlink
		bin_dir="${OUTDIR}/${KVMTOOL_SUPPORT_PLATFORM}"
		mkdir -p ${bin_dir}
		cp "${TOP_DIR}/kvmtool/lkvm" ${bin_dir}
		create_tgt_symlinks ${KVMTOOL_SUPPORT_PLATFORM} ${PLATFORM} "lkvm*"
		echo
		echo -e "${GREEN}kvmtool Packaged..${NORMAL}"
		echo
	fi

	if [ "$KVM_UNIT_TESTS_BUILD_ENABLED" == "1" ]; then
		local kvm_ut_dir

		# Copy kvm-unit-tests related files to appropriate directory
		kvm_ut_dir="${TOP_DIR}/kvm-unit-tests/kvm-ut"
		rm -rf ${kvm_ut_dir}
		mkdir -p ${kvm_ut_dir}
		mkdir -p "${kvm_ut_dir}/arm"
		cp ${TOP_DIR}/kvm-unit-tests/arm/*.flat "${kvm_ut_dir}/arm/"
		cp "${TOP_DIR}/kvm-unit-tests/arm/run" "${kvm_ut_dir}/arm/"
		cp "${TOP_DIR}/kvm-unit-tests/arm/unittests.cfg" "${kvm_ut_dir}/arm/"
		cp "${TOP_DIR}/kvm-unit-tests/config.mak" "${kvm_ut_dir}/"
		cp -a "${TOP_DIR}/kvm-unit-tests/scripts" "${kvm_ut_dir}/"
		cp "${TOP_DIR}/kvm-unit-tests/run_tests.sh" "${kvm_ut_dir}/"
		cp -a "${kvm_ut_dir}" "${OUTDIR}"
		echo
		echo -e "${GREEN}kvm-unit-test Packaged..${NORMAL}"
		echo
	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
set -- "-f none $@"
source $DIR/common_utils.sh
source $DIR/framework.sh $@
