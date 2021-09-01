#!/bin/sh

set -u
set -e

echo "dir /lib 755 0 0"
echo "dir /lib/firmware 755 0 0"
echo "dir /lib/firmware/rtl_nic 755 0 0"
echo "file /lib/firmware/rtl_nic/rtl8168g-2.fw $WORKSPACE_DIR/tools/linuxfirmware/rtl8168g-2.fw 755 0 0"
