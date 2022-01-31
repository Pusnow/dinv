# Using Jenkins with DinV


## Step 1: Jenkins Dockerfile

Befor running Jenkins, you should make Jenkins `Dockerfile` by following step 4 of [https://www.jenkins.io/doc/book/installing/docker/#on-macos-and-linux](https://www.jenkins.io/doc/book/installing/docker/#on-macos-and-linux).
In this instruction, the Jenkins Dockerfile is stored in a `jenkins` folder.

## Step 2: Run Jenkins

To run Jenkins, DinV provides two options: using DinV volume or sharing volume via virtio-9p.
Since virtio-9p shows very poor performance, we recommend using DinV volume.

### Step 2-1: Run Jenkins using DinV volume (Recommended)

* `jenkins_home` in VM disk image
* Pro: fast disk I/O
* Con: invisible `jenkins_home` (lies in VM disk image)

#### Layout

```
┌Host docker───────────────────────────────┐
│ ┌dinv docker───────────────────────────┐ │
│ │ ┌─Jenkins ─────────────────────────┐ │ │
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
  jenkins:
    image: pusnow/dinv:latest
    restart: always
    devices:
      - /dev/kvm
    ports:
      - 8080:8080
    networks:
      - default
    commands:
      - sh
      - /jenkins/run.sh
    volumes:
      - jenkins-volume:/volume
      - docker-image:/docker
      - $PWD/jenkins:/jenkins
    environment:
      - DINV_TCP_PORTS=8080
      - DINV_VOLUME_PATH=/var/jenkins_home
volumes: 
  jenkins-volume:
  docker-image:
networks:
  default:
```



### Step 2-2: Jenkins using virtio-9p

* `jenkins_home` is shared by virtio-9p
* Pro: jenkins_home is visible
* Con: terribly slow I/O (virtio-9p)


#### Layout

```
┌Host docker───────────────────────────────┐
│ ┌Jenkins ──────────┐ ┌dinv docker──────┐ │
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
  jenkins:
    build: jenkins
    restart: always
    networks: 
      - default
      - jenkins
    volumes:
      - jenkins-data:/var/jenkins_home
    environment:
      - DOCKER_HOST=tcp://docker:2375
    ports:
      - "8080:8080"
    depends_on: 
      - docker
    labels:
  docker:
    image: pusnow/dinv:latest
    hostname: docker
    restart: always
    devices:
      - /dev/kvm
    networks:
      - jenkins
    volumes:
      - jenkins-data:/var/jenkins_home
      - docker-image:/docker
    environment:
      - DINV_MOUNTS=/var/jenkins_home
volumes: 
  jenkins-data:
  docker-image:
networks:
  default:
  jenkins:
```