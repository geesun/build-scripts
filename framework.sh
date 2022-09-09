#!/usr/bin/env bash

# Copyright (c) 2021-2022 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

readonly DEFAULT_SHELL_OPTS="$(set +o)"
set -o pipefail
set -e

# Patch a component
patching() {
    PATCHES=$(ls $1/*.patch 2>/dev/null)
    pushd $2
    for patch in $PATCHES; do
        git am --committer-date-is-author-date $patch
        if [ $? -eq 0 ]; then
          echo "Applied $patch"
        else
          echo "Patch $patch am failed, Either patch did not apply cleanly or was already applied." \
               "Aborting git am."
          git am --abort
        fi
    done
    popd
}

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
        echo "PLATFORM   = ${SCP_PLATFORM:-}"
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

info_echo() {
    echo -e "$BOLD${BLUE}INFO:$NORMAL$BLUE $*$NORMAL" >&2
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

if [[ -v PARALLELISM ]] ; then
    echo "PARALLELISM set in environment to $PARALLELISM, not overridden."
else
    PARALLELISM=`getconf _NPROCESSORS_ONLN`
fi
readonly PARALLELISM

# custom text set by the component script

readonly SCRIPT_DIR="$(realpath --no-symlinks "$(dirname "${BASH_SOURCE[0]}")")"
readonly WORKSPACE_DIR="$(realpath --no-symlinks "$SCRIPT_DIR/..")"

source "$SCRIPT_DIR/parse_params.sh"

for cmd in "${CMD[@]}" ; do
    cd "$WORKSPACE_DIR"
    source $VENV_DIR/bin/activate
    if [[ "$cmd" != "with_reqs" ]];then
        do_$cmd
    else
        if [[ "$1" == "build" || "$1" == "with_reqs" ]];then
            info_echo "Building Dependencies"
            export SRC="$(basename $0)"
            "$(dirname ${BASH_SOURCE[0]})/build-scripts/requisites.sh"
        fi
    fi
    deactivate
done
