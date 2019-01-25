FROM scratch
MAINTAINER binhex

# additional files
##################

# add supervisor conf file
ADD build/*.conf /etc/supervisor.conf

# add install bash script
ADD build/root/*.sh /root/

# add statically linked busybox
ADD build/busybox/busybox /bootstrap/busybox

# unpack tarball
################

# symlink busybox utilities to /bootstrap folder
RUN ["/bootstrap/busybox", "--install", "-s", "/bootstrap"]

# run busybox bourne shell and use sub shell to execute busybox utils
# once we have tarball extracted then use bash to run script to 
# install everything else 
# note, do not line wrap the below command, as it will fail looking 
# for /bin/sh
RUN ["/bootstrap/sh", "-c", "/bootstrap/wget -O /bootstrap/archlinux.tar.bz2 https://github.com/binhex/arch-scratch/releases/download/2018032800/arch-root.tar.bz2; /bootstrap/tar -xvjf /bootstrap/archlinux.tar.bz2 -C /; /bootstrap/rm -rf /bootstrap /.dockerenv /.dockerinit /usr/share/info/*; /bin/bash -c 'chmod +x /root/*.sh && /root/install.sh'"]

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
