#!/usr/bin/env bash

# Copyright (c) 2015-2021, ARM Limited and Contributors. All rights reserved.
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
# SCP_PLATFORMS - List of images to build in format <PLATFORM>-<PLAT>
# SCP_BUILD_MODE - release or debug
# SCP_BYPASS_ROM_SUPPORT - Mapping of platforms that require bypass ROM support

# cmake build support is experimental. Set this variable to '1' to enable cmake build.
CMAKE_BUILD=1

check_cmsis_source ()
{
	# Check whether the cmsis submodule has been fetched, if not
	# fetch it
	if [[ -d "$TOP_DIR/$SCP_PATH" ]]; then
		pushd $TOP_DIR/$SCP_PATH
		echo "Fetching cmsis submodule for SCP build ... "
		git submodule update --init
		popd
	fi
}

do_build ()
{
	if [ "$SCP_BUILD_ENABLED" == "1" ]; then

		check_cmsis_source
		local prd_build_params="";

		pushd $TOP_DIR/$SCP_PATH
		PATH=$SCP_ARM_COMPILER_PATH:$PATH

		if [ $CMAKE_BUILD -eq 1 ]; then
			if [ -d "cmake-build" ]; then
				rm -r cmake-build
				mkdir -p cmake-build
			fi
		fi

		for item in $SCP_PLATFORMS; do
			if [ $CMAKE_BUILD -eq 1 ]; then
				# Build using cmake
				if [ ! -z "$SCP_PLATFORM_VARIANT" ]; then
					prd_build_params="-DSCP_PLATFORM_VARIANT=$SCP_PLATFORM_VARIANT"
				fi

				for scp_fw in mcp_romfw scp_romfw scp_ramfw; do
					echo
					echo "====================================================="
					echo "Building $scp_fw [`date`] ....."
					echo "====================================================="
					echo

					local outdir=$TOP_DIR/$SCP_PATH/output
					if [ -z "$SCP_PLATFORM_VARIANT" ]; then
						vpath="$item"
					else
						vpath="$item/$SCP_PLATFORM_VARIANT"
					fi

					mkdir -p ${outdir}/$vpath

					mkdir -p cmake-build/"$item/$scp_fw"
					cmake -S "." -B "./cmake-build/$item/$scp_fw" \
						-DSCP_TOOLCHAIN:STRING="GNU" \
						-DCMAKE_BUILD_TYPE=$SCP_BUILD_MODE \
						-DSCP_FIRMWARE_SOURCE_DIR:PATH="$item/$scp_fw" \
						-DCMAKE_C_COMPILER=${SCP_COMPILER_PATH}/arm-none-eabi-gcc \
						-DCMAKE_ASM_COMPILER=${SCP_COMPILER_PATH}/arm-none-eabi-gcc \
						$prd_build_params

					echo
					echo echo cmake --build "./cmake-build/$item/$scp_fw" --parallel $PARALLELISM
					echo
					cmake --build "./cmake-build/$item/$scp_fw" --parallel $PARALLELISM

					pushd cmake-build/$item/$scp_fw
					case $scp_fw in
						mcp_romfw)
							mv "bin/"$item-mcp-bl1.bin""  "bin/"$scp_fw.bin""
							 ;;
						scp_romfw)
							mv "bin/"$item-bl1.bin""  "bin/"$scp_fw.bin""
							;;
						scp_ramfw)
							mv "bin/"$item-bl2.bin""  "bin/"$scp_fw.bin""
							;;
					esac
					popd
				done
				cp -r cmake-build/$item/* ${outdir}/$vpath
			else # !$CMAKE_BUILD
				# Build using make
				local outdir=$TOP_DIR/$SCP_PATH/output
				if [ -z "$SCP_PLATFORM_VARIANT" ]; then
					vpath="$item"
				else
					vpath="$item/$SCP_PLATFORM_VARIANT"
				fi

				mkdir -p ${outdir}/$vpath

				if [ ! -z "$SCP_PRODUCT_BUILD_PARAMS" ]; then
					prd_build_params="PRODUCT_BUILD_PARAMS=$SCP_PRODUCT_BUILD_PARAMS"
				fi

				# Convert build mode to lower case, make build requires it.
				SCP_BUILD_MODE="${SCP_BUILD_MODE,,}"
				make -j $PARALLELISM PRODUCT=$item $prd_build_params MODE=$SCP_BUILD_MODE CC=${SCP_COMPILER_PATH}/arm-none-eabi-gcc
				cp -r build/product/$item/* ${outdir}/$vpath
			fi
		done
		popd
	fi
}

do_clean ()
{
	if [ "$SCP_BUILD_ENABLED" == "1" ]; then
		pushd $TOP_DIR/$SCP_PATH
		for item in $SCP_PLATFORMS; do
			if [ -z "$SCP_PLATFORM_VARIANT" ]; then
				vpath="$item"
			else
				vpath="$item/$SCP_PLATFORM_VARIANT"
			fi
			local outdir=$TOP_DIR/$SCP_PATH/output/$vpath

			if [ $CMAKE_BUILD -eq 1 ]; then
				# Build using cmake
				rm -rf $TOP_DIR/$SCP_PATH/cmake-build/$item
			else
				# Build using make
				make PLATFORM=$item clean
			fi
			rm -rf ${outdir}
		done
		popd
	fi
}

do_package ()
{
	for plat in $SCP_PLATFORMS; do
		if [ "$SCP_BUILD_ENABLED" == "1" ]; then
			if [ -z "$SCP_PLATFORM_VARIANT" ]; then
			   vpath="$plat"
			else
			   vpath="$plat/$SCP_PLATFORM_VARIANT"
			fi
			pushd $TOP_DIR
			mkdir -p ${OUTDIR}/${plat}

				if [ $CMAKE_BUILD -eq 1 ]; then
					# Build using cmake
					for scp_fw in mcp_romfw scp_romfw scp_ramfw; do
						cp ./${SCP_PATH}/output/$vpath/$scp_fw/bin/"$scp_fw.bin" ${OUTDIR}/${plat}
					done
				else
					# Build using make

					# Convert build mode to lower case, make build requires it.
					SCP_BUILD_MODE="${SCP_BUILD_MODE,,}"

					cp ./${SCP_PATH}/output/$vpath/scp_ramfw/${SCP_BUILD_MODE}/bin/scp_ramfw.bin ${OUTDIR}/${plat}/
					cp ./${SCP_PATH}/output/$vpath/scp_romfw/${SCP_BUILD_MODE}/bin/scp_romfw.bin ${OUTDIR}/${plat}/

					if [ -d ${SCP_PATH}/output/$vpath/mcp_romfw ]; then
						cp ./${SCP_PATH}/output/$vpath/mcp_romfw/${SCP_BUILD_MODE}/bin/mcp_romfw.bin ${OUTDIR}/${plat}/
					fi

					if [ -d ${SCP_PATH}/output/$vpath/mcp_ramfw ]; then
						cp ./${SCP_PATH}/output/$vpath/mcp_ramfw/${SCP_BUILD_MODE}/bin/mcp_ramfw.bin ${OUTDIR}/${plat}/
					fi
				fi

				if [[ "${SCP_BYPASS_ROM_SUPPORT[$plat]}" = true ]]; then
					cp ./${SCP_PATH}/output/$vpath/scp/romfw_bypass.bin ${OUTDIR}/${plat}/scp-rom-bypass.bin
				fi
			popd
		else
			mkdir -p ${OUTDIR}/${plat}
			local var=SCP_PREBUILT_RAMFW_${plat}
			local fw=${!var}
			if [ -e "$fw" ]; then
				cp $fw ${OUTDIR}/${plat}/scp_ramfw.bin
			fi
			var=SCP_PREBUILT_ROMFW_${plat}
			fw=${!var}
			if [ -e "$fw" ]; then
				cp ${fw} ${OUTDIR}/${plat}/scp_romfw.bin
			fi
			var=SCP_PREBUILT_ROMFW_BYPASS_${plat}
			fw=${!var}
			if [ -e "$fw" ]; then
				cp ${fw} ${OUTDIR}/${plat}/scp-rom-bypass.bin
			fi

			#MCP
			local mcp_var=MCP_PREBUILT_RAMFW_${plat}
			mcp_fw=${!mcp_var}
			if [ -e "$mcp_fw" ]; then
				cp ${mcp_fw} ${OUTDIR}/${plat}/mcp_ramfw.bin
			fi
			mcp_var=MCP_PREBUILT_ROMFW_${plat}
			mcp_fw=${!mcp_var}
			if [ -e "$mcp_fw" ]; then
				cp ${mcp_fw} ${OUTDIR}/${plat}/mcp_romfw.bin
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
