#!/bootstrap/sh

# busybox wget does not support SSL
/bootstrap/sh -c "/bootstrap/wget -O /bootstrap/archlinux.tar.gz http://mirrors.dotsrc.org/archlinuxarm/os/ArchLinuxARM-aarch64-latest.tar.gz && /bootstrap/tar --exclude=./etc/resolv.conf --exclude=./etc/hostname --exclude=./etc/hosts -xvf /bootstrap/archlinux.tar.gz -C / && /usr/sbin/chmod +x /root/install.sh && /bin/bash -c /root/install.sh"