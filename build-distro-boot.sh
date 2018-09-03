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

declare -A sgi_platforms
sgi_platforms[sgi575]=1

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
	echo "Usage: ./build-scripts/build-distro-boot.sh -p <platform> <command>"
	echo
	echo "build-distro-boot.sh: Builds the SGI platform software stack with all the"
	echo "required software components that allows a enterprise linux distribution"
	echo "to be installed on a disk"
	echo
	__print_supported_sgi_platforms
	echo "Supported build commands are - clean/build/package/all"
	echo
	echo "Example 1: ./build-scripts/build-distro-boot.sh -p sgi575 all"
	echo "    This command builds the required software components of the SGI575"
	echo "    platform that allow a enterprise linux distribution to be installed"
	echo "    to a disk"
	echo
	echo "Example 2: ./build-scripts/build-distro-boot.sh -p sgi575 clean"
	echo "    This command cleans the previous build of the sgi575 platform software stack"
	echo
	exit
}

#callback from build-all.sh to override any build config
__do_override_build_configs()
{
	echo "build-distro-boot.sh: overriding BUILD_SCRIPTS"
	BUILD_SCRIPTS="build-arm-tf.sh build-uefi.sh build-scp.sh build-target-bins.sh "
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
set -- "-p $SGI_PLATFORM -f none $BUILD_CMD"
source ./build-scripts/build-all.sh

echo
echo "./build-distro-boot.sh: build completed successfully!"
echo "-----------------------------------------------------"
echo
