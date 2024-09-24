#!/bootstrap/sh

# get release tag name (defined in Dockerfile as arg)
RELEASETAG="${1}"

# get target arch from first parameter (defined in Dockerfile as arg)
TARGETARCH="${2}"

# create vars for arch, note busybox wget does not support SSL thus url is http
if [ "${TARGETARCH}" = "amd64" ]; then
	url="http://mirror.bytemark.co.uk/archlinux/iso/latest/archlinux-bootstrap-x86_64.tar.zst"
	exclude="root.x86_64"
	strip="--strip-components=1"
	compression="zst"
	decompress="/bootstrap/zstd -d /bootstrap/archlinux.tar.${compression}"
elif [ "${TARGETARCH}" = "arm64" ]; then
	url="http://mirrors.dotsrc.org/archlinuxarm/os/ArchLinuxARM-aarch64-latest.tar.gz"
	exclude="."
	strip=""
	compression="gz"
	decompress="/bootstrap/gzip -d /bootstrap/archlinux.tar.${compression}"
else
	echo "[warn] Target architecture name '${TARGETARCH}' from build arg is empty or unexpected, exiting script..."
	exit 1
fi

# download tarball
/bootstrap/sh -c "/bootstrap/wget --timeout=60 -O /bootstrap/archlinux.tar.${compression} ${url} && ${decompress} && /bootstrap/tar --exclude=${exclude}/etc/resolv.conf --exclude=${exclude}/etc/hosts -xvf /bootstrap/archlinux.tar ${strip} -C / && /bin/bash -c 'chmod +x /bootstrap/*.sh && /bin/bash /bootstrap/install.sh ${RELEASETAG} ${TARGETARCH}'"