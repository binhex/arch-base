#!/bootstrap/sh

# get target arch from first parameter (defined in Dockerfile as arg)
TARGETARCH="${1}"

# create vars for arch
if [ "${TARGETARCH}" = "amd64" ]; then
	url="http://mirror.bytemark.co.uk/archlinux/iso/latest/archlinux-bootstrap-x86_64.tar.gz"
	exclude="root.x86_64"
	strip="--strip-components=1"
else
	url="http://mirrors.dotsrc.org/archlinuxarm/os/ArchLinuxARM-aarch64-latest.tar.gz"
	exclude="."
	strip=""
fi

# download tarball, note busybox wget does not support SSL
/bootstrap/sh -c "/bootstrap/wget --timeout=60 -O /bootstrap/archlinux.tar.gz ${url} && /bootstrap/tar --exclude=${exclude}/etc/resolv.conf --exclude=${exclude}/etc/hosts -xvf /bootstrap/archlinux.tar.gz ${strip} -C / && /bin/bash -c 'chmod +x /bootstrap/*.sh && /bin/bash /bootstrap/install.sh ${TARGETARCH}'"