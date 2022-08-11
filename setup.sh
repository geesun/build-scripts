#!/bin/bash

# Copyright (c) 2022, Arm Limited. All rights reserved.
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

SCRIPT_DIR="$(realpath --no-symlinks "$(dirname "${BASH_SOURCE[0]}")")"

if [[ -z $PLATFORM ]]; then
    echo "\$PLATFORM not specified. Please specify a platform."
    echo "Platform options:"
    echo "    - tc2"
    exit 1
fi

if [[ -z "${FILESYSTEM:-}" ]] ; then
    echo "\$FILESYSTEM not specified. Please specify a filesystem."
    echo "Filesystem options:"
    echo "    - buildroot"
    echo "    - android-swr"
    exit 1
fi

# Install toolchains

mkdir -p $SCRIPT_DIR/../tools/

pushd $SCRIPT_DIR/../tools/

mkdir -p downloads

GCC_VERSION="11.2-2022.02"

# Remove obsolete gcc versions
gcc_old=$(find . -type d -name "gcc-arm-*-x86_64-*" \( ! -iname "gcc-arm-$GCC_VERSION-x86_64-*" \))
rm -rf $gcc_old

# Toolchains
if [ ! -d gcc-arm-$GCC_VERSION-x86_64-arm-none-eabi ]; then
    wget https://developer.arm.com/-/media/Files/downloads/gnu/$GCC_VERSION/binrel/gcc-arm-$GCC_VERSION-x86_64-arm-none-eabi.tar.xz -P downloads
    tar xf downloads/gcc-arm-$GCC_VERSION-x86_64-arm-none-eabi.tar.xz
fi
if [ ! -d gcc-arm-$GCC_VERSION-x86_64-aarch64-none-elf ]; then
    wget https://developer.arm.com/-/media/Files/downloads/gnu/$GCC_VERSION/binrel/gcc-arm-$GCC_VERSION-x86_64-aarch64-none-elf.tar.xz -P downloads
    tar xf downloads/gcc-arm-$GCC_VERSION-x86_64-aarch64-none-elf.tar.xz
fi
if [ ! -d gcc-arm-$GCC_VERSION-x86_64-aarch64-none-linux-gnu ]; then
    wget https://developer.arm.com/-/media/Files/downloads/gnu/$GCC_VERSION/binrel/gcc-arm-$GCC_VERSION-x86_64-aarch64-none-linux-gnu.tar.xz -P downloads
    tar xf downloads/gcc-arm-$GCC_VERSION-x86_64-aarch64-none-linux-gnu.tar.xz
fi

# Builds tools
# Cmake v3.22.4
if [ ! -f cmake-3.22.4-linux-x86_64/bin/cmake ]; then
    wget https://github.com/Kitware/CMake/releases/download/v3.22.4/cmake-3.22.4-linux-x86_64.tar.gz -P downloads
    tar xf downloads/cmake-3.22.4-linux-x86_64.tar.gz
fi

# Repo tool
if [ ! command -v repo &>/dev/null ]; then
    curl https://storage.googleapis.com/git-repo-downloads/repo > ~/downloads/repo
    chmod a+x ~/bin/repo
    export PATH=~/bin:$PATH
fi

popd

# OpenSSL 3.0 (needed by TF-A)
OPENSSL_DIR=$SCRIPT_DIR/../tools/openssl

if [ ! -f $OPENSSL_DIR/bin/openssl ]; then

    mkdir $OPENSSL_DIR
    OPENSSL_VER="3.0.2"
    OPENSSL_DIRNAME="openssl-${OPENSSL_VER}"
    OPENSSL_FILENAME="openssl-${OPENSSL_VER}"
    OPENSSL_CHECKSUM="98e91ccead4d4756ae3c9cde5e09191a8e586d9f4d50838e7ec09d6411dfdb63"
    curl --connect-timeout 5 --retry 5 --retry-delay 1 --create-dirs -fsSLo $OPENSSL_DIR/${OPENSSL_FILENAME}.tar.gz \
      https://www.openssl.org/source/${OPENSSL_FILENAME}.tar.gz
    echo "${OPENSSL_CHECKSUM}  $OPENSSL_DIR/${OPENSSL_FILENAME}.tar.gz" | sha256sum -c
    mkdir -p ${OPENSSL_DIR}/${OPENSSL_DIRNAME} && tar -xzf ${OPENSSL_DIR}/${OPENSSL_FILENAME}.tar.gz -C ${OPENSSL_DIR}/${OPENSSL_DIRNAME} --strip-components=1
    pushd ${OPENSSL_DIR}/${OPENSSL_DIRNAME}
    ./Configure --libdir=lib --prefix=$OPENSSL_DIR --api=1.1.1
    popd

    pushd ${OPENSSL_DIR}
    make -C ${OPENSSL_DIR}/${OPENSSL_DIRNAME}
    make -C ${OPENSSL_DIR}/${OPENSSL_DIRNAME} install
    popd
fi


# Create virtual environment
pip3 install virtualenv
VENV_DIR=$SCRIPT_DIR/../tc-venv
if [ ! -f $VENV_DIR/pyvenv.cfg ]; then
    echo "Creating virtual environment...."
    python3 -m virtualenv -p `which python3` $VENV_DIR
fi

source $VENV_DIR/bin/activate

pip3 install --upgrade pip

# U-Boot requirements
pip3 install pyelftools

# RSS requirements
pushd $SCRIPT_DIR/../src/rss
pip3 install -r tools/requirements.txt
popd

# The minimum jinja2 version supported by RSS doesn't work with the latest markupsafe,
# and updating jinja2 will break the Trusted Services build, so the easiest
# solution is to ensure we keep markupsafe to a known working version
pip3 install markupsafe==2.0.1

# Trusted Services requirements
pushd $SCRIPT_DIR/../src/trusted-services
pip3 install -r requirements.txt
popd

# Patch components

# Android has its own thing to do the patching
to_patch=(
    "build-hafnium.sh"
    "build-linux.sh"
    "build-optee-os.sh"
    "build-optee-test.sh"
    "build-scp.sh"
    "build-tfa.sh"
    "build-u-boot.sh"
    "build-trusted-services.sh"
    "build-rss.sh"
)

if [ -d "$SCRIPT_DIR/../src/trusty" ]; then
    to_patch+=(
         "build-trusty.sh"
    )
fi

for component in "${to_patch[@]}"; do
    ./$component patch
done

# Leave python virtual environment
deactivate
