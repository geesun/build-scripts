#!/bin/bash

SCRIPT_DIR="$(realpath --no-symlinks "$(dirname "${BASH_SOURCE[0]}")")"

apt install -y chrpath gawk texinfo diffstat wget git unzip gcc-arm-linux-gnueabihf \
 build-essential socat cpio python3 python3-pip python3-pexpect xz-utils debianutils \
 iputils-ping python3-git libegl1-mesa libsdl1.2-dev xterm git-lfs openssl curl \
 lib32ncurses5-dev libz-dev u-boot-tools m4 zip liblz4-tool zstd make dwarves ninja-build \
 libssl-dev srecord libelf-dev bison flex

# Install ubuntu packages based on ubuntu versions - Refer to the user guide for more info
U_VER_20_04=20.04
U_VER_18_04=18.04
OUT=`lsb_release -a | awk '/Description:/ {print $3}'`
U_VER=`echo $OUT | awk -F '.' '{printf("%0.2d.%0.2d", $1, $2)}'`
echo U_VER=$U_VER
if [ $U_VER == $U_VER_20_04 ];
then
	if [ $(dpkg-query -W -f='${Status}' pylint 2>/dev/null | grep -c "ok installed") -eq 0 ];
	then
		sudo apt install pylint python -y
	fi
elif [ $U_VER == $U_VER_18_04 ];
then
	if [ $(dpkg-query -W -f='${Status}' pylint3 python-pip 2>/dev/null | grep -c "ok installed") -eq 0 ];
	then
		sudo apt install pylint3 python-pip python -y
	fi
fi
