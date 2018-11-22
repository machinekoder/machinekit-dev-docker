from debian:stretch

# Configure & update apt
ENV DEBIAN_FRONTEND noninteractive
RUN echo 'APT::Install-Recommends "0";\nAPT::Install-Suggests "0";' > \
        /etc/apt/apt.conf.d/01norecommend
ARG DEBIAN_MIRROR=deb.debian.org
ARG DEBIAN_SECURITY_MIRROR=security.debian.org
RUN bash -c "( \
        echo deb http://${DEBIAN_MIRROR}/debian stretch main; \
        echo deb http://${DEBIAN_MIRROR}/debian stretch-updates main; \
        echo deb http://${DEBIAN_SECURITY_MIRROR}/debian-security \
            stretch/updates main; \
        ) > /etc/apt/sources.list"
RUN apt-get update
RUN apt-get upgrade -y && \
    apt-get clean

# silence debconf warnings
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get install -y \
    libfile-fcntllock-perl && \
    apt-get clean

# Install and configure sudo, passwordless for everyone
RUN apt-get install -y \
    sudo && \
    apt-get clean
RUN echo "ALL	ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

# Cookie variable for container environment
ENV ENV_COOKIE docker

###########################################
# Install packages
#
# Customize the following for building/running targeted software

# Install misc. packages
ARG EXTRA_PACKAGES
RUN apt-get install -y \
    ccache \
    ssh \
    gdb \
    wget \
    curl \
    lsb-release \
    gnupg2 \
    mesa-utils \
    libgl1-mesa-dri \
    ca-certificates \
    dirmngr \
    git \
    ${EXTRA_PACKAGES} \
    && apt-get clean

###########################################
# Graphics drivers
#
COPY include/glx.sh /tmp/install/
RUN bash /tmp/install/glx.sh

###########################################
# Install Machinekit
#
COPY include/mk.sh /tmp/install/
RUN bash /tmp/install/mk.sh

###########################################
# Install nodejs (for Machinetalk-protobuf)
#
COPY include/node.sh /tmp/install/
RUN bash /tmp/install/node.sh

###########################################
# Install Tools
#
COPY include/tools.sh /tmp/install/
RUN bash /tmp/install/tools.sh

RUN echo "cap_net_raw alexander" > /etc/security/capability.conf

###########################################
# Setup environment
#

# set locale for tools such as "black" to work correctly
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# nvidia-container-runtime
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES graphics

###########################################
# Set up user
#

# This shell script adds passwd and group entries for the user
COPY entrypoint.sh /usr/bin/entrypoint
ENTRYPOINT ["/usr/bin/entrypoint"]
# If no args to `docker run`, start an interactive shell
CMD ["/bin/bash", "--login", "-i"]
