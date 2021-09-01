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
# to endorse or promote products derived from this software without
# specific prior written permission.
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

# [data_url]     : URL to the tar to download and extract
# [checksum_url] : checksum URL. Checked during 'update' and if the contents
#                  have changed it will trigger a new download.
# [sanity_file]  : this file should exist after extraction

readonly -A TOOL_linaro_gcc=(
    [data_url]="https://releases.linaro.org/components/toolchain/binaries/7.5-2019.12/aarch64-linux-gnu/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu.tar.xz"
    [checksum_url]=""
    [sanity_file]="bin/aarch64-linux-gnu-gcc"
    [extract]="yes"
)
readonly -A TOOL_arm_gcc=(
    [data_url]="https://developer.arm.com/-/media/Files/downloads/gnu-rm/9-2020q2/gcc-arm-none-eabi-9-2020-q2-update-x86_64-linux.tar.bz2"
    [checksum_url]=""
    [sanity_file]="bin/arm-none-eabi-gcc"
    [extract]="yes"
)
readonly -A TOOL_ubuntu_bionic=(
    [data_url]="http://cdimage.ubuntu.com/ubuntu-base/bionic/daily/current/bionic-base-arm64.tar.gz"
    [checksum_url]=""
    [sanity_file]=""
    [extract]=""
)
readonly -A TOOL_linuxfirmware=(
    [data_url]="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/rtl_nic/rtl8168g-2.fw?h=20200421"
    [checksum_url]=""
    [sanity_file]=""
    [extract]=""
)
readonly TOOLS=( linaro_gcc arm_gcc ubuntu_bionic linuxfirmware )
readonly DO_DESC_build="download tools if not already downloaded"

do_build() {
    mkdir -p "$WORKSPACE_DIR/tools"
    local tool
    for tool in "${TOOLS[@]}" ; do
        local -n tool_info="TOOL_$tool"
        local tool_dir="tools/$tool"
        if [[ -e "$tool_dir" ]] ; then
            echo "$tool: already extracted"
            continue
        fi

        local work_dir="$PLATFORM_OUT_DIR/intermediates/tools/$tool"
        rm -fr "$work_dir"
        mkdir -p "$work_dir"

        echo "$tool: downloading..."
        {
            echo "${tool_info[data_url]}"
            echo "${tool_info[checksum_url]}"
        } > "$work_dir/url"

        if [[ -n "${tool_info[checksum_url]}" ]] ; then
            wget -O "$work_dir/checksum" "${tool_info[checksum_url]}"
        fi

        local data_file="${tool_info[data_url]##*/}"
        data_file="${data_file%\?*}"
        wget -O "$work_dir/$data_file" "${tool_info[data_url]}"

        if [[ -n "${tool_info[extract]}" ]] ; then
            echo "$tool: extracting..."
            mkdir "$work_dir/extract"
            if ! tar --no-same-owner --no-same-permissions --strip-components=1 -C "$work_dir/extract" -xf "$work_dir/$data_file" ; then
                error_echo "$tool: extraction failed!"
                error_echo "$tool: keeping work directory: $work_dir"
                exit 1
            fi
            if ! [[ -e "$work_dir/extract/${tool_info[sanity_file]}" ]] ; then
                error_echo "$tool: sanity check failed!"
                error_echo "$tool: file does not exist: $sanity_file"
                error_echo "$tool: keeping work directory: $work_dir"
                exit 1
            fi
            mv "$work_dir/url" "tools/.$tool.url"
            if [[ -e "$work_dir/checksum" ]] ; then
                mv "$work_dir/checksum" "tools/.$tool.checksum"
            fi
            mv "$work_dir/extract" "$tool_dir"
            rm -r "$work_dir"
            rmdir --ignore-fail-on-non-empty "$PLATFORM_OUT_DIR/intermediates/tools"
        else
            mv "$work_dir" "$tool_dir"
        fi
        echo "$tool: done"
    done
}

do_clean() {
    return 0
}

fetchtools_clear() {
    local tool="$1" ; shift
    local tool_dir="tools/$tool"
    echo "$tool: '$tool_dir' -> '$tool_dir.old'"
    rm -rf "$tool_dir.old"
    mv "$tool_dir" "$tool_dir.old"
}

# check for every tool for URL changes or if the remote checksum file has been
# updated and if so trigger a new download of that tool
readonly DO_DESC_update="check for updated tools and download if needed"
do_update() {
    # clear any outdated tools
    local tool
    for tool in "${TOOLS[@]}" ; do
        local -n tool_info="TOOL_$tool"
        local url_file="tools/.$tool.url"
        local checksum_file="tools/.$tool.checksum"

        local tool_dir="tools/$tool"
        [[ -e "$tool_dir" ]] || continue

        if ! [[ -e "$url_file" ]] ; then
            echo "$tool: missing '$url_file', assuming manual user setup"
            continue
        fi

        mapfile -t old_url < "$url_file"
        if [[ "${tool_info[data_url]}" != "${old_url[0]:-}" ]] ; then
            echo "$tool: data URL changed"
            fetchtools_clear "$tool"
            continue
        fi
        if [[ "${tool_info[checksum_url]}" != "${old_url[1]:-}" ]] ; then
            echo "$tool: checksum URL changed"
            fetchtools_clear "$tool"
            continue
        fi

        if [[ -n "${tool_info[checksum_url]}" ]] ; then
            echo "$tool: fetching checksum file..."
            # currently any type of fetch failure causes us to skip the check
            if wget -O "$PLATFORM_OUT_DIR/intermediates/$tool.checksum" "${tool_info[checksum_url]}" ; then
                if cmp --silent "$PLATFORM_OUT_DIR/intermediates/$tool.checksum" "$checksum_file" ; then
                    echo "$tool: no updated checksum file"
                else
                    echo "$tool: updated checksum file detected!"
                    fetchtools_clear "$tool"
                fi
                rm -f "$PLATFORM_OUT_DIR/intermediates/$tool.checksum"
            else
                echo -e "$tool: failed to fetch checksum file from remote, ${BOLD}skipping check$NORMAL."
            fi
        fi
    done

    # download the new version of anything removed
    do_build
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
