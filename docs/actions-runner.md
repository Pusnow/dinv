# Using GitHub Actions Runner with DinV

To run [GitHub actions runner for docker](https://github.com/myoung34/docker-github-actions-runner), DinV provides two options: using DinV volume or sharing volume via virtio-9p.
Since virtio-9p shows very poor performance, we recommend using DinV volume.

### Option 1: Run actions runner using DinV volume (Recommended)

* `/workspace` in VM disk image
* Pro: fast disk I/O
* Con: invisible `/workspace` (lies in VM disk image)

#### Layout

```
┌Host docker───────────────────────────────┐
│ ┌dinv docker───────────────────────────┐ │
│ │ ┌─actions runner───────────────────┐ │ │
│ │ │                                  │ │ │
│ │ │ bind mount: /var/run/docker.sock │ │ │
│ │ │                                  │ │ │
│ │ └──────────────────────────────────┘ │ │
│ └──────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

#### Docker Compose

```yaml
version: "3.5"

services:
  runner:
    image: pusnow/dinv:latest
    restart: always
    devices:
      - /dev/kvm
    networks:
      - default
    command:
      - docker
      - run
      - -d
      - --restart
      - always
      - --name
      - github-runner
      - -v
      - /var/run/docker.sock:/var/run/docker.sock
      - -v
      - /workspace:/workspace
      - -e RUNNER_WORKDIR="/workspace"
      - -e ...
      - myoung34/github-runner:latest
    volumes:
      - runner-volume:/volume
      - docker-image:/docker
    environment:
      - DINV_VOLUME_PATH=/workspace
volumes: 
  runner-volume:
  docker-image:
networks:
  default:
```



### Option 2: actions runner using virtio-9p

* `workspace` is shared by virtio-9p
* Pro: workspace is visible
* Con: terribly slow I/O (virtio-9p)


#### Layout

```
┌Host docker───────────────────────────────┐
│ ┌actions runner────┐ ┌dinv docker──────┐ │
│ │                  │ │                 │ │
│ │  DOCKER_HOST:    │ │                 │ │
│ │  dinv docker     │ │                 │ │
│ │                  │ │                 │ │
│ └──────────────────┘ └─────────────────┘ │
└──────────────────────────────────────────┘
```

#### Docker Compose

```yaml
version: "3.5"

services:
  runner:
    image: myoung34/github-runner:debian-bullseye
    restart: always
    networks: 
      - default
      - runner
    volumes:
      - runner-data:/workspace
    environment:
      - DOCKER_HOST=tcp://docker:2375
      - RUNNER_WORKDIR="/workspace"
      - RUNNER_NAME=...
      - ...
    depends_on: 
      - docker
  docker:
    image: pusnow/dinv:latest
    hostname: docker
    restart: always
    devices:
      - /dev/kvm
    networks:
      - runner
    volumes:
      - runner-data:/workspace
      - docker-image:/docker
    environment:
      - DINV_MOUNTS=/workspace
volumes: 
  runner-data:
  docker-image:
networks:
  default:
  runner:
```