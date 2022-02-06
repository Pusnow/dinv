ARG ALPINE_VERION=latest
FROM alpine:${ALPINE_VERION}

RUN apk add --no-cache qemu-system-x86_64 qemu-img docker-cli coreutils

COPY build/root.qcow2 /dinv/root.qcow2
COPY build/vmlinuz /dinv/vmlinuz
COPY build/initrd.img /dinv/initrd.img
COPY entrypoint.sh /entrypoint.sh

VOLUME ["/docker", "/volume"]

ENV DINV_CPUS 1
ENV DINV_MEMORY 512M
ENV DINV_TCP_PORTS ""
ENV DINV_UDP_PORTS ""
ENV DINV_MOUNTS ""
ENV DINV_DOCKER_SIZE "64G"
ENV DINV_VOLUME_PATH ""
ENV DINV_VOLUME_SIZE "64G"
ENV DINV_VOLUME_UID "0"
ENV DINV_VOLUME_GID "0"
ENV DINV_SHUTDOWN_TIMEOUT "5"
ENV DINV_MACHINE "microvm"

ENV DOCKER_HOST="tcp://127.0.0.1:2375"

EXPOSE 2375
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "docker", "info" ]