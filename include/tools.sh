###########################
# Tools
###########################
set -e
CLEANUP=${CLEANUP:-true}

# install CLion dependency
${SUDO} apt-get install -y \
        openjdk-8-jdk \
        cmake

${SUDO} apt-get install -y \
        arping \
        net-tools

###########################
# Clean up
###########################
if $CLEANUP; then
    ${SUDO} apt-get clean
fi
