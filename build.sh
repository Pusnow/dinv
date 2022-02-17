#!/bin/sh
set -ex

APK_TOOLS=http://dl-cdn.alpinelinux.org/alpine/v3.15/main/x86_64/apk-tools-static-2.12.7-r3.apk

VERSION=${VERSION:-latest-stable}
ARCH=${ARCH:-x86_64}

rm -rf build
mkdir -p build

cd build

wget -O apk-tools.tar.gz ${APK_TOOLS}
tar -xvzf apk-tools.tar.gz
APK=sbin/apk.static

modprobe nbd max_part=1

qemu-img create -f qcow2 root.qcow2 8G

qemu-nbd --connect=/dev/nbd0 root.qcow2

sleep 1

mkfs.ext4 /dev/nbd0

mkdir -p rootfs

mount /dev/nbd0 rootfs

${APK} --arch ${ARCH} -X http://dl-cdn.alpinelinux.org/alpine/${VERSION}/main/ \
   -X http://dl-cdn.alpinelinux.org/alpine/${VERSION}/community/ \
   -U --allow-untrusted --root rootfs --initdb add alpine-base linux-virt util-linux e2fsprogs docker qemu-guest-agent

cd rootfs/etc/init.d
ln -s agetty agetty.ttyS0
cd ../../..

echo "
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
" >rootfs/etc/network/interfaces

echo "9pnet" >>rootfs/etc/modules
echo "9pnet_virtio" >>rootfs/etc/modules
echo "qemu_fw_cfg" >>rootfs/etc/modules
echo "virtio_console" >>rootfs/etc/modules

echo "DOCKER_OPTS=\"-H unix:///var/run/docker.sock -H tcp://0.0.0.0:2375 --bip 172.19.0.1/16\"" >>rootfs/etc/conf.d/docker

cp ../dinv rootfs/etc/init.d/dinv
cp ../dinv-post rootfs/etc/init.d/dinv-post

chroot rootfs rc-update add agetty.ttyS0 default
chroot rootfs rc-update add docker default
chroot rootfs rc-update add dinv default
chroot rootfs rc-update add dinv-post default
chroot rootfs rc-update add qemu-guest-agent default

chroot rootfs rc-update add devfs sysinit
chroot rootfs rc-update add dmesg sysinit
chroot rootfs rc-update add mdev sysinit

chroot rootfs rc-update add hwclock boot
chroot rootfs rc-update add modules boot
chroot rootfs rc-update add sysctl boot
chroot rootfs rc-update add hostname boot
chroot rootfs rc-update add bootmisc boot
chroot rootfs rc-update add syslog boot
chroot rootfs rc-update add networking boot

chroot rootfs rc-update add mount-ro shutdown
chroot rootfs rc-update add killprocs shutdown
chroot rootfs rc-update add savecache shutdown

cp rootfs/boot/vmlinuz-* vmlinuz
cp rootfs/boot/initramfs-* initrd.img

umount rootfs
qemu-nbd --disconnect /dev/nbd0
