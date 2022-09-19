#!/usr/bin/env bash

# Copyright (c) 2019-2022, ARM Limited and Contributors. All rights reserved.
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

############################################################################
#                                                                          #
#  Global Variables                                                        #
#                                                                          #
############################################################################

RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NORMAL='\033[0m'
CYAN='\033[0;36m'
LPURPLE='\033[1;35m'

############################################################################
# List of packages which would need to be installed via "apt-get install"  #
# for all the platforms. This list should not include any package which is #
# specific to any test or filesystem.                                      #
############################################################################
APT_PACKAGES_COMMON=(
		"git"
		"acpica-tools"
		"bc"
		"bison"
		"build-essential"
		"curl"
		"flex"
		"genext2fs"
		"gperf"
		"libxml2"
		"libxml2-dev"
		"libxml2-utils"
		"libxml-libxml-perl"
		"make"
		"openssh-server"
		"openssh-client"
		"expect"
		"bridge-utils"
		"python"
		"python3-pip"
		"device-tree-compiler"
		"autopoint"
		"doxygen"
		"xterm"
		"ninja-build"
		"python3-distutils"
		"uuid-dev"
		"wget"
		"zip"
		"mtools"
		"autoconf"
		"locales"
		"sbsigntool"
		"pkg-config"
		"gdisk"
)

############################################################################
# List of packages which would need to be installed via "apt-get install"  #
# for x86 host machines. This list should not include any package which is #
# specific to any test or filesystem.                                      #
############################################################################
APT_PACKAGES_x86=(
		"g++-multilib"
		"gcc-multilib"
		"gcc-6"
		"g++-6"
		"gcc-aarch64-linux-gnu"
		"libc6:i386"
		"libstdc++6:i386"
		"libncurses5:i386"
		"fuseext2"
		"zlib1g:i386"
		"zlib1g-dev:i386"
)

############################################################################
# List of packages which would need to be installed via "apt-get install"  #
# for arm64 host machines. This list should not include any package which  #
# is specific to any test or filesystem.                                   #
############################################################################
APT_PACKAGES_arm64=(
		"libc6:arm64"
		"libstdc++6:arm64"
		"libncurses5:arm64"
		"zlib1g:arm64"
		"zlib1g-dev:arm64"
		"gcc-arm-none-eabi"
)

LOGFILE="./refinfra_pkg_install.log"

APT_PACKAGES_TO_INSTALL=( )
APT_PACKAGES_FAILED=( )

RC_ERROR=1
RC_SUCCESS=0

###########################################################################
#                                                                         #
#  Function: prepare_resources                                            #
#  Description: set-up resources required for installing packages         #
#                                                                         #
###########################################################################
function prepare_resources()
{
	ARCH_VERSION=$(uname -m)

	# Get the list of packages to be installed
	APT_PACKAGES_TO_INSTALL+=( "${APT_PACKAGES_COMMON[@]}" )
	if [ "$ARCH_VERSION" ==  "x86_64" ]; then
		APT_PACKAGES_TO_INSTALL+=( "${APT_PACKAGES_x86[@]}" )
	else
		APT_PACKAGES_TO_INSTALL+=( "${APT_PACKAGES_arm64[@]}" )
	fi

	# Enable all the standard Ubuntu repositories
	echo -ne "\nAdding required Ubuntu repositories to apt list..."
	sudo add-apt-repository main > $LOGFILE 2>&1
	sudo add-apt-repository universe >> $LOGFILE 2>&1
	sudo add-apt-repository restricted >> $LOGFILE 2>&1
	sudo add-apt-repository multiverse >> $LOGFILE 2>&1
	sudo add-apt-repository ppa:ubuntu-toolchain-r/test -y 2>&1
	echo >> $LOGFILE 2>&1
	echo -e "${BOLD}${GREEN}done${NORMAL}"

	if [ "$ARCH_VERSION" ==  "x86_64" ]; then
		# Add 'i386'  to dpkg architecture list
		sudo dpkg --add-architecture i386 >> $LOGFILE 2>&1
		echo >> $LOGFILE 2>&1
	else
		# Add 'arm64'  to dpkg architecture list
		sudo dpkg --add-architecture arm64 >> $LOGFILE 2>&1
		echo >> $LOGFILE 2>&1
	fi

	# Update package list
	echo -ne "\nUpdating apt list..."
	sudo apt-get update >> $LOGFILE 2>&1
	echo >> $LOGFILE 2>&1
	echo -e "${BOLD}${GREEN}done${NORMAL}"
}

###########################################################################
#                                                                         #
#  Function: install_package                                              #
#  Description: Install required packages on the build machine            #
#                                                                         #
###########################################################################
function install_package()
{
	i=1
	n=${#APT_PACKAGES_TO_INSTALL[@]}
	for pack in "${APT_PACKAGES_TO_INSTALL[@]}"
	do
		echo -ne "${BOLD}${CYAN}[$i/$n]${NORMAL} Installing '$pack' - "
		echo >> $LOGFILE 2>&1
		# Install the package
		sudo apt-get install -y $pack >> $LOGFILE 2>&1
		RC=$?
		if [ $RC = $RC_SUCCESS ]
		then
			echo -e "${BOLD}${GREEN}done${NORMAL}\n"
		else
			echo -e "${BOLD}${RED}failed${NORMAL}\n"
			APT_PACKAGES_FAILED+=( "$pack" )
		fi
		((i++))
	done

	if [ ${#APT_PACKAGES_FAILED[@]} -gt 0 ]
	then
		echo -e "\n${BOLD}${RED}Failed to install following packages!${NORMAL} \
Check log file to find the specific reason for failure\n"
		printf '%s\n' "${APT_PACKAGES_FAILED[@]}"
	fi
}

############################################################################
#                                                                          #
#  Function: install_libfdt                                                #
#  Description: Download, build and install LIBFDT into GCC toolchain      #
#                                                                          #
############################################################################
function install_libfdt()
{
	local CC SYSROOT

	# Clone the LIBFDT git repo
	git clone git://git.kernel.org/pub/scm/utils/dtc/dtc.git
	wait

	# Compile and install library
	export CC="${PWD}/${1}gcc"
	SYSROOT=$($CC -print-sysroot)
	pushd dtc
	make clean
	make libfdt
	make DESTDIR=$SYSROOT PREFIX=/usr LIBDIR=/usr/lib/ install-lib install-includes

	# Clean Up
	popd
	rm -rf dtc
}

############################################################################
#                                                                          #
#  Function: install_gcc_toolchain                                         #
#  Description: Download and install GCC toolchain into tools/gcc path     #
#                                                                          #
############################################################################
function install_gcc_toolchain()
{
	echo -e "\nInstalling toolchain:\n\n"

	# Create the target path if not present
	mkdir -p tools/gcc
	pushd tools/gcc

	echo
	echo -ne "Downloading gcc-11.2 toolchain..."
	echo

	# Download the toolchain and the checksum files from developer.arm.com
	# AArch32 bare-metal target (arm-none-eabi)
	wget https://developer.arm.com/-/media/Files/downloads/gnu/11.2-2022.02/binrel/gcc-arm-11.2-2022.02-x86_64-arm-none-eabi.tar.xz &
	wget https://developer.arm.com/-/media/Files/downloads/gnu/11.2-2022.02/binrel/gcc-arm-11.2-2022.02-x86_64-arm-none-eabi.tar.xz.asc &

	#  AArch64 GNU/Linux target (aarch64-none-linux-gnu)
	wget https://developer.arm.com/-/media/Files/downloads/gnu/11.2-2022.02/binrel/gcc-arm-11.2-2022.02-x86_64-aarch64-none-linux-gnu.tar.xz &
	wget https://developer.arm.com/-/media/Files/downloads/gnu/11.2-2022.02/binrel/gcc-arm-11.2-2022.02-x86_64-aarch64-none-linux-gnu.tar.xz.asc &

	# Wait for the download to complete
	wait

	# Command to verify the MD5 hash
	VERIFY_TOOLCHAIN_1="md5sum -c gcc-arm-11.2-2022.02-x86_64-arm-none-eabi.tar.xz.asc"
	VERIFY_TOOLCHAIN_2="md5sum -c gcc-arm-11.2-2022.02-x86_64-aarch64-none-linux-gnu.tar.xz.asc"

	# verify the md5 checksum for the downloaded tar files
	if $VERIFY_TOOLCHAIN_1 && $VERIFY_TOOLCHAIN_2
	then
		echo
		echo -ne "Extracting ..."
		echo

		# Extract the toolchain
		tar -xf gcc-arm-11.2-2022.02-x86_64-arm-none-eabi.tar.xz
		tar -xf gcc-arm-11.2-2022.02-x86_64-aarch64-none-linux-gnu.tar.xz

		echo
		echo -e "${BOLD}${GREEN}GCC 11.2 toolchain setup complete${NORMAL}\n"
		echo

		echo
		echo -ne "Installing LIBFDT library ..."
		echo

		# Install LIBFDT library for GCC 11.2
		install_libfdt "gcc-arm-11.2-2022.02-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-"

		echo
		echo -e "${BOLD}${GREEN}LIBFDT library installation complete${NORMAL}\n"
		echo
	else
		echo
		echo -e "${BOLD}${RED}GCC 11.2 md5checksum failed! Please execute the install_prerequistes.sh script again.${NORMAL}\n"
		echo
	fi

	# Remove the downloaded files
	rm gcc-arm-11.2-2022.02-x86_64-arm-none-eabi.tar.xz
	rm gcc-arm-11.2-2022.02-x86_64-arm-none-eabi.tar.xz.asc
	rm gcc-arm-11.2-2022.02-x86_64-aarch64-none-linux-gnu.tar.xz
	rm gcc-arm-11.2-2022.02-x86_64-aarch64-none-linux-gnu.tar.xz.asc
	popd
}

############################################################################
#                                                                          #
#  Function: install_openssl3_0                                            #
#  Description: Download and install openssl3_0                            #
#                                                                          #
############################################################################
function install_openssl3_0()
{
	#uninstall existing libssl-dev
	apt-get remove -y libssl-dev

	# Install OpenSSL 3.0
	TOOLS_DIR=/tmp
	OPENSSL_VER="3.0.2"
	OPENSSL_DIRNAME="openssl-${OPENSSL_VER}"
	OPENSSL_FILENAME="openssl-${OPENSSL_VER}"
	OPENSSL_CHECKSUM="98e91ccead4d4756ae3c9cde5e09191a8e586d9f4d50838e7ec09d6411dfdb63"

	curl --connect-timeout 5 --retry 5 --retry-delay 1 --create-dirs \
		-fsSLo /tmp/${OPENSSL_FILENAME}.tar.gz \
		https://www.openssl.org/source/${OPENSSL_FILENAME}.tar.gz
	echo "${OPENSSL_CHECKSUM}  /tmp/${OPENSSL_FILENAME}.tar.gz" | \
		sha256sum -c
	mkdir -p ${TOOLS_DIR}/${OPENSSL_DIRNAME} && tar -xzf \
		/tmp/${OPENSSL_FILENAME}.tar.gz \
		-C ${TOOLS_DIR}/${OPENSSL_DIRNAME} --strip-components=1
	cd ${TOOLS_DIR}/${OPENSSL_DIRNAME}
	./Configure --libdir=lib --prefix=/usr --api=1.0.1
	cd ${TOOLS_DIR}
	make -j${nproc} -C ${TOOLS_DIR}/${OPENSSL_DIRNAME}
	make -C ${TOOLS_DIR}/${OPENSSL_DIRNAME} install
}

############################################################################
#                                                                          #
#  Function: shutdown                                                      #
#  Description: Handle untrapping trapped signals and output of the final  #
#               return code from the script.                               #
#                                                                          #
############################################################################
function shutdown()
{
	trap '' 1 2 3 15

	exit $1
}

############################################################################
#                                                                          #
#  Function: install_fvp_dependencies                                      #
#  Description: Install any packages required to use the FVP.              #
#                                                                          #
############################################################################
function install_fvp_dependencies()
{
	sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
	sudo apt upgrade -y libstdc++6
}

############################################################################
#                                                                          #
#  Function: install_cmake                                                 #
#  Description: Install cmake for the platform                             #
#                                                                          #
############################################################################
function install_cmake()
{
	echo -e "\n Installing CMake - \n\n"

	ARCH_VERSION=$(uname -m)
	if [ "$ARCH_VERSION" ==  "x86_64" ]; then
		pip install scikit-build >> $LOGFILE 2>&1
		python -m pip install --upgrade pip >> $LOGFILE 2>&1
		pip install cmake --upgrade >> $LOGFILE 2>&1
	else
		mkdir /tmp/cmake_build
		pushd /tmp/cmake_build
		wget https://github.com/Kitware/CMake/releases/download/v3.24.1/cmake-3.24.1.tar.gz
		tar xf cmake-3.24.1.tar.gz
		cd cmake-3.24.1
		./configure
		make -j${nproc}
		make -j${nproc} install
		popd
		sudo rm -Rf /tmp/cmake_build
	fi

	echo -e "${BOLD}${GREEN}done${NORMAL}"
}

############################################################################
#                                                                          #
#  Function:     main                                                      #
#  Description:  Entry point for the script.                               #
#                                                                          #
############################################################################

	trap 'shutdown' 1 2 3 15

	# Check for 'root' permission
	if [[ $EUID -ne 0 ]]
	then
		echo -e "\n'sudo' privilege is required to install pre-requisite packages\n"
		shutdown $RC_ERROR
	fi

	if [ ! -f $LOGFILE ]
	then
		/bin/touch $LOGFILE &>/dev/null
	fi
	echo "LOGFILE is $LOGFILE"

	echo -e "\nInstalltion of prerequisites started on "
	echo -e "${NORMAL} ${BOLD}${BLUE}`date`${NORMAL}\n"

	prepare_resources

	echo -e "\nInstalling Required Packages:\n\n"
	install_package

	ARCH_VERSION=$(uname -m)
	if [ "$ARCH_VERSION" ==  "x86_64" ]; then
		install_gcc_toolchain
	fi

	echo -e "\nInstalling OpenSSL 3.0:\n\n"
	install_openssl3_0

	#install cmake
	install_cmake

	echo -e "\nInstalling FVP dependencies \n\n"
	install_fvp_dependencies

	echo -e "\nInstalltion of prerequisites ended at "
	echo -e "${NORMAL} ${BOLD}${BLUE}`date`${NORMAL}\n"

	shutdown $?

#end of main
