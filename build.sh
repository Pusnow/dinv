#!/bin/sh

run() {
   echo "$@"
   $@ || exit 1
}


APK_TOOLS=http://dl-cdn.alpinelinux.org/alpine/v3.15/main/x86_64/apk-tools-static-2.12.7-r3.apk

VERSION=${VERSION:-latest-stable}
ARCH=${ARCH:-x86_64}

run rm -rf build
run mkdir -p build

run cd build

run wget -O apk-tools.tar.gz ${APK_TOOLS}
run tar -xvzf apk-tools.tar.gz
APK=sbin/apk.static

run modprobe nbd max_part=1

run qemu-img create -f qcow2 root.qcow2 8G

run qemu-nbd --connect=/dev/nbd0 root.qcow2

run sleep 1

run mkfs.ext4 /dev/nbd0

run mkdir -p rootfs

run mount /dev/nbd0 rootfs

run ${APK} --arch ${ARCH} -X http://dl-cdn.alpinelinux.org/alpine/${VERSION}/main/ \
   -X http://dl-cdn.alpinelinux.org/alpine/${VERSION}/community/ \
   -U --allow-untrusted --root rootfs --initdb add alpine-base linux-virt util-linux e2fsprogs docker

run cd rootfs/etc/init.d
run ln -s agetty agetty.ttyS0
run cd ../../..

run echo "
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
" > rootfs/etc/network/interfaces


run echo "9pnet" >>rootfs/etc/modules
run echo "9pnet_virtio" >>rootfs/etc/modules
run echo "qemu_fw_cfg" >>rootfs/etc/modules

echo "DOCKER_OPTS=\"-H unix:///var/run/docker.sock -H tcp://0.0.0.0:2375\"" >> rootfs/etc/conf.d/docker


run cp ../mount-dinv rootfs/etc/init.d/mount-dinv

run chroot rootfs rc-update add agetty.ttyS0 default
run chroot rootfs rc-update add docker default
run chroot rootfs rc-update add mount-dinv default

run chroot rootfs rc-update add devfs sysinit
run chroot rootfs rc-update add dmesg sysinit
run chroot rootfs rc-update add mdev sysinit

run chroot rootfs rc-update add hwclock boot
run chroot rootfs rc-update add modules boot
run chroot rootfs rc-update add sysctl boot
run chroot rootfs rc-update add hostname boot
run chroot rootfs rc-update add bootmisc boot
run chroot rootfs rc-update add syslog boot
run chroot rootfs rc-update add networking boot

run chroot rootfs rc-update add mount-ro shutdown
run chroot rootfs rc-update add killprocs shutdown
run chroot rootfs rc-update add savecache shutdown

run cp rootfs/boot/vmlinuz-* vmlinuz
run cp rootfs/boot/initramfs-* initrd.img

run umount rootfs
run qemu-nbd --disconnect /dev/nbd0
