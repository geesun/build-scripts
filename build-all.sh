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

#Parse the arguments passed in from the command line
if [ $# == 2 ]; then
	CMD=$2
	VARIANT=$1
elif [ $# == 1 ]; then
	CMD="build"
	VARIANT=$1
else
	echo $"Usage: $0 {variant} {build|clean|package}"
	exit 1
fi

# find the script directory...
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# load the variant so we get access to the BUILD_SCRIPTS
SAVE_CMD=$CMD
source $DIR/framework.sh $VARIANT "ignore"
CMD=$SAVE_CMD

if [ "$FINAL_BUILD_STEP" != "" ]; then
	echo "Sorting the build scripts for correctness."
	echo $BUILD_SCRIPTS
	BUILD_SCRIPTS=`echo "$BUILD_SCRIPTS" | sed "s/$FINAL_BUILD_STEP/ /g"`
	BUILD_SCRIPTS=$BUILD_SCRIPTS$FINAL_BUILD_STEP
	echo $BUILD_SCRIPTS
	echo "Done."
fi

# $1 - cmd to execute
__do_build_all()
{
	# Now to execute each component build in turn
	for build in $BUILD_SCRIPTS; do
		echo "***********************************"
		echo "Execute $1 for $build on $VARIANT"
		${DIR}/$build $VARIANT $1
		if [ "$?" -ne 0 ]; then
			echo "Command failed: $1 for $build on $VARIANT"
			exit 1
		fi
		echo "Execute $1 for $build on $VARIANT done."
		echo "-----------------------------------"
	done

	if [ "$1" = "clean" ]; then
		echo "Finishing clean by removing $OUTDIR and $PLATDIR"
		rm -rf $OUTDIR
		rm -rf $PLATDIR
	fi
}

if [ "$CMD" != "all" ]; then
	__do_build_all $CMD
else
	__do_build_all clean
	__do_build_all build
	__do_build_all package

fi
