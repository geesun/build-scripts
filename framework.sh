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

set -E

handle_error ()
{
	local callinfo=$(caller 0)
	local script=${callinfo##* }
	local lineno=${callinfo%% *}
	local func=${callinfo% *}
	func=${func#* }
	echo
	echo "Build failed: error while running ${func} at line ${lineno} in ${script} for variant ${VARIANT}."
	echo
	exit 1
}

trap handle_error ERR

if [ "$PARALLELISM" != "" ]; then
	echo "Parallelism set in environment to $PARALLELISM, not overridding"
else
	PARALLELISM=`getconf _NPROCESSORS_ONLN`
fi

VARIANT=$1
CMD=$2

# Directory variables provided by the framework
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
pushd $DIR/..
TOP_DIR=`pwd`
popd
PLATDIR=${TOP_DIR}/output
OUTDIR=${PLATDIR}/components
LINUX_OUT_DIR=out/$VARIANT

usage_exit ()
{
	echo "Usage: $0 {variant} {build|clean|package|all}"
	exit 1
}

if [ $# -lt 1 ]; then
	usage_exit
fi

# Load the variables from the variant if it exists. We support single nested
# variant folders which will override the top level variant files. But if
# multiple subfolders contain the same variant file we'll just use the first
# found
VARIANT_FILE=""
for VDIR in $TOP_DIR/build-scripts/*/variants ; do
	# Look for variant in that folder
	if [ -f $VDIR/$VARIANT ]; then
		VARIANT_FILE="$VDIR/$VARIANT"
		break
	fi
done
if [ "$VARIANT_FILE" == "" ]; then
	if [ -f $TOP_DIR/build-scripts/variants/$VARIANT ]; then
		VARIANT_FILE="$TOP_DIR/build-scripts/variants/$VARIANT"
	fi
fi
if [ "$VARIANT_FILE" == "" ]; then
	echo "Variant $VARIANT doesn't exist"
	exit 1
else
	source $VARIANT_FILE $VARIANT
fi

case "$CMD" in
	"") do_build
	;;

	build) do_build
	;;

	clean) do_clean
	;;

	package) do_package
	;;

	ignore) echo "Parsing variant"
	;;

	*) usage_exit
	;;
esac
