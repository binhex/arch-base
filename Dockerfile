FROM scratch
LABEL org.opencontainers.image.authors="binhex"
LABEL org.opencontainers.image.source="https://github.com/binhex/arch-base"

# release tag name from buildx arg
ARG RELEASETAG

# arch from buildx --platform, e.g. amd64 and arm64
ARG TARGETARCH

# additional files
##################

# add supervisor conf file
ADD build/common/root/*.conf /etc/supervisor.conf

# add install bash script
ADD build/common/root/*.sh /bootstrap/

# add statically linked busybox for target arch
ADD build/${TARGETARCH}/utils/busybox/busybox /bootstrap/busybox

# unpack tarball
################

# symlink busybox utilities to /bootstrap folder
# we use the exec form of RUN to avoid shell processing (the insertion of /bin/sh -c)
# as we do not have this available at this point.
RUN ["/bootstrap/busybox", "--install", "-s", "/bootstrap"]

# we need to define the boostrap shell otherwise docker assume /bin/sh which does
# not exist at this point, it also means we do not need to use the exec form of RUN
# and therefore wont get tripped up with shell processing the arguments.
SHELL ["/bootstrap/sh", "-c"]

# run busybox bourne shell and use sub shell to execute busybox utils (wget, rm...)
# to download and extract tarball.
# once the tarball is extracted we then use bash to execute the install script to
# install everything else for the base image.
# note, do not line wrap the below command, as it will fail looking for /bin/sh
RUN /bootstrap/bootstrap.sh "${RELEASETAG}" "${TARGETARCH}"

# once the bootstrap has run we set the shell back to the default for use in subsequently
# built images from this base image
SHELL ["/bin/sh", "-c"]

# env
#####

# set environment variables for user nobody
ENV HOME=/home/nobody

# set environment variable for terminal
ENV TERM=xterm

# set environment variables for language
ENV LANG=en_GB.UTF-8

# run
#####

# run dumb-init to manage graceful exit and zombie reaping
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
