#!/bin/sh
#

on_exit() {
        test $? -ne 0 || exit 0
        echo "Tried to terminated PID 1, bailing to a recovery shell!" >&2
        exec /bin/sh
}

trap "on_exit" EXIT TERM

set -u
set -e

mkdir /target
mount /dev/sda2 /target
mount -t devtmpfs dev /target/dev

chroot /target /bin/init

cut -f2 -d' ' /proc/mounts | grep -E '^/target($|/)' | sort -r | xargs umount

cat <<EOF

Installation has finished.

Use 'reboot' to reset the system and boot into your new Ubuntu system!
EOF

while true ; do
        /bin/sh
done
