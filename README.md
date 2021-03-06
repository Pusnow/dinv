# dinv (Docker in VM)

* [Korean version](https://www.pusnow.com/note/dinv/)

Run Docker containers in microVM in a Docker container

## Why dinv?

To build a dockerized CI pipeline, you may have to run docker inside a docker container (e.g., [building docker images in a Jenkins container](https://www.jenkins.io/doc/book/installing/docker/)).
However, due to the Docker container's permission, privileges, etc., spawning containers inside a container is a little bit tricky and sacrifices security.
[DinD (Docker-in-Docker)](https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/), for example, requires `--privileged` flag, and [using it should be avoided for security](https://docs.docker.com/engine/reference/commandline/run/#full-container-capabilities---privileged).
DooD (Docker-out-of-Docker), on the other hand, shares the host-side `dockerd` daemon by binding the host's docker control socket (`/var/run/docker.sock`).
This method does not require `--privileged` flag but allows direct access to the host-side `dockerd`, giving full view and permission of the daemon.
[Sysbox](https://github.com/nestybox/sysbox) is a special container runtime for this purpose; however, it requires host-side setup.

We build DinV (Docker-in-VM), which allows spawning containers in a docker container without `--privileged`, `dockerd` sharing, and a special runtime.
DinV uses [QEMU's microVM](https://qemu.readthedocs.io/en/latest/system/i386/microvm.html) to run a lightweight virtual machine with a separate Linux image ([Alpine Linux](https://www.alpinelinux.org)) and `dockerd` daemon.
Also, it supports port binding (via `hostfwd` of [SLIRP](https://wiki.qemu.org/Documentation/Networking#User_Networking_.28SLIRP.29)) and file system sharing (via [virtio-9p](https://wiki.qemu.org/Documentation/9psetup)).

|                            | DooD                                                 | DinD                                     | Sysbox                          | DinV                                                                                                                                                              |
|----------------------------|------------------------------------------------------|------------------------------------------|---------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Requirement                | Bind mounting of `/var/run/docker.sock`              | `--privileged` flag                      | Special runtime (`sysbox-runc`) | KVM device option (`--device /dev/kvm`)                                                                                                                           |
| Require special runtime    | No                                                   | No                                       | Yes                             | No                                                                                                                                                                |
| `dockerd` separation       | Shared with host (no separation)                     | Separated                                | Separated                       | Separated                                                                                                                                                         |
| Security                   | Container can create/delete/modify host's containers | Weak isolation (require privileged mode) | ?                               | Strong isolation (VM isolation + unprivileged)                                                                                                                    |
| Compute/memory performance | Native                                               | Native                                   | ?                               | Near-native (VT-x accelerated)                                                                                                                                    |
| Networking performance     | Native                                               | Native                                   | ?                               | Poor (depends on [SLIRP](https://wiki.qemu.org/Documentation/Networking#User_Networking_.28SLIRP.29))                                                             |
| I/O performance            | Native                                               | Native                                   | ?                               | [Volumes](https://docs.docker.com/storage/volumes/): Near-native (`virtio-blk`) <br> Bind mounts: Poor ([virtio-9p](https://wiki.qemu.org/Documentation/9psetup)) |

## Usage

### Basic Usage

```bash
$ docker run -d --rm --name dinv --device /dev/kvm pusnow/dinv:latest
$ # wait few seconds
$ docker exec -it dinv docker run -it --rm debian
Unable to find image 'debian:latest' locally
latest: Pulling from library/debian
0c6b8ff8c37e: Pull complete 
Digest: sha256:fb45fd4e25abe55a656ca69a7bef70e62099b8bb42a279a5e0ea4ae1ab410e0d
Status: Downloaded newer image for debian:latest
root@1ee213376f22:/# 
```

Or, you can use Docker management port.

```bash
$ docker run -d --rm --name dinv --device /dev/kvm -p127.0.0.1:2375:2375 pusnow/dinv:latest
$ # wait few seconds
$ docker -H tcp://127.0.0.1:2375 ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
$ DOCKER_HOST="tcp://127.0.0.1:2375" docker ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

### Port Forwarding

* Note: you have to specifiy forwared ports via `DINV_TCP_PORTS` environment variable. Semicolon-separated list is allowed.
* Note 2: DinV uses a bridged network (172.19.0.0/16) inside VM. Make sure your host docker network does not use the range (Docker's default network range is 172.17.0.0/16).

```bash
$ docker run -d --rm -p8080:8080 -e DINV_TCP_PORTS=8080 --name dinv --device /dev/kvm pusnow/dinv:latest
$ # wait few seconds
$ docker exec -it dinv docker run -d -p8080:80 --rm nginx
$ curl http://127.0.0.1:8080
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

### Bind Mount

* Note: you have to specifiy bind mounts via `DINV_MOUNTS` environment variable. Semicolon-separated list is allowed.
* Note: we've found virtio-9p is terribly slow. Please, avoid I/O heavy workloads on it.

```bash
$ mkdir -p data && echo "Hello world" > data/hello.txt
$ cat data/hello.txt
Hello world
$ docker run -d --rm -v $PWD/data:/data -e DINV_MOUNTS=/data --name dinv --device /dev/kvm pusnow/dinv:latest
$ # wait few seconds
$ docker exec -it dinv docker run -it -v/data:/data debian cat /data/hello.txt
Unable to find image 'debian:latest' locally
latest: Pulling from library/debian
0c6b8ff8c37e: Pull complete 
Digest: sha256:fb45fd4e25abe55a656ca69a7bef70e62099b8bb42a279a5e0ea4ae1ab410e0d
Status: Downloaded newer image for debian:latest
Hello world
```

### Environment Variables

| Name                    | Description                                                                                   |
|-------------------------|-----------------------------------------------------------------------------------------------|
| `DINV_CPUS`             | Number of CPUS for VM (default: 1)                                                            |
| `DINV_MEMORY`           | Amount of memory for VM (default: 512M)                                                       |
| `DINV_TCP_PORTS`        | TCP port numbers for forwarding. Semicolon-separated list (default: none)                     |
| `DINV_UDP_PORTS`        | UDP port numbers for forwarding. Semicolon-separated list (default: none)                     |
| `DINV_MOUNTS`           | Paths for bind mounts. Semicolon-separated list (default: none)                               |
| `DINV_DOCKER_SIZE`      | Initial size of Docker VM disk for `/var/lib/docker` (default: 64G)                           |
| `DINV_VOLUME_PATH`      | If specified, DinV mount an additional VM disk image on the path (default: none)              |
| `DINV_VOLUME_SIZE`      | Initial size of the `DINV_VOLUME_PATH` VM disk image                                          |
| `DINV_VOLUME_UID`       | UID of the `DINV_VOLUME_PATH`                                                                 |
| `DINV_VOLUME_GID`       | GID of the `DINV_VOLUME_PATH`                                                                 |
| `DINV_DOCKER_SOCK_UID`  | UID of the `/var/run/docker.sock`                                                             |
| `DINV_DOCKER_SOCK_GID`  | GID of the `/var/run/docker.sock`                                                             |
| `DINV_SHUTDOWN_TIMEOUT` | DinV `dockerd`'s shutdown time out value (default: 5)                                         |
| `DINV_MACHINE`          | DinV machine type. Use `microvm` for a microVM and `q35` for a normal VM (default: `microvm`) |


### Volumes

| Path      | Description                                                            |
|-----------|------------------------------------------------------------------------|
| `/docker` | VM disk image store for Docker (`/var/lib/docker`)                     |
| `/volume` | VM disk image store for an additioanl DinV volume (`DINV_VOLUME_PATH`) |

### Ports

| Port Number | Description         |
|-------------|---------------------|
| `2375`      | Docker control port |

## TODO

* virtio-fs (current QEMU microVM does not support it)
