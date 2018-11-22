#!/usr/bin/env bash

if test "$ENV_COOKIE" = docker; then
    echo "This script cannot run inside a container" >&2
    exit 1
fi

while getopts bn:i:?h ARG; do
    case $ARG in
    b) BUILD=true; break ;; # following args go to `docker build` cmd
    n) NAME=$OPTARG ;;
    i) IMAGE=$OPTARG ;;
    ?|h)
        echo "Usage: $0 [ -i IMAGE ] [ -b | CMD ARG ... ]" >&2
        exit
        ;;
    *) usage "Unknown arg: '-$ARG'" ;;
    esac
done
shift $(($OPTIND-1))
BUILD=${BUILD:-false}
TAG=${TAG:-develop}
IMAGE=${IMAGE:-machinekoder/machinekit:$TAG}
LINK_CONTAINER=${LINK_CONTAINER:+--link=${LINK_CONTAINER}}
NAME=${NAME:-machinekit}

if $BUILD; then
    cd $(dirname $0)
    set -x
    exec docker build -t "${IMAGE}" \
     ${DOCKER_DEV_BUILD_OPTS[@]} \
     ${BUILD_ARGS} \
     "$@" .
fi

# Detect video driver
VIDEO_INTEL=${VIDEO_INTEL:-false}
VIDEO_NVIDIA=${VIDEO_NVIDIA:-false}
VIDEO_ATI=${VIDEO_ATI:-false}
case $(glxinfo | sed -n '/OpenGL vendor string/ s/^.*: // p') in
    "Intel Open Source Technology Center") VIDEO_INTEL=true ;;
    "NVIDIA Corporation") VIDEO_NVIDIA=true ;;
esac

if test $VIDEO_NVIDIA = true; then
    echo "detected NVIDIA graphics card"
    OTHER_OPTS="--runtime=nvidia \
              -e NVIDIA_VISIBLE_DEVICES=all \
              -e NVIDIA_DRIVER_CAPABILITIES=graphics \
    "
fi

# Check if container is running
docker exec ${NAME} true 2>/dev/null
RUNNING=$?

if [ $RUNNING -ne 0 ]; then
C_UID=$(id -u)
C_GID=$(id -g)
set -x
exec docker run --rm \
    --network host \
    -it --privileged \
    -e UID=${C_UID} \
    -e GID=${C_GID} \
    -e QT_X11_NO_MITSHM=1 \
    -e XDG_RUNTIME_DIR \
    -e HOME \
    -e USER \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e DISPLAY \
    -v /dev/dri:/dev/dri \
    -v $HOME:$HOME \
    -v $PWD:$PWD \
    -v $XDG_RUNTIME_DIR:$XDG_RUNTIME_DIR \
    -w $PWD \
    -h ${NAME} --name ${NAME} \
    ${DOCKER_DEV_OPTS[@]} \
    ${OTHER_OPTS} \
    ${LINK_CONTAINER} \
    ${IMAGE} "$@"
else
set -x
exec docker exec --user `whoami` -it ${NAME} /bin/bash --login -i
fi
