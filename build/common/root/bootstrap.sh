#!/bootstrap/sh

# app name from buildx arg, used in healthcheck to identify app and monitor correct process
APPNAME="${1}"
shift

# release tag name from buildx arg, stripped of build ver using string manipulation
RELEASETAG="${1}"
shift

# target arch from buildx arg
TARGETARCH="${1}"
shift

if [ -z "${APPNAME}" ]; then
	echo "[warn] App name from build arg is empty, exiting script..."
	exit 1
fi

if [ -z "${RELEASETAG}" ]; then
	echo "[warn] Release tag name from build arg is empty, exiting script..."
	exit 1
fi

if [ -z "${TARGETARCH}" ]; then
	echo "[warn] Target architecture name from build arg is empty, exiting script..."
	exit 1
fi

# create vars for arch, note busybox wget does not support SSL thus url is http
# handy list showing http/https servers is here https://archlinux.org/mirrorlist/all/
if [ "${TARGETARCH}" = "amd64" ]; then
	url="http://mirror.rackspace.com/archlinux/iso/latest/archlinux-bootstrap-x86_64.tar.zst"
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
/bootstrap/sh -c "/bootstrap/wget --timeout=60 -O /bootstrap/archlinux.tar.${compression} ${url} && ${decompress} && /bootstrap/tar --exclude=${exclude}/etc/resolv.conf --exclude=${exclude}/etc/hosts -xvf /bootstrap/archlinux.tar ${strip} -C / && /bin/bash -c 'chmod +x /bootstrap/*.sh && /bin/bash /bootstrap/install.sh ${APPNAME} ${RELEASETAG} ${TARGETARCH}'"