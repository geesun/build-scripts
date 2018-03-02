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
# SCP_BUILD_ENABLED - Flag to enable building SCP
# SCP_PATH - sub-directory containing SCP code
# SCP_ARM_COMPILER_PATH - PATH to ARMCC compiler binaries, not needed if
#			SCP_GCC_COMPILER_PREFIX is used.
# SCP_GCC_COMPILER_PREFIX - Prefix for gcc binaries
# SCP_PLATFORMS - List of images to build in format <PLATFORM>-<PLAT>
# SCP_BUILD_MODE - release or debug
# SCP_BYPASS_ROM_SUPPORT - Mapping of platforms that require bypass ROM support

do_build ()
{
	if [ "$SCP_BUILD_ENABLED" == "1" ]; then
		pushd $TOP_DIR/$SCP_PATH
		PATH=$SCP_ARM_COMPILER_PATH:$PATH
		for item in $SCP_PLATFORMS; do
			p1=${item%%_*}
			p2=${item#*_}
			local outdir=$TOP_DIR/$SCP_PATH/output/$item
			mkdir -p ${outdir}

			local COMPILER_OPTIONS=""
			if [ ! -z "$SCP_GCC_COMPILER_PREFIX" ] ; then
				COMPILER_OPTIONS="TOOLCHAIN=GCC GCC32_TOOLCHAIN=$SCP_GCC_COMPILER_PREFIX"
			fi

			make -j $PARALLELISM PLATFORM=$p1 PLAT=$p2 MODE=$SCP_BUILD_MODE ${COMPILER_OPTIONS}

			if [ "${SCP_BYPASS_ROM_SUPPORT[$p1]}" = true ]; then
				make -j $PARALLELISM PLATFORM=$p1 PLAT=$p2 MODE=$SCP_BUILD_MODE ${COMPILER_OPTIONS} scp-bypassrom
			fi
			cp -r build/artefacts/* ${outdir}/
		done
		popd
	fi
}

do_clean ()
{
	if [ "$SCP_BUILD_ENABLED" == "1" ]; then
		pushd $TOP_DIR/$SCP_PATH
		for item in $SCP_PLATFORMS; do
			p1=${item%%_*}
			p2=${item#*_}
			local outdir=$TOP_DIR/$SCP_PATH/output/$item
			make PLATFORM=$p1 clean
			rm -rf ${outdir}
		done
		popd
	fi
}

do_package ()
{
	for plat in $SCP_PLATFORMS; do
		if [ "$SCP_BUILD_ENABLED" == "1" ]; then
			pushd $TOP_DIR
				p1=${plat%%_*}
				mkdir -p ${OUTDIR}/${plat}
				cp ./${SCP_PATH}/output/${plat}/scp/ramfw.bin ${OUTDIR}/${plat}/scp-ram.bin
				cp ./${SCP_PATH}/output/${plat}/scp/romfw.bin ${OUTDIR}/${plat}/scp-rom.bin
				if [ -d ${TOP_DIR}/${SCP_PATH}/output/${plat}/mcp ]; then
					cp ./${SCP_PATH}/output/${plat}/mcp/ramfw.bin ${OUTDIR}/${plat}/mcp-ram.bin
					cp ./${SCP_PATH}/output/${plat}/mcp/romfw.bin ${OUTDIR}/${plat}/mcp-rom.bin
				fi

				if [ "${SCP_BYPASS_ROM_SUPPORT[$p1]}" = true ]; then
					cp ./${SCP_PATH}/output/${plat}/scp/romfw_bypass.bin ${OUTDIR}/${plat}/scp-rom-bypass.bin
				fi
			popd
		else

			mkdir -p ${OUTDIR}/${plat}
			local var=SCP_PREBUILT_RAMFW_${plat}
			local fw=${!var}
			if [ -e "$fw" ]; then
				cp $fw ${OUTDIR}/${plat}/scp-ram.bin
			fi
			var=SCP_PREBUILT_ROMFW_${plat}
			fw=${!var}
			if [ -e "$fw" ]; then
				cp ${fw} ${OUTDIR}/${plat}/scp-rom.bin
			fi
			var=SCP_PREBUILT_ROMFW_BYPASS_${plat}
			fw=${!var}
			if [ -e "$fw" ]; then
				cp ${fw} ${OUTDIR}/${plat}/scp-rom-bypass.bin
			fi
			#MCP
			set -x
			local mcp_var=MCP_PREBUILT_RAMFW_${plat}
			local mcp_fw=${!mcp_var}
			if [ -e "$mcp_fw" ]; then
				cp $mcp_fw ${OUTDIR}/${plat}/mcp-ram.bin
			fi
			mcp_var=MCP_PREBUILT_ROMFW_${plat}
			mcp_fw=${!mcp_var}
			if [ -e "$mcp_fw" ]; then
				cp ${mcp_fw} ${OUTDIR}/${plat}/mcp-rom.bin
			fi
			mcp_var=MCP_PREBUILT_ROMFW_BYPASS_${plat}
			mcp_fw=${!mcp_var}
			if [ -e "$mcp_fw" ]; then
				cp ${mcp_fw} ${OUTDIR}/${plat}/mcp-rom-bypass.bin
			fi
		fi
	done
}

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $DIR/framework.sh $@
