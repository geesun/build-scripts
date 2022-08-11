#!/usr/bin/env bash

# Copyright (c) 2021 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

readonly FILESYSTEM_OPTIONS=(
    "buildroot"
    "android-swr"
)

readonly PLATFORM_OPTIONS=(
    "tc2"
)

AVB_DEFAULT=false

readonly CMD_DEFAULT=( "build" )
CMD_OPTIONS=("build" "patch" "clean" "deploy")
if [[ $0 == "./build-all.sh" ]]; then
    CMD_OPTIONS=("build" "package" "clean" "all" "deploy")
fi

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

CMD=( "${CMD_DEFAULT[@]}" )
while getopts "p:f:a:h" opt; do
    case $opt in
    ("p")
        PLATFORM="$OPTARG"
        ;;
    ("f")
        FILESYSTEM="$OPTARG"
        ;;
    ("a")
        AVB=true
        ;;
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

if [[ -z "${PLATFORM:-}" ]] ; then
    echo "ERROR: Mandatory -p PLATFORM not given!" >&2
    echo "" >&2
    print_usage >&2
    exit 1
fi
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

if [[ -z "${AVB:-}" ]] ; then
    AVB=$AVB_DEFAULT
fi

# Load config for specified platforn
source $SCRIPT_DIR/config/$PLATFORM.config

if [[ "$#" -ne 0 ]] ; then
    CMD=( "$@" )
fi
for cmd in "${CMD[@]}" ; do
    in_haystack "$cmd" "${CMD_OPTIONS[@]}" || die "invalid CMD: $cmd"
done
readonly CMD
