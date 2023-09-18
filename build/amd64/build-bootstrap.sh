#!/bootstrap/sh

# busybox wget does not support SSL
/bootstrap/sh -c "/bootstrap/wget --timeout=60 -O /bootstrap/archlinux.tar.gz http://mirror.bytemark.co.uk/archlinux/iso/latest/archlinux-bootstrap-x86_64.tar.gz && /bootstrap/tar --exclude=root.x86_64/etc/resolv.conf --exclude=root.x86_64/etc/hosts -xvf /bootstrap/archlinux.tar.gz --strip-components=1 -C / && /bin/bash -c 'chmod +x /root/*.sh && /bin/bash /root/install.sh'"