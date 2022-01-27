# dinv (Docker in VM)

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

|                            | DooD                                                 | DinD                                     | Sysbox                  | DinV                                                                                                                                                          |
|----------------------------|------------------------------------------------------|------------------------------------------|-------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Additional parameters      | `-v /var/run/docker.sock:/var/run/docker.sock`       | `--privileged`                           | `--runtime=sysbox-runc` | `--device /dev/kvm`                                                                                                                                           |
| Require special runtime    | No                                                   | No                                       | Yes                     | No                                                                                                                                                            |
| `dockerd` separation       | Shared with host (no separation)                     | Separated                                | Separated               | Separated                                                                                                                                                     |
| Security                   | Container can create/delete/modify host's containers | Weak isolation (require privileged mode) | ?                       | Strong isolation (VM isolation + unprivileged)                                                                                                                |
| Compute/memory performance | Native                                               | Native                                   | ?                       | Near-native (VT-x accelerated)                                                                                                                                |
| Networking performance     | Native                                               | Native                                   | ?                       | Poor (depends on [SLIRP](https://wiki.qemu.org/Documentation/Networking#User_Networking_.28SLIRP.29))                                                         |
| I/O performance            | Native                                               | Native                                   | ?                       | Near-native (`docker volume` (private), depending on `virtio-blk`), Poor (bind mounts, depending on [virtio-9p](https://wiki.qemu.org/Documentation/9psetup)) |

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

### Port Forwarding (Currently Not Working)

* Note: you have to specifiy forwared ports via `DINV_TCP_PORTS` environment variable. Semicolon-separated list is allowed.

```bash
$ docker run -d --rm -p8080:8080 -e DINV_TCP_PORTS=8080 --name dinv --device /dev/kvm pusnow/dinv:latest
$ # wait few seconds
$ docker exec -it dinv docker run -d -p8080:80 --rm nginx
$ curl http://127.0.0.1:8080
```

### Bind Mount

* Note: you have to specifiy bind mounts via `DINV_MOUNTS` environment variable. Semicolon-separated list is allowed.

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

## TODO

- Graceful shutdown
- virtio-fs (current QEMU microVM does not support it)
- Port forwarding (it is due to IP conflit between host network and VM network)