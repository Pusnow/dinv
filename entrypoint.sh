#!/bin/sh

DINV_CPUS=${DINV_CPUS:-1}
DINV_MEMORY=${DINV_MEMORY:-512M}

DINV_DOCKER_SIZE=${DINV_DOCKER_SIZE:-64G}

if [ ! -f /docker/docker.qcow2 ]; then
  qemu-img create -f qcow2 /docker/docker.qcow2 ${DINV_DOCKER_SIZE}
fi

HOSTFWD=""

for port in $(echo "$DINV_TCP_PORTS" | tr ';' ' '); do
  HOSTFWD="${HOSTFWD},hostfwd=tcp::${port}-:${port}"
done
for port in $(echo "$DINV_UDP_PORTS" | tr ';' ' '); do
  HOSTFWD="${HOSTFWD},hostfwd=udp::${port}-:${port}"
done

MOUNTS=""
MOUNT_COUNTER=0

for mount in $(echo "$DINV_MOUNTS" | tr ';' ' '); do
  echo "$mount" >/var/run/dinvfs${MOUNT_COUNTER}
  MOUNTS="${MOUNTS}\
  -fsdev local,path=${mount},security_model=passthrough,id=dinvfsdev${MOUNT_COUNTER} \
  -device virtio-9p-pci,fsdev=dinvfsdev${MOUNT_COUNTER},mount_tag=dinvfs${MOUNT_COUNTER} \
  -fw_cfg name=opt/dinv/9p/dinvfs${MOUNT_COUNTER},file=/var/run/dinvfs${MOUNT_COUNTER} "
  MOUNT_COUNTER=$((MOUNT_COUNTER + 1))
done

DINV_VOLUME_SIZE=${DINV_VOLUME_SIZE:-64G}
VOLUMES=""
if [ ! -z "${DINV_VOLUME_PATH}" ]; then
  if [ ! -f /volume/volume.qcow2 ]; then
    qemu-img create -f qcow2 /volume/volume.qcow2 ${DINV_VOLUME_SIZE}
  fi
  echo "$DINV_VOLUME_PATH" >/var/run/dinv-volume
  VOLUMES="\
  -drive id=volume,file=/volume/volume.qcow2,format=qcow2,if=none \
  -device virtio-blk-device,drive=volume \
  -fw_cfg name=opt/dinv/volume,file=/var/run/dinv-volume"
fi

cmd_handler() {

  while [ "$(wget -q -O- http://127.0.0.1:2375/_ping)" != "OK" ]; do
    echo "Waiting dockerd..."
    sleep 5
  done
  $@
}

if [ "$#" -gt 0 ]; then
  cmd_handler $@ &
fi

qemu-system-x86_64 \
  -machine microvm,accel=kvm -cpu host -smp ${DINV_CPUS} -m ${DINV_MEMORY} \
  -chardev socket,path=/var/run/dinv-qga.sock,server=on,wait=off,id=qga0 \
  -device virtio-serial-device \
  -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
  -kernel /dinv/vmlinuz -initrd /dinv/initrd.img -append "console=ttyS0 rootfstype=ext4 root=/dev/vda" \
  -nodefaults -no-user-config -no-reboot -nographic \
  -serial stdio \
  -device virtio-balloon-device \
  -netdev user,id=user0,hostfwd=tcp::2375-:2375${HOSTFWD} -device virtio-net-device,netdev=user0 \
  -drive id=root,file=/dinv/root.qcow2,format=qcow2,if=none -device virtio-blk-device,drive=root \
  -drive id=docker,file=/docker/docker.qcow2,format=qcow2,if=none -device virtio-blk-device,drive=docker \
  ${VOLUMES} ${MOUNTS}
