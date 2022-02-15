#!/usr/bin/env bash

# Copyright (c) 2021-2022, ARM Limited and Contributors. All rights reserved.
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

readonly DEFAULT_SHELL_OPTS="$(set +o)"
set -E
set -o pipefail
set -u

# excute a command with the default shell options (mostly useful with external
# shell functions)
with_default_shell_opts() {
    local -r original_opts="$(set +o)"
    eval "$DEFAULT_SHELL_OPTS"
    "$@"
    local -r i=$?
    eval "$original_opts"
    return $i
}

print_trace() {
    local -a lineno func file
    local len_lineno=0 len_func=0 len_file=0
    local i
    local callinfo
    for ((i=0; ; i++)) ; do
        callinfo="$(caller $((i+1)))" || break

        lineno+=( "${callinfo%% *}" )
        [[ ${#lineno[i]} -lt $len_lineno ]] || len_lineno=${#lineno[i]}
        callinfo="${callinfo#* }"

        func+=( "${callinfo%% *}" )
        [[ ${#func[i]} -lt $len_func ]] || len_func=${#func[i]}
        callinfo="${callinfo#* }"

        file+=( "$callinfo" )
        [[ ${#file[i]} -lt $len_file ]] || len_file=${#file[i]}
    done
    local -r depth="$i"

    local -r fmt_str="%-${len_func}s  %-${len_file}s  %-${len_lineno}s\n"
    printf "$BOLD$fmt_str$NORMAL" "func" "file" "line"
    for ((i=0; i<depth ; i++)) ; do
        printf "$fmt_str" "${func[i]}" "${file[i]}" "${lineno[i]}"
    done
}

handle_error () {
    local -r exit_code=$?
    {
        error_echo "Command terminated with a non-zero code!"
        echo "PLATFORM   = ${PLATFORM:-}"
        echo "FILESYSTEM = ${FILESYSTEM:-}"
        echo "WD         = $PWD"
        echo "EXIT CODE  = $exit_code"
        echo ""
        echo "Build-script call trace:"
        print_trace
    } >&2
    exit 1
}

if [[ -t 1 ]] ; then
    BOLD="\e[1m"
    NORMAL="\e[0m"
    RED="\e[31m"
    GREEN="\e[32m"
    YELLOW="\e[33m"
    BLUE="\e[94m"
    CYAN="\e[36m"
else
    BOLD=""
    NORMAL=""
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
fi
readonly BOLD NORMAL RED GREEN YELLOW BLUE CYAN

trap handle_error ERR

error_echo() {
    echo -e "$BOLD${RED}ERROR:$NORMAL$RED $*$NORMAL" >&2
}

die() {
    error_echo "$*"
    exit 1
}

in_haystack() {
    local -r needle="$1" ; shift
    local haystack
    for haystack in "$@" ; do
        [[ $needle != $haystack ]] || return 0
    done
    return 1
}

readonly DO_DESC_all="alias for \"clean build\""
do_all() {
    cd "$WORKSPACE_DIR"
    do_clean
    cd "$WORKSPACE_DIR"
    do_build
}

if [[ -v PARALLELISM ]] ; then
    echo "PARALLELISM set in environment to $PARALLELISM, not overridden."
else
    PARALLELISM=`getconf _NPROCESSORS_ONLN`
fi
readonly PARALLELISM

# custom text set by the component script
readonly DO_DESC_build
readonly DO_DESC_clean

readonly SCRIPT_DIR="$(realpath --no-symlinks "$(dirname "${BASH_SOURCE[0]}")")"
readonly WORKSPACE_DIR="$(realpath --no-symlinks "$SCRIPT_DIR/..")"

readonly GCC_ARM64_PREFIX="$WORKSPACE_DIR/tools/arm_linux_gcc/bin/aarch64-none-linux-gnu-"
readonly GCC_ARM32_PREFIX="$WORKSPACE_DIR/tools/arm_eabi_gcc/bin/arm-none-eabi-"

source "$SCRIPT_DIR/parse_params.sh"

readonly PLATFORM_OUT_DIR="$WORKSPACE_DIR/output/$PLATFORM"

for cmd in "${CMD[@]}" ; do
    cd "$WORKSPACE_DIR"
    do_$cmd
done
