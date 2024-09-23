#!/bootstrap/sh

# get release tag name (defined in Dockerfile as arg)
RELEASETAG="${1}"

# get target arch from first parameter (defined in Dockerfile as arg)
TARGETARCH="${2}"

# create vars for arch
if [ "${TARGETARCH}" = "x86_64" ]; then
	url="http://mirror.bytemark.co.uk/archlinux/iso/latest/archlinux-bootstrap-x86_64.tar.zst"
	exclude="root.x86_64"
	strip="--strip-components=1"
	compression="zst"
	decompress="/bootstrap/zstd -d /bootstrap/archlinux.tar.${compression}"
else
	url="http://mirrors.dotsrc.org/archlinuxarm/os/ArchLinuxARM-aarch64-latest.tar.gz"
	exclude="."
	strip=""
	compression="gz"
	decompress="/bootstrap/gzip -d /bootstrap/archlinux.tar.${compression}"
fi

# download tarball, note busybox wget does not support SSL
/bootstrap/sh -c "/bootstrap/wget --timeout=60 -O /bootstrap/archlinux.tar.${compression} ${url} && ${decompress} && /bootstrap/tar --exclude=${exclude}/etc/resolv.conf --exclude=${exclude}/etc/hosts -xvf /bootstrap/archlinux.tar ${strip} -C / && /bin/bash -c 'chmod +x /bootstrap/*.sh && /bin/bash /bootstrap/install.sh ${RELEASETAG} ${TARGETARCH}'"