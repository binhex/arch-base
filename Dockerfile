FROM scratch
MAINTAINER binhex

# additional files
##################

# add supervisor conf file
ADD build/*.conf /etc/supervisor.conf

# add install bash script
ADD build/root/*.sh /root/

# add statically linked busybox
ADD build/utils/busybox/busybox /bootstrap/busybox

# unpack tarball
################

# symlink busybox utilities to /bootstrap folder
RUN ["/bootstrap/busybox", "--install", "-s", "/bootstrap"]

# run busybox bourne shell and use sub shell to execute busybox utils (wget, rm...)
# to download and extract tarball. 
# once the tarball is extracted we then use bash to execute the install script to
# install everything else for the base image.
# note, do not line wrap the below command, as it will fail looking for /bin/sh
RUN ["/bootstrap/sh", "-c", "rel_date=$(/bootstrap/date +%Y.%m.01) && /bootstrap/wget -O /bootstrap/archlinux.tar.gz http://archlinux.de-labrusse.fr/iso/latest/archlinux-bootstrap-${rel_date}-x86_64.tar.gz && /bootstrap/tar -xvf /bootstrap/archlinux.tar.gz --overwrite --strip-components=1 -C / ; /bootstrap/rm -rf /bootstrap /.dockerenv /.dockerinit /usr/share/info/* && /bin/bash -c 'chmod +x /root/*.sh && /bin/bash /root/install.sh'"]

# env
#####

# set environment variables for user nobody
ENV HOME /home/nobody

# set environment variable for terminal
ENV TERM xterm

# set environment variables for language
ENV LANG en_GB.UTF-8

# run
#####

# run tini to manage graceful exit and zombie reaping
ENTRYPOINT ["/usr/bin/tini", "--"]
