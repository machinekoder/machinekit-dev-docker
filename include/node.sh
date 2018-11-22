###########################
# Node
###########################
set -e
CLEANUP=${CLEANUP:-true}

if [ -z "${SUDO}"]; then
   curl -sL https://deb.nodesource.com/setup_9.x | bash -
else
    curl -sL https://deb.nodesource.com/setup_9.x | ${SUDO} -E bash -
fi
${SUDO} apt install -y nodejs

###########################
# Clean up
###########################
if $CLEANUP; then
    ${SUDO} apt-get clean
fi
