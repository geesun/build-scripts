#!/bin/bash

# Copyright (c) 2022 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

for_each_dep() {
     local  scripts=(
        )
 declare -A arr

 #store dependencies as an associative array
 while IFS='=' read -r key value
 do
     arr["$key"]="$value"
 done < "$(dirname ${BASH_SOURCE[0]})/dependencies.txt"

 #check for dependencies to be built on building a particular component
 while IFS="=" read -r key value; do
     case "$key" in
         '#'*) ;;
          *)
             if [[ "$key" == "$SRC" ]]; then
                for i in ${value//,/ }
                do
                    scripts+=(
                        "$i"
                    )
                    for k in "${!arr[@]}"
                    do
                        if [[ "$i" == "$k" ]]; then
                            scripts+=(
                                "${arr["$k"]}"
                            )
                         fi
                    done
                done
             fi
     esac
 done < "$(dirname ${BASH_SOURCE[0]})/dependencies.txt"

 local script
 for script in "${scripts[@]}" ; do
     echo "Executing command $@ for $script..."
     "$SCRIPT_DIR/$script" -f "$FILESYSTEM" -p "$PLATFORM" "$@" || exit 1
 done
}

do_build()
{
    # create a deploy directory
    mkdir -p $DEPLOY_DIR/$PLATFORM
    for_each_dep build
    for_each_dep deploy
}

do_all() {
    do_clean
    do_build
}

do_clean() {
    for_each_dep clean
    # Empty deploy directory
    info_echo "Cleaning deploy directory"
    rm -rf $DEPLOY_DIR/$PLATFORM/*
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
