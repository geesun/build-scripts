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
# OUTDIR - output dir for final packaging
# TOP_DIR - workspace root directory
# OPTEE_ARCH - OPTEE OS execution mode
# OPTEE_BUILD_ENABLED - Flag to enable building optee
# OPTEE_OS_PATH - path to optee os code
# OPTEE_PLATFORM - Platform for which to build optee for
# OPTEE_PLATFORM_FLAVOR - Platform flavour for optee build
# OPTEE_OS_CROSS_COMPILE - gcc for compiling tee (optee os)
# OPTEE_OS_BIN_NAME - name of the optee os executable bin
# OPTEE_CORE_LOG_LEVEL - 1-> least debug logs, 4-> most debug logs

do_build ()
{
	if [ "$OPTEE_BUILD_ENABLED" == "1" ]; then
		#setup the environment
		#only aarch32 mode supported currently for optee execution
		if [ "$OPTEE_ARCH" ==  "aarch32" ]; then
			echo "Building OPTEE for $PLATFORM_FLAVOR"
			export CROSS_COMPILE=$OPTEE_OS_CROSS_COMPILE
			export PLATFORM=$OPTEE_PLATFORM
			export PLATFORM_FLAVOR=$OPTEE_PLATFORM_FLAVOUR
			export CFG_TEE_CORE_LOG_LEVEL=$OPTEE_CORE_LOG_LEVEL
		else
			echo
			echo "OPTEE: unsupported ARCH"
			echo
			exit 1;
		fi

		pushd $TOP_DIR/$OPTEE_OS_PATH
		make -j$PARALLELISM
		## temp patch: to be fixed by proper memory mapping of TEE
		${CROSS_COMPILE}objcopy -O binary out/arm-plat-${PLATFORM}/core/tee.elf out/arm-plat-${PLATFORM}/core/tee.bin
		popd
	fi
}

do_clean ()
{
	if [ "$OPTEE_BUILD_ENABLED" == "1" ]; then
		pushd $TOP_DIR/$OPTEE_OS_PATH
		make clean
	fi
}

do_package ()
{
	if [ "$OPTEE_BUILD_ENABLED" == "1" ]; then
		pushd $TOP_DIR/$OPTEE_OS_PATH
		for plat in $ARM_TF_PLATS; do
			mkdir -p ${OUTDIR}/$plat
			cp out/arm-plat-${OPTEE_PLATFORM}/core/${OPTEE_OS_BIN_NAME}  ${OUTDIR}/$plat/tf-bl32.bin
		done
		popd
	fi
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $1 $2
