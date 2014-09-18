#!/bin/bash

IMG=dd.raw
SIZE=20240

TMPDIR=tmp
ARCH=amd64
KERNEL=3.13.0-24-generic
KERNEL_CHRONOS=3.0.31-chronos+

DISTRIBUTION=trusty
MIRROR=http://ftp.ubuntu.com/ubuntu


if [ `id -u` -ne 0 ]; then
    echo "Need to be run as root"
    exit 1
fi

# dd if=/dev/zero of=$IMG bs=1M count=$SIZE
mke2fs -F $IMG

if [ ! -d ${TMPDIR} ]
then
    mkdir $TMPDIR
fi

mount $IMG $TMPDIR -o loop

/usr/sbin/debootstrap --verbose $DISTRIBUTION $TMPDIR $MIRROR

cat > $TMPDIR/root/chroot.sh <<EOF
#!/bin/sh
LANG=C

passwd -d root

mount proc /proc -t proc
mount sysfs /sys -t sysfs
mount devpts /dev/pts -t devpts

echo "deb-src http://ftp.ubuntu.com/ubuntu $DISTRIBUTION main" >> /etc/apt/sources.list

apt-get -q -y update
apt-get -q -y install linux-image-extra-$KERNEL

rm -f /etc/hostname
echo kairos > /etc/hostname

umount /proc
umount /sys
umount /dev/pts

exit
EOF

cat > $TMPDIR/root/kernel.sh <<EOF
apt-get build-dep linux
apt-get install git

cd /root

git clone git://git.chronoslinux.org/kernel.git

cd /root/kernel
cp /root/config-3.0.24-chronos .config
yes "" | make oldconfig
./kinst.sh

sed -i 's/GRUB_DEFAULT=0/GRUB_DEFAULT="1>1"/' grub
update-grub2

EOF

cat > $TMPDIR/root/userspace.sh <<EOF
git clone ssh://git@git.chronoslinux.org/userspace.git

cd /root/userspace/libchronos
make
make install

cd /root/userspace/sched_test_app
make
make install
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

exit 0

# Then launch QEMU, e.g.:

qemu-system-x86_64 \
        --enable-kvm \
        -m 1G \
        -smp 2 \
        -hda $IMG \
        -initrd initrd.img-$KERNEL \
        -kernel vmlinuz-$KERNEL \
        -append "root=/dev/sda"

# qemu-system-x86_64 \
#         --enable-kvm \
#         -m 1G \
#         -smp 2 \
#         -hda $IMG \
#         -initrd initrd.img-$KERNEL_CHRONOS \
#         -kernel vmlinuz-$KERNEL_CHRONOS \
#         -append "root=/dev/sda"
