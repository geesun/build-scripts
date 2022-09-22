#!/usr/bin/env bash

# Copyright (c) 2019-2022, Arm Limited and Contributors. All rights reserved.
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

if [ -z "$refinfra" ] ; then
	refinfra="sgi"
fi

declare -A platforms_sgi
platforms_sgi[sgi575]=1
declare -A platforms_rdinfra
platforms_rdinfra[rdn1edge]=1
platforms_rdinfra[rdn1edgex2]=1
platforms_rdinfra[rdv1]=1
platforms_rdinfra[rdv1mc]=1
platforms_rdinfra[rdn2]=1
platforms_rdinfra[rdn2cfg1]=1
platforms_rdinfra[rdn2cfg2]=1
platforms_rdinfra[rdv2]=1

__print_supported_platforms_sgi()
{
	echo "Supported platforms are -"
	for plat in "${!platforms_sgi[@]}" ;
		do
			printf "\t $plat\n"
		done
	echo
}

__print_supported_platforms_rdinfra()
{
	echo "Supported platforms are -"
	for plat in "${!platforms_rdinfra[@]}" ;
		do
			printf "\t $plat\n"
		done
	echo
}

__print_examples()
{
	echo "Example 1: ./build-scripts/$refinfra/build-test-acs.sh -p $1 all"
	echo "   This command builds the software stack for $1 platform and"
	echo "   prepares a disk image to boot upto uefi shell"
	echo
	echo "Example 2: ./build-scripts/$refinfra/build-test-acs.sh -p $1 clean"
	echo "   This command cleans the previous build of the $1 platform "
	echo "   software stack"
}

__print_examples_sgi()
{
	__print_examples "sgi575"
}

__print_examples_rdinfra()
{
	__print_examples "rdn1edge"
}

__print_usage()
{
	echo "Usage: ./build-scripts/$refinfra/build-test-acs.sh -p <platform> <command>"
	echo
	echo "build-test-acs.sh: Builds the platform software stack with all the"
	echo "required software components that allows the execution for Arm"
	echo "Architecture Compliance Suite (ACS) tests."
	echo
	__print_supported_platforms_$refinfra
	echo "Supported build commands are - clean/build/package/all"
	echo
	__print_examples_$refinfra
	echo
	exit 0
}

#callback from build-all.sh to override any build config
__do_override_build_configs()
{
	echo "build-test-acs.sh: overriding BUILD_SCRIPTS"
	BUILD_SCRIPTS="build-arm-tf.sh build-uefi.sh build-scp.sh build-target-bins.sh "

	# Disable RAS extension on arm-tf build
	ARM_TF_BUILD_FLAGS="${ARM_TF_BUILD_FLAGS/RAS_EXTENSION=1/}"
	ARM_TF_BUILD_FLAGS="${ARM_TF_BUILD_FLAGS/HANDLE_EA_EL3_FIRST=1/}"
	ARM_TF_BUILD_FLAGS="${ARM_TF_BUILD_FLAGS/SDEI_SUPPORT=1/}"

	# Disable RAS extension on UEFI build
	var=UEFI_PLAT_$PLATFORM[defines]
	EDK2_VAR=${!var}
	EDK2_VAR="${EDK2_VAR/-D EDK2_ENABLE_GHES_MM/}"
	EDK2_VAR="${EDK2_VAR/-D EDK2_ENABLE_FIRMWARE_FIRST/}"
	EDK2_VAR="${EDK2_VAR/-D EDK2_ERROR_INJ_EN/}"
	EDK2_VAR="${EDK2_VAR/-D EDK2_ENABLE_RAS=1/}"
	eval "UEFI_PLAT_$PLATFORM[defines]=\"$EDK2_VAR\""

	echo "BUILD_SCRIPTS="$BUILD_SCRIPTS
}

parse_params() {
	#Parse the named parameters
	while getopts "p:" opt; do
		case $opt in
			p)
				ARM_PLATFORM="$OPTARG"
				;;
		esac
	done

	#The clean/build/package/all should be after the other options
	#So grab the parameters after the named param option index
	BUILD_CMD=${@:$OPTIND:1}

	#Ensure that the platform is supported
	if [ -z "$ARM_PLATFORM" ] ; then
		__print_usage
	fi
	platform=platforms_$refinfra[$ARM_PLATFORM]
	if [ -z "${!platform}" ] ; then
		echo "[ERROR] Could not deduce which platform to build."
		__print_supported_platforms_$refinfra
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
set -- "-p $ARM_PLATFORM -f none $BUILD_CMD"
source ./build-scripts/build-all.sh
