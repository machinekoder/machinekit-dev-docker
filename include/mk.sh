###########################
# Machinekit
###########################
set -e
CLEANUP=${CLEANUP:-true}
MK_REMOTE=https://github.com/machinekit/machinekit.git
#MK_REMOTE=

# Override this, e.g. `posix` for Docker or sim
if test "$ENV_COOKIE" == docker; then
    MK_THREAD_STYLE=${MK_THREAD_STYLE:-posix}
else
    MK_THREAD_STYLE=${MK_THREAD_STYLE:-rt-preempt}
fi

if test -n "$MK_REMOTE"; then
    # MK build deps
    ${SUDO} apt-get install -y \
            cython \
            uuid-runtime \
            libjansson-dev \
            libwebsockets-dev \
            libavahi-client-dev \
            avahi-daemon \
            libmodbus-dev \
            libreadline-dev \
            libzmq3-dev \
            libczmq-dev \
            devscripts \
            equivs \
            python-avahi \
            python-dbus \
            rsyslog

    git clone --depth=1 ${MK_REMOTE}
    cd machinekit

    # prepare environment
    ${SUDO} touch /var/log/linuxcnc.log
    ${SUDO} cp src/rtapi/rsyslogd-linuxcnc.conf /etc/rsyslog.d/linuxcnc.conf
    ${SUDO} cp src/rtapi/shmdrv/limits.d-machinekit.conf /etc/security/limits.d/machinekit.conf
    ${SUDO} service rsyslog restart

    # Set up Debianization
    case $MK_THREAD_STYLE in
        posix) CONFIG_ARGS=-pc ;;
        rt-preempt) CONFIG_ARGS=-rc ;;
    esac
    ./debian/configure $CONFIG_ARGS

    # Install build deps
    yes y | ${SUDO} mk-build-deps -ir

    cd ..
    rm -rf machinekit
else
    # Install upstream packages
    echo "deb http://deb.machinekit.io/debian stretch main" | \
        ${SUDO} tee /etc/apt/sources.list.d/machinekit.list
    ${SUDO} apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 43DDF224
    ${SUDO} apt-get update
    ${SUDO} apt-get install -y \
            machinekit-${MK_THREAD_STYLE}

    # - Enable remote
    ${SUDO} sed -i -e '/^REM/ s/0$/1/' /etc/linuxcnc/machinekit.ini
fi

# MachineTalk
# - Discovery debugging
${SUDO} apt-get install -y avahi-utils
# - MachineTalk python
${SUDO} apt-get install -y python-pip python-setuptools
${SUDO:+${SUDO} -H} pip install machinetalk-protobuf pymachinetalk
# - MK client
arch=x64
extension=AppImage
package=$(wget -qO- https://dl.bintray.com/machinekoder/MachinekitClient-Development/ | grep ${arch} | grep ${extension} | tail -n 1 | awk -F"\"" '{print $4}')
url=https://dl.bintray.com/machinekoder/MachinekitClient-Development/${package:1}
wget -O mk-client ${url}
${SUDO} mv mk-client /usr/bin/MachinekitClient
${SUDO} chmod +x /usr/bin/MachinekitClient
${SUDO} apt-get install -y fuse
# - Fix avahi-daemon in Docker
#   https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=856311#15
if test "$ENV_COOKIE" == docker; then
    ${SUDO} sed -i -e '/^rlimit-nproc/ s/^/#/' /etc/avahi/avahi-daemon.conf
fi


###########################
# Clean up
###########################
if $CLEANUP; then
    ${SUDO} apt-get clean
fi
