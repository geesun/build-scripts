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
		"g++-multilib"
		"gcc-multilib"
		"gcc-6"
		"g++-6"
		"genext2fs"
		"gperf"
		"libc6:i386"
		"libstdc++6:i386"
		"libncurses5:i386"
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
		"gcc-aarch64-linux-gnu"
)

###########################################################################
# List of packages which would need to be installed via "apt-get install" #
# for enterprise platform only. This list should not include any package  #
# which is specific to any test or filesystem.                            #
###########################################################################
APT_PACKAGES_ENTERPRISE=(
		"uuid-dev"
		"wget"
		"zlib1g:i386"
		"zlib1g-dev:i386"
		"zip"
		"mtools"
		"fuseext2"
		"autoconf"
		"locales"
		"sbsigntool"
		"pkg-config"
		"gdisk"
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
	# Get the list of packages to be installed
	APT_PACKAGES_TO_INSTALL+=( "${APT_PACKAGES_COMMON[@]}" )
	APT_PACKAGES_TO_INSTALL+=( "${APT_PACKAGES_ENTERPRISE[@]}" )

	# Enable all the standard Ubuntu repositories
	echo -ne "\nAdding required Ubuntu repositories to apt list..."
	sudo add-apt-repository main > $LOGFILE 2>&1
	sudo add-apt-repository universe >> $LOGFILE 2>&1
	sudo add-apt-repository restricted >> $LOGFILE 2>&1
	sudo add-apt-repository multiverse >> $LOGFILE 2>&1
	sudo add-apt-repository ppa:ubuntu-toolchain-r/test -y 2>&1
	echo >> $LOGFILE 2>&1
	echo -e "${BOLD}${GREEN}done${NORMAL}"

	# Add 'i386'  to dpkg architecture list
	sudo dpkg --add-architecture i386 >> $LOGFILE 2>&1
	echo >> $LOGFILE 2>&1

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
#  Function: install_gcc_toolchain                                         #
#  Description: Download and install GCC toolchain into tools/gcc path     #
#                                                                          #
############################################################################
function install_gcc_toolchain()
{
	# Create the target path if not present
	mkdir -p tools/gcc
	pushd tools/gcc

	echo
	echo -ne "Downloading gcc-10.2 toolchain..."
	echo

	# Download the toolchain and the checksum files from developer.arm.com
	wget https://developer.arm.com/-/media/Files/downloads/gnu-rm/10-2020q4/gcc-arm-none-eabi-10-2020-q4-major-x86_64-linux.tar.bz2 &
	wget https://developer.arm.com/-/media/Files/downloads/gnu-a/10.2-2020.11/binrel/gcc-arm-10.2-2020.11-x86_64-aarch64-none-linux-gnu.tar.xz &
	wget https://developer.arm.com/-/media/Files/downloads/gnu-a/10.2-2020.11/binrel/gcc-arm-10.2-2020.11-x86_64-aarch64-none-linux-gnu.tar.xz.asc?revision=9209a723-af18-46c9-9c3e-3d2e3572e220&la=en&hash=15703A3D3E2735F069EA1282363247724E92E216 &

	# Wait for the download to complete
	wait

	# verify the md5 checksum for the downloaded tar files
	if md5sum -c gcc-arm-10.2-2020.11-x86_64-aarch64-none-linux-gnu.tar.xz.asc?revision=9209a723-af18-46c9-9c3e-3d2e3572e220
	then
		echo
		echo -ne "Extracting ..."
		echo

		# Extract the toolchain
		tar -xf gcc-arm-none-eabi-10-2020-q4-major-x86_64-linux.tar.bz2
		tar -xf gcc-arm-10.2-2020.11-x86_64-aarch64-none-linux-gnu.tar.xz

		echo
		echo -e "${BOLD}${GREEN}GCC 10.2 toolchain setup complete${NORMAL}\n"
		echo
	else
		echo
		echo -e "${BOLD}${RED}GCC 10.2 md5checksum failed! Please execute the install_prerequistes.sh script again.${NORMAL}\n"
		echo
	fi

	# Remove the downloaded files
	rm gcc-arm-10.2-2020.11-x86_64-aarch64-none-linux-gnu.tar.xz.asc?revision=9209a723-af18-46c9-9c3e-3d2e3572e220 \
		gcc-arm-none-eabi-10-2020-q4-major-x86_64-linux.tar.bz2 \
		gcc-arm-10.2-2020.11-x86_64-aarch64-none-linux-gnu.tar.xz

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

	echo -e "\nInstalltion of prerequisites started on \
${NORMAL} ${BOLD}${BLUE}`date`${NORMAL}\n"

	prepare_resources

	echo -e "\nInstalling Required Packages:\n\n"
	install_package

	echo -e "\n Installing CMake - \n\n"
	pip install scikit-build >> $LOGFILE 2>&1
	python -m pip install --upgrade pip >> $LOGFILE 2>&1
	pip install cmake --upgrade >> $LOGFILE 2>&1
	echo -e "${BOLD}${GREEN}done${NORMAL}"

	ARCH_VERSION=$(uname -m)
	if [ "$ARCH_VERSION" ==  "x86_64" ]; then
		echo -e "\nInstalling toolchain:\n\n"
		install_gcc_toolchain
	fi

	echo -e "\nInstalling OpenSSL 3.0:\n\n"
	install_openssl3_0

	echo -e "\nInstalltion of prerequisites ended at \
${NORMAL} ${BOLD}${BLUE}`date`${NORMAL}\n"

	shutdown $?

#end of main
