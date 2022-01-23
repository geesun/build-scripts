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

shopt -s nullglob

readonly libelf_URL="https://sourceware.org/pub/elfutils/0.178/elfutils-0.178.tar.bz2"
readonly opencsd_URL="https://github.com/Linaro/OpenCSD/archive/v1.2.0.tar.gz"
readonly perf_URL="/dev/null"
readonly zlib_URL="https://zlib.net/zlib-1.2.12.tar.xz"

readonly COMPONENTS=( \
    opencsd \
    zlib \
    libelf \
    perf \
)

opencsd_compile() {
    cd "$DIR_SRC/decoder/build/linux/"
    env \
        ARCH=arm64 \
        CROSS_COMPILE="$MRTOOLPREFIX" \
        make $MAKEOPTS
}

opencsd_install() {
    cd "$DIR_SRC/decoder/build/linux/"
    make install PREFIX="$BDIR/sysroot"
}

zlib_configure() {
    mkdir -p "$DIR_BUILD"
    cd "$DIR_BUILD"
    "$DIR_SRC/configure" \
        --prefix="$BDIR/sysroot" \
        --static
}

libelf_configure() {
    mkdir -p "$DIR_BUILD"
    cd "$DIR_BUILD"
    env \
        CPPFLAGS="-isystem $BDIR/sysroot/include"\
        LDFLAGS="-L$BDIR/sysroot/lib" \
        "$DIR_SRC/configure" \
            --host=x86_64-linux-gnu \
            --build=aarch64-linux-gnu \
            --prefix="$BDIR/sysroot" \
            --disable-debuginfod \
            --disable-gprof \
            --disable-gcov \
            --disable-textrelcheck
}

perf_compile() {
    cd "$WORKSPACE_DIR/linux/tools/perf/"

    local CORESIGHT_OPTS=( \
        "CORESIGHT=1" \
        "CSINCLUDES=\"$BDIR/sysroot/include\"" \
        "CSLIBS=\"$BDIR/sysroot/lib\"" \
    )

    mkdir -p "$DIR_BUILD"
    env \
        EXTRA_CFLAGS="-isystem $BDIR/sysroot/include"
        EXTRA_LDFLAGS="-L$BDIR/sysroot/lib"
        make \
            V=1 \
            "${CORESIGHT_OPTS[@]}" \
            LDFLAGS="-static" \
            O="$DIR_BUILD" \
            ARCH=arm64 \
            CROSS_COMPILE="${MRTOOLPREFIX}" \

    test -e "$DIR_BUILD/feature/test-libopencsd.bin" || die "opencsd support not activated"
}

perf_install() {
    "${MRTOOLPREFIX}strip" --strip-all "$DIR_BUILD/perf" -o "$DIR_BUILD/perf.stripped"
    install \
        -m0666 \
        -Dt "$PLATFORM_OUT_DIR/perf/" \
        "$DIR_BUILD/perf" \
        "$DIR_BUILD/perf.stripped"
}

phase_get() {
    local name="$COMPONENT"
    local url="$1" ; shift
    test "$url" != "/dev/null" || return 0

    mkdir -p "$BDIR/download/"
    local filename="$(basename "$url")"
    local filepath_fetched="$BDIR/download/$filename"
    if test "${N1SDP_PERF_DOWNLOAD_CACHE:-}" != "" ; then
        test ! -e "$N1SDP_PERF_DOWNLOAD_CACHE/$name/$filename" \
        || cp "$N1SDP_PERF_DOWNLOAD_CACHE/$name/$filename"
    fi
    test -e "$filepath_fetched" || wget "$url" -O "$filepath_fetched"
    mkdir -p "$BDIR/comp/$name/"
    cd "$BDIR/comp/$name/"
    tar xf "$filepath_fetched"
    test "$(for x in * ; do echo "$x" ; done | wc -l)" = "1" || die "unexpected content"
    mv * src
}

phase_configure() {
    :
}

phase_compile() {
    cd "$DIR_BUILD"
    make $MAKEOPTS
}

phase_install() {
    cd "$DIR_BUILD"
    make install
}

phase_exec() {
    local COMPONENT="$1" ; shift
    local PHASE="$1" ; shift
    DIR_SRC="$BDIR/comp/$COMPONENT/src"
    DIR_BUILD="$BDIR/comp/$COMPONENT/build"

    printf "%- 10s: $COMPONENT\n" "$PHASE"

    if declare -f "${COMPONENT}_$PHASE" >/dev/null ; then
        "${COMPONENT}_$PHASE" "$@" &> "$BDIR/log/$comp.$PHASE.log"
    else
        "phase_$PHASE" "$@" &> "$BDIR/log/$comp.$PHASE.log"
    fi
}

do_build() {
    MRTOOLPREFIX="$GCC_ARM64_PREFIX"
    CC="${MRTOOLPREFIX}gcc"
    BDIR="${PLATFORM_OUT_DIR}/intermediates/perf"

    export CC
    mkdir -p "$BDIR"
    mkdir -p "$BDIR/log"

    if test "${MAKEOPTS:-}" = "" ; then
        MAKEOPTS="-j$(( ($(grep -E '^processor[[:blank:]]*:' /proc/cpuinfo | wc -l))+4 ))"
        echo "auto populating MAKEOPTS=\"$MAKEOPTS\""
    else
        echo "user supplied MAKEOPTS=\"$MAKEOPTS\""
    fi
    readonly MAKEOPTS

    for comp in "${COMPONENTS[@]}"; do
        s="${comp}_URL"
        phase_exec "$comp" get "${!s}"
    done
    for comp in "${COMPONENTS[@]}"; do
        for PHASE in configure compile install ; do
            phase_exec "$comp" "$PHASE"
        done
    done
}

do_clean() {
    BDIR="${PLATFORM_OUT_DIR}/intermediates/perf"
    rm -rf \
        "$BDIR" \
        "$PLATFORM_OUT_DIR/perf/"
}

source "$(dirname ${BASH_SOURCE[0]})/framework.sh"
