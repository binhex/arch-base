#!/bin/bash

# exit script if return code != 0
set -e

touch /tmp/resolv.conf
ln -fs /tmp/resolv.conf /etc/resolv.conf

touch /tmp/hosts
ln -fs /tmp/hosts /etc/hosts

# construct snapshot date (cannot use todays as archive wont exist) and set url for archive
# note for arch linux arm archive repo that the snapshot date has to be at least 2 days
# previous as the mirror from live to the archive for arm packages is slow
snapshot_date=$(date -d "2 days ago" +%Y/%m/%d)

# now set pacman to use snapshot for packages for snapshot date
echo 'Server = https://archive.archlinux.org/repos/'"${snapshot_date}"'/$repo/os/$arch' > '/etc/pacman.d/mirrorlist'
echo 'Server = http://archive.virtapi.org/repos/'"${snapshot_date}"'/$repo/os/$arch' >> '/etc/pacman.d/mirrorlist'

echo "[info] content of arch mirrorlist file"
cat '/etc/pacman.d/mirrorlist'

# reset gpg (not required when source is bootstrap tarball, but keeping for historic reasons)
rm -rf '/etc/pacman.d/gnupg/' '/root/.gnupg/' || true

# dns resolution reconfigure is required due to the tarball extraction
# overwriting the /etc/resolv.conf, thus we then need to fix this up
# before we can continue to build the image.
echo "[info] Setting DNS resolvers to Cloudflare..."
echo "nameserver 1.1.1.1" > '/etc/resolv.conf' || true
echo "nameserver 1.0.0.1" >> '/etc/resolv.conf' || true

# refresh gpg keys
gpg --refresh-keys

# initialise key for pacman and populate keys 
pacman-key --init && pacman-key --populate archlinux

# force use of protocol http and ipv4 only for keyserver (defaults to hkp)
echo "no-greeting" > '/etc/pacman.d/gnupg/gpg.conf'
echo "no-permission-warning" >> '/etc/pacman.d/gnupg/gpg.conf'
echo "lock-never" >> '/etc/pacman.d/gnupg/gpg.conf'
echo "keyserver hkp://ipv4.pool.sks-keyservers.net" >> '/etc/pacman.d/gnupg/gpg.conf'
echo "keyserver-options timeout=10" >> '/etc/pacman.d/gnupg/gpg.conf'

# perform pacman refresh with retries (required as keyservers are unreliable)
count=0
echo "[info] refreshing keys for pacman..."
until pacman-key --refresh-keys || (( count++ >= 6 ))
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

echo "[info] Updating packages currently installed..."
pacman -Syu --noconfirm

echo "[info] Install base group and additional packages..."
pacman -S base awk sed grep gzip supervisor nano vi ldns moreutils net-tools dos2unix unzip unrar htop jq openssl-1.0 --noconfirm

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
 
# delme once fixed!!
# force downgrade of coreutils - fixes permission denied issue when building on docker hub
# https://gitlab.archlinux.org/archlinux/archlinux-docker/-/issues/32
curl --connect-timeout 5 --max-time 600 --retry 5 --retry-delay 0 --retry-max-time 60 -o /tmp/coreutils.tar.xz -L "https://github.com/binhex/arch-packages/raw/master/compiled/x86-64/coreutils.tar.xz"
pacman -U '/tmp/coreutils.tar.xz' --noconfirm

# add coreutils to pacman ignore list to prevent it being upgraded
sed -i -e 's~#IgnorePkg.*~IgnorePkg = coreutils~g' '/etc/pacman.conf'
# /delme once fixed!!

# force re-install of ncurses 6.x with 5.x backwards compatibility (can be removed once all apps have switched over to ncurses 6.x)
curl --connect-timeout 5 --max-time 600 --retry 5 --retry-delay 0 --retry-max-time 60 -o /tmp/ncurses5-compat.tar.xz -L "https://github.com/binhex/arch-packages/raw/master/compiled/x86-64/ncurses5-compat-libs.tar.xz"
pacman -U '/tmp/ncurses5-compat.tar.xz' --noconfirm

# find latest tini release tag from github
curl --connect-timeout 5 --max-time 600 --retry 5 --retry-delay 0 --retry-max-time 60 -o /tmp/tini_release_tag -L "https://github.com/krallin/tini/releases"
tini_release_tag=$(cat /tmp/tini_release_tag | grep -P -o -m 1 '(?<=/krallin/tini/releases/tag/)[^"]+')

# download tini, used to do graceful exit when docker stop issued and correct reaping of zombie processes.
curl --connect-timeout 5 --max-time 600 --retry 5 --retry-delay 0 --retry-max-time 60 -o /usr/bin/tini -L "https://github.com/krallin/tini/releases/download/${tini_release_tag}/tini-amd64" && chmod +x /usr/bin/tini

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
