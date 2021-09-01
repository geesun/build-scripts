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

readonly FILESYSTEM_OPTIONS=(
    "none"
    "busybox"
    "ubuntu"
)

readonly PLATFORM_DEFAULT="n1sdp"
readonly PLATFORM_OPTIONS=(
    "n1sdp"
)

readonly CMD_DEFAULT=( "build" )
readonly CMD_OPTIONS=( $(compgen -A function | sed -rne 's#^do_##p') )

source "$SCRIPT_DIR/config/bsp"

print_usage() {
    echo -e "${BOLD}Usage:"
    echo -e "    $0 ${CYAN}-f FILESYSTEM [-p PLATFORM] [CMD...]$NORMAL"
    echo
    echo "FILESYSTEM:"
    local s
    for s in "${FILESYSTEM_OPTIONS[@]}" ; do
        echo "    $s"
    done
    echo
    echo "PLATFORM (default is \"$PLATFORM_DEFAULT\"):"
    for s in "${PLATFORM_OPTIONS[@]}" ; do
        echo "    $s"
    done
    echo
    echo "CMD (default is \"${CMD_DEFAULT[@]}\"):"
    local s_maxlen="0"
    for s in "${CMD_OPTIONS[@]}" ; do
        local i="${#s}"
        (( i > s_maxlen )) && s_maxlen="$i"
    done
    for s in "${CMD_OPTIONS[@]}" ; do
        local -n desc="DO_DESC_$s"
        printf "    %- ${s_maxlen}s    %s\n" "$s" "${desc:+($desc)}"
    done
}

PLATFORM="$PLATFORM_DEFAULT"
FILESYSTEM=""
CMD=( "${CMD_DEFAULT[@]}" )
while getopts "p:f:h" opt; do
    case $opt in
    ("p") PLATFORM="$OPTARG" ;;
    ("f") FILESYSTEM="$OPTARG" ;;
    ("?")
        print_usage >&2
        exit 1
        ;;
    ("h")
        print_usage
        exit 0
    esac
done
shift $((OPTIND-1))

in_haystack "$PLATFORM" "${PLATFORM_OPTIONS[@]}" ||
    die "invalid PLATFORM: $PLATFORM"
readonly PLATFORM

if [[ -z "${FILESYSTEM:-}" ]] ; then
    echo "ERROR: Mandatory -f FILESYSTEM not given!" >&2
    echo "" >&2
    print_usage >&2
    exit 1
fi
in_haystack "$FILESYSTEM" "${FILESYSTEM_OPTIONS[@]}" ||
    die "invalid FILESYSTEM: $FILESYSTEM"
readonly FILESYSTEM

if [[ "$#" -ne 0 ]] ; then
    CMD=( "$@" )
fi
for cmd in "${CMD[@]}" ; do
    in_haystack "$cmd" "${CMD_OPTIONS[@]}" || die "invalid CMD: $cmd"
done
readonly CMD
