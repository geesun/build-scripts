#!/bin/sh

set -e
set -u

cat files.txt

# we assume busybox is to be used
echo "file /bin/busybox $PLATFORM_OUT_DIR/intermediates/busybox-ubuntu/_install/bin/busybox 755 0 0"
