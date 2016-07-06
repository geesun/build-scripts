#!/usr/bin/env bash

# Copyright (c) 2015, ARM Limited and Contributors. All rights reserved.
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

#Print the script that the user explicitly called.
get_root_script() {
	declare -i depth
	depth=0
	while [ ! -z "$(caller $depth)" ] ; do
		depth=$depth+1
	done
	depth=$depth-1
	local callinfo=$(caller $depth)
	local script=${callinfo##* }
	echo $script
}

get_shell_type() {
	tty -s && echo "INTERACTIVE" || echo "NON-INTERACTIVE"
}

set_formatting() {
	if [ "$(get_shell_type)" = "INTERACTIVE" ] ; then
		export BOLD="\e[1m"
		export NORMAL="\e[0m"
		export RED="\e[31m"
		export GREEN="\e[32m"
		export YELLOW="\e[33m"
		export BLUE="\e[94m"
		export CYAN="\e[36m"
	fi
}

#Print usage and exit with given return code
usage_exit ()
{
	#Show extra formatting if it's an interactive session
	#(but non in automated build systems as logging gets confusing)
	set_formatting
	local flavour_cmd_list="clean/build/package"
	local no_flavour_cmd_list="clean"
	if [[ "$(get_root_script)" == *"build-all.sh" ]] ; then
		flavour_cmd_list="$flavour_cmd_list/all"
		no_flavour_cmd_list="$no_flavour_cmd_list/all"
	fi
	echo -e "${BOLD}Usage: ${NORMAL}"
	echo -en "	$0 ${RED}-p PLATFORM${NORMAL} ${GREEN}-t FLAVOUR${NORMAL} "
	echo -e "${BLUE}[-f FILESYSTEM]${NORMAL} [-d] ${CYAN}[$flavour_cmd_list]${NORMAL}"
	echo -en "	$0 ${RED}-p PLATFORM${NORMAL} "
	echo -e "${BLUE}[-f FILESYSTEM]${NORMAL} [-d] ${CYAN}[$no_flavour_cmd_list]${NORMAL}"
	echo -e "$extra_message"
	echo "Valid platforms and flavours:"
	for platform_dir in $(find $DIR/platforms/ -mindepth 1 -maxdepth 1 -type d) ; do
		flavours=$(ls $platform_dir | grep -v '.base$'| tr '\n' ' ')
		platform=$(basename $platform_dir)
		if [ ! -z "$flavours" ] ; then
			echo -e "Platform $BOLD$RED$platform$NORMAL has flavours $BOLD$GREEN$flavours$NORMAL"
		fi
	done
	echo -e "If ${GREEN}FLAVOUR$NORMAL option is omitted, all flavours for that platform will be assumed."
	echo -e "${GREEN}FLAVOUR$NORMAL must be specified for the ${CYAN}build/package$NORMAL options."
	echo
	echo -e "Valid fileystems: $BOLD${BLUE}$(ls $DIR/filesystems | tr '\n' ' ')$NORMAL"
	echo -e "If ${BLUE}FILESYSTEM$NORMAL option is omitted, all filesystems will be assumed."
	echo
	echo "If the '-d' option is present, MPG and SCP will be built from source,"
	echo "otherwise MPG and SCP artifacts will be used when building android"
	echo "and SCP will also be built instead of using the prebuilt artifacts."
	echo
	echo -e "${CYAN}Commands:${NORMAL}"
	echo -e "	${CYAN}clean${NORMAL}	 Cleans any binaries produced during build command."
	echo -e "	${CYAN}build${NORMAL}	 Build source."
	echo -e "	${CYAN}package${NORMAL}	 Packages into output folder for use."
	echo -e "		 Must be done after build command."
	if [[ "$(get_root_script)" == *"build-all.sh" ]] ; then
		echo -e "	${CYAN}all${NORMAL}	 Does a build and package for any flavours specified."
	fi
	exit $1
}


check_not_missing() {
	local description=$1
	local value=$2
	if [ -z "$value" ] ; then
		echo "$BOLD$RED$description is not set.$NORMAL" >&2
		usage_exit 1
	fi
}

parse_params() {
	#If this is called multiple times, let's ensure that it's handled
	unset OPTIND
	unset CMD

	#Parse the named parameters
	while getopts "p:f:ht:d" opt; do
		case $opt in
			p)
				export PLATFORM="$OPTARG"
				;;
			f)
				export FILESYSTEM_CONFIGURATION="$OPTARG"
				;;
			t)
				export FLAVOUR="$OPTARG"
				;;
			d)
				source $PARSE_PARAMS_DIR/.debug
				;;
			h)
				usage_exit 0
				;;
			\?)
				usage_exit 1
				;;
		esac
	done

	#The clean/build/package/all should be after the other options
	#So grab the parameters after the named param option index
	export CMD=${@:$OPTIND:1}

	loop=0
	if [ -z "$FILESYSTEM_CONFIGURATION" ] || [ "$FILESYSTEM_CONFIGURATION" = "all" ] ; then
		FILESYSTEM_CONFIGURATION='*'
	fi

	if [ "$FLAVOUR" = "all" ] ; then
		#Flavour looping is done elsewhere if FLAVOUR is not set.
		unset FLAVOUR
	fi

	if [ -z "$FLAVOUR" ] ; then
		if [ "$CMD" = "build" ] || [ "$CMD" = "package" ] ; then
			set_formatting
			echo -en "${RED}Command ${BOLD}$CMD${NORMAL}${RED} is unavailable if no "
			echo -e "${BOLD}single flavour${NORMAL}${RED} is specified.${NORMAL}\n"
			usage_exit 1
		fi
	fi

	#If missing the platform, loop over the platforms
	if [ -z "$PLATFORM" ] || [ "$PLATFORM" = "all" ] ; then
		set_formatting
		platform_loop=""
		for platform_dir in $(find $DIR/platforms/ -mindepth 1 -maxdepth 1 -type d) ; do
			flavours=$(ls $platform_dir | grep -v '.base$'| tr '\n' ' ')
			#Don't build platforms with no flavours
			if [ ! -z "$flavours" ] ; then
				platform_name=$(basename $platform_dir)
				platform_loop="$platform_loop $platform_name"
			fi
		done
		if [ "$CMD" = "all" ] ; then
			action=Building
		else
			action=Cleaning
		fi
		echo -e "${BOLD}$action for all platforms: ${platform_loop}${NORMAL}"
		if [ "$(get_shell_type)" = "INTERACTIVE" ] ; then
			sleep 5
		fi
		for platform_entry in $platform_loop ; do
			#HACK Disable IOT for now.
			if [ "$platform_entry" = "css-iot" ] ; then
				continue
			fi
			$(get_root_script) -p $platform_entry $CMD
		done
		if [ "$CMD" = "clean" ] ; then
			this_dir=$(dirname $(get_root_script))
			entire_output=$(readlink -f ${this_dir}/../output)
			echo -e "${GREEN}Finishing clean by removing $entire_output${NORMAL}"
			rm -rf $entire_output
		fi
		exit 0
	fi
}
export PARSE_PARAMS_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
