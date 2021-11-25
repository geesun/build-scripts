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

# both $1 and $2 are absolute paths beginning with /
# returns relative path to $2/$target from $1/$source
relative_path()
{
	source=$2
	target=$1

	common_part=$source # for now
	result="" # for now

	while [[ "${target#$common_part}" == "${target}" ]]; do
		# no match, means that candidate common part is not correct
		# go up one level (reduce common part)
		common_part="$(dirname $common_part)"
		# and record that we went back, with correct / handling
		if [[ -z $result ]]; then
			result=".."
		else
			result="../$result"
		fi
	done

	if [[ $common_part == "/" ]]; then
		# special case for root (no common path)
		result="$result/"
	fi

	# since we now have identified the common part,
	# compute the non-common part
	forward_part="${target#$common_part}"

	# and now stick all parts together
	if [[ -n $result ]] && [[ -n $forward_part ]]; then
		result="$result$forward_part"
	elif [[ -n $forward_part ]]; then
		# extra slash removal
		result="${forward_part:1}"
	fi
	echo ${result}
}

# $1: TARGET_blah from variant
# $2: target from variant
# $3: file pattern
create_tgt_symlinks()
{
	shopt -s nullglob

	if [[ "${OUTDIR}/$1" != "${PLATDIR}/$2" ]]; then
		mkdir -p ${PLATDIR}/$2
		for bin in ${OUTDIR}/$1/$3; do
			local dirlink=$(relative_path $(dirname ${bin}) ${PLATDIR}/$1)
			local filename=$(basename ${bin})
			ln -sf  ${dirlink}/${filename} ${PLATDIR}/$2/${filename}
		done
	fi
}
