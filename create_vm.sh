#!/bin/bash

# A small script to generate a ready to use VM based on Debian
# unstable.

# Copyright (C) 2014 Vincent Legout <vincent@legout.info>

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


IMG=unstable.raw
SIZE=1024

TMPDIR=tmp
ARCH=amd64
KERNEL=3.14-1-$ARCH

DISTRIBUTION=unstable
MIRROR=http://ftp.us.debian.org/debian


if [ `id -u` -ne 0 ]; then
    echo "Need to be run as root"
    exit 1
fi

dd if=/dev/zero of=$IMG bs=1M count=$SIZE
mke2fs -F $IMG

mkdir $TMPDIR
mount $IMG $TMPDIR -o loop
debootstrap --verbose $DISTRIBUTION $TMPDIR $MIRROR

cat > $TMPDIR/root/chroot.sh <<EOF
#!/bin/sh
LANG=C

passwd -d root

mount proc /proc -t proc
mount sysfs /sys -t sysfs
mount devpts /dev/pts -t devpts

echo "deb $MIRROR testing main" >> /etc/apt/sources.list

apt-get -q -y update
apt-get -q -y install linux-image-$ARCH

rm -f /etc/hostname
echo debian > /etc/hostname

umount /proc
umount /sys
umount /dev/pts

exit
EOF

cat > $TMPDIR/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

chmod +x $TMPDIR/root/chroot.sh

chroot $TMPDIR /bin/sh ./root/chroot.sh

cp $TMPDIR/boot/initrd.img-$KERNEL .
cp $TMPDIR/boot/vmlinuz-$KERNEL .

rm $TMPDIR/root/chroot.sh

umount $TMPDIR

rmdir $TMPDIR

# Then launch QEMU, e.g.:

# qemu-system-x86_64 \
#         --enable-kvm \
#         -m 1G \
#         -smp 2 \
#         -hda $IMG \
#         -initrd initrd.img-$KERNEL \
#         -kernel vmlinuz-$KERNEL \
#         -append "root=/dev/sda"
