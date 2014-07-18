#!/bin/bash

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
