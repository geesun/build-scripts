#!/bin/sh

# This proprietary software may be used only as authorised by a licensing
# agreement from Arm Limited.
#
# (C) COPYRIGHT 2015-2021 Arm Limited.
#
# The entire notice above must be reproduced on all authorised copies and
# copies may only be made to the extent permitted by a licensing agreement from
# ARM Limited.

#Mount things needed by this script
/bin/busybox mount -t proc proc /proc
/bin/busybox mount -t sysfs sysfs /sys
/bin/busybox mount -t debugfs none /sys/kernel/debug
echo "init.sh"

#Create all the symlinks to /bin/busybox
/bin/busybox --install -s

mdev -s

# Send an EOT character to shutdown models if lauched with the corresponding
# option.
echo -e '\004'

exec sh
