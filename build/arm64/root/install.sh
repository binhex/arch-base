#!/bin/bash

# exit script if return code != 0
set -e

# set arch for base image
OS_ARCH="aarch64"

# construct snapshot date (cannot use todays as archive wont exist) and set url for archive.
# note: for arch linux arm archive repo that the snapshot date has to be at least 2 days
# previous as the mirror from live to the archive for arm packages is slow
snapshot_date=$(date -d "2 days ago" +%Y/%m/%d)

# now set pacman to use snapshot for packages for snapshot date
if [[ "${OS_ARCH}" == "aarch64" ]]; then
	echo 'Server = http://tardis.tiny-vps.com/aarm/repos/'"${snapshot_date}"'/$arch/$repo' > '/etc/pacman.d/mirrorlist'
	echo 'Server = http://eu.mirror.archlinuxarm.org/$arch/$repo' >> '/etc/pacman.d/mirrorlist'
else
	echo 'Server = https://archive.archlinux.org/repos/'"${snapshot_date}"'/$repo/os/$arch' > '/etc/pacman.d/mirrorlist'
	echo 'Server = http://archive.virtapi.org/repos/'"${snapshot_date}"'/$repo/os/$arch' >> '/etc/pacman.d/mirrorlist'
fi

echo "[info] content of arch mirrorlist file"
cat '/etc/pacman.d/mirrorlist'

# reset gpg (not required when source is bootstrap tarball, but keeping for historic reasons)
rm -rf '/etc/pacman.d/gnupg/' '/root/.gnupg/' || true

# dns resolution reconfigure is required due to the tarball extraction
# overwriting the /etc/resolv.conf, thus we then need to fix this up
# before we can continue to build the image.
#echo "[info] Setting DNS resolvers to Cloudflare..."
#echo "nameserver 1.1.1.1" > '/etc/resolv.conf' || true
#echo "nameserver 1.0.0.1" >> '/etc/resolv.conf' || true

# refresh gpg keys
gpg --refresh-keys

# initialise key for pacman and populate keys
if [[ "${OS_ARCH}" == "aarch64" ]]; then
	pacman-key --init && pacman-key --populate archlinuxarm
else
	pacman-key --init && pacman-key --populate archlinux
fi

# force use of protocol http and ipv4 only for keyserver (defaults to hkp)
echo "no-greeting" > '/etc/pacman.d/gnupg/gpg.conf'
echo "no-permission-warning" >> '/etc/pacman.d/gnupg/gpg.conf'
echo "lock-never" >> '/etc/pacman.d/gnupg/gpg.conf'
echo "keyserver https://keyserver.ubuntu.com" >> '/etc/pacman.d/gnupg/gpg.conf'
echo "keyserver-options timeout=10" >> '/etc/pacman.d/gnupg/gpg.conf'

# perform pacman refresh with retries (required as keyservers are unreliable)
count=0
echo "[info] refreshing keys for pacman..."
until pacman-key --refresh-keys || (( count++ >= 3 ))
do
	echo "[warn] failed to refresh keys for pacman, retrying in 30 seconds..."
	sleep 30s
done

# force pacman db refresh and install sed package (used to do package folder exclusions)
pacman -Sy sed --noconfirm

# configure pacman to not extract certain folders from packages being installed
# this is done as we strip out locale, man, docs etc when we build the arch-scratch image
sed -i '\~\[options\]~a # Do not extract the following folders from any packages being installed\n'\
'NoExtract   = usr/share/locale* !usr/share/locale/en* !usr/share/locale/locale.alias\n'\
'NoExtract   = usr/share/doc*\n'\
'NoExtract   = usr/share/man*\n'\
'NoExtract   = usr/lib/firmware*\n'\
'NoExtract   = usr/lib/modules*\n'\
'NoExtract   = usr/share/gtk-doc*\n' \
'/etc/pacman.conf'

# list all packages that we want to exclude/remove
unneeded_packages="\
filesystem \
cryptsetup \
device-mapper \
dhcpcd \
iproute2 \
jfsutils \
libsystemd \
linux \
lvm2 \
man-db \
man-pages \
mdadm \
netctl \
openresolv \
pciutils \
pcmciautils \
reiserfsprogs \
s-nail \
systemd \
systemd-sysvcompat \
usbutils \
xfsprogs"

# split space separated string into list for install paths
IFS=' ' read -ra unneeded_packages_list <<< "${unneeded_packages}"

# construct string to ensure removal of any packages that might be part of tarball
pacman_remove_unneeded_packages='pacman --noconfirm -Rsc'

for i in "${unneeded_packages_list[@]}"; do
	pacman_remove_unneeded_packages="${pacman_remove_unneeded_packages} ${i}"
done

echo "[info] Removing unneeded packages that might be part of the tarball..."
echo "${pacman_remove_unneeded_packages} || true"
eval "${pacman_remove_unneeded_packages} || true"

echo "[info] Adding required packages to pacman ignore package list to prevent upgrades..."

# add coreutils to pacman ignore list to prevent permission denied issue on Docker Hub -
# https://gitlab.archlinux.org/archlinux/archlinux-docker/-/issues/32
#
# add filesystem to pacman ignore list to prevent buildx issues with
# /etc/hosts and /etc/resolv.conf being read only, see issue -
# https://github.com/moby/buildkit/issues/1267#issuecomment-768903038
#
sed -i -e 's~#IgnorePkg.*~IgnorePkg = filesystem~g' '/etc/pacman.conf'

echo "[info] Displaying contents of pacman config file, showing ignored packages..."
cat '/etc/pacman.conf'

echo "[info] Updating packages currently installed..."
pacman -Syu --noconfirm

echo "[info] Install base group and additional packages..."
pacman -S base awk sed grep gzip supervisor nano vi ldns moreutils net-tools dos2unix unzip unrar htop jq openssl-1.1 rsync --noconfirm

echo "[info] set locale..."
echo en_GB.UTF-8 UTF-8 > '/etc/locale.gen'
locale-gen
echo LANG="en_GB.UTF-8" > '/etc/locale.conf'

# add user "nobody" to primary group "users" (will remove any other group membership)
usermod -g users nobody

# add user "nobody" to secondary group "nobody" (will retain primary membership)
usermod -a -G nobody nobody

# setup env for user nobody
mkdir -p '/home/nobody'
chown -R nobody:users '/home/nobody'
chmod -R 775 '/home/nobody'

# set user "nobody" home directory (needs defining for pycharm, and possibly other apps)
usermod -d /home/nobody nobody

# set shell for user nobody
chsh -s /bin/bash nobody

# find latest dumb-init release tag from github
curl --connect-timeout 5 --max-time 600 --retry 5 --retry-delay 0 --retry-max-time 60 -o "/tmp/dumbinit_release_tag" -L "https://github.com/Yelp/dumb-init/releases"
dumbinit_release_tag=$(grep -P -o -m 1 '(?<=/Yelp/dumb-init/releases/tag/)[^"]+' < /tmp/dumbinit_release_tag)

# remove first character 'v' from string, used for url to download binary
dumbinit_release_tag_strip="${dumbinit_release_tag#?}"

# download dumb-init, used to do graceful exit when docker stop issued and correct reaping of zombie processes.
if [[ "${OS_ARCH}" == "aarch64" ]]; then
	curl --connect-timeout 5 --max-time 600 --retry 5 --retry-delay 0 --retry-max-time 60 -o "/usr/bin/dumb-init" -L "https://github.com/Yelp/dumb-init/releases/download/${dumbinit_release_tag}/dumb-init_${dumbinit_release_tag_strip}_aarch64" && chmod +x "/usr/bin/dumb-init"
else
	curl --connect-timeout 5 --max-time 600 --retry 5 --retry-delay 0 --retry-max-time 60 -o "/usr/bin/dumb-init" -L "https://github.com/Yelp/dumb-init/releases/download/${dumbinit_release_tag}/dumb-init_${dumbinit_release_tag_strip}_x86_64" && chmod +x "/usr/bin/dumb-init"
fi

# identify if base-devel package installed
if pacman -Qg "base-devel" > /dev/null ; then

	# remove base devel excluding useful core packages
	pacman -Ru $(pacman -Qgq base-devel | grep -v awk | grep -v pacman | grep -v sed | grep -v grep | grep -v gzip | grep -v which) --noconfirm

fi

# remove any build tools that maybe present from the build
pacman -Ru dotnet-sdk yarn git yay-bin reflector gcc binutils --noconfirm 2> /dev/null || true

# general cleanup
yes|pacman -Scc
pacman --noconfirm -Rns $(pacman -Qtdq) 2> /dev/null || true
rm -rf /var/cache/* \
/var/empty/.cache/* \
/usr/share/locale/* \
/usr/share/man/* \
/usr/share/gtk-doc/* \
/tmp/*

# additional cleanup for base only
rm -rf /root/* \
/var/cache/pacman/pkg/* \
/usr/lib/firmware \
/usr/lib/modules \
/.dockerenv \
/.dockerinit \
/usr/share/info/* \
/README \
/bootstrap
