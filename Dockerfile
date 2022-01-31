ARG ALPINE_VERION=latest
FROM alpine:${ALPINE_VERION}

RUN apk add --no-cache qemu-system-x86_64 qemu-img docker-cli

COPY build/root.qcow2 /dinv/root.qcow2
COPY build/vmlinuz /dinv/vmlinuz
COPY build/initrd.img /dinv/initrd.img
COPY entrypoint.sh /entrypoint.sh

VOLUME ["/docker"]

ENV DINV_CPUS 1
ENV DINV_MEMORY 512M
ENV DINV_TCP_PORTS ""
ENV DINV_UDP_PORTS ""
ENV DINV_MOUNTS ""
ENV DINV_DOCKER_SIZE "64G"
ENV DOCKER_HOST="tcp://127.0.0.1:2375"

EXPOSE 2375
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "docker", "info" ]