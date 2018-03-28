#!/bin/bash

# exit script if return code != 0
set -e

# construct yesterdays date (cannot use todays as archive wont exist) and set url for archive
yesterdays_date=$(date -d "yesterday" +%Y/%m/%d)

# now set pacman to use snapshot for packages for yesterdays date
echo 'Server = https://archive.archlinux.org/repos/'"${yesterdays_date}"'/$repo/os/$arch' > /etc/pacman.d/mirrorlist
echo 'Server = http://archive.virtapi.org/repos/'"${yesterdays_date}"'/$repo/os/$arch' >> /etc/pacman.d/mirrorlist

echo "[info] content of arch mirrorlist file"
cat /etc/pacman.d/mirrorlist

# reset gpg (not required when source is bootstrap tarball, but keeping for historic reasons)
rm -rf /etc/pacman.d/gnupg/ /root/.gnupg/ || true

# refresh gpg keys
gpg --refresh-keys

# initialise key for pacman and populate keys 
pacman-key --init && pacman-key --populate archlinux

# force use of protocol http and ipv4 only for keyserver (defaults to hkp)
echo "no-greeting" > /etc/pacman.d/gnupg/gpg.conf
echo "no-permission-warning" >> /etc/pacman.d/gnupg/gpg.conf
echo "lock-never" >> /etc/pacman.d/gnupg/gpg.conf
echo "keyserver hkp://ipv4.pool.sks-keyservers.net" >> /etc/pacman.d/gnupg/gpg.conf
echo "keyserver-options timeout=10" >> /etc/pacman.d/gnupg/gpg.conf

# refresh keys for pacman
pacman-key --refresh-keys

# force pacman db refresh and install sed package (used to do package folder exclusions)
pacman -Sy sed --noconfirm

# configure pacman to not extract certain folders from packages being installed
# this is done as we strip out locale, man, docs etc when we build the arch-scratch image
sed -i '\~\[options\]~a # Do not extract the following folders from any packages being installed\n'\
'NoExtract   = usr/share/locale* !usr/share/locale/en* !usr/share/locale/locale.alias\n'\
'NoExtract   = usr/share/doc*\n'\
'NoExtract   = usr/share/man*\n'\
'NoExtract   = usr/share/gtk-doc*\n' \
/etc/pacman.conf

# update packages currently installed
pacman -Syu --noconfirm

# install grep package (used to do package install exclusions)
pacman -S grep --noconfirm

# install base group packages with exclusions
pacman -S $(pacman -Sgq base | \
grep -v filesystem | \
grep -v cryptsetup | \
grep -v device-mapper | \
grep -v dhcpcd | \
grep -v iproute2 | \
grep -v jfsutils | \
grep -v libsystemd | \
grep -v linux | \
grep -v lvm2 | \
grep -v man-db | \
grep -v man-pages | \
grep -v mdadm | \
grep -v netctl | \
grep -v pciutils | \
grep -v pcmciautils | \
grep -v reiserfsprogs | \
grep -v s-nail | \
grep -v systemd | \
grep -v systemd-sysvcompat | \
grep -v usbutils | \
grep -v xfsprogs) \
 --noconfirm

# install additional packages
pacman -S awk sed supervisor nano vi ldns moreutils net-tools dos2unix unzip unrar htop jq openssl-1.0 --noconfirm

# set locale
echo en_GB.UTF-8 UTF-8 > /etc/locale.gen
locale-gen
echo LANG="en_GB.UTF-8" > /etc/locale.conf

# add user "nobody" to primary group "users" (will remove any other group membership)
usermod -g users nobody

# add user "nobody" to secondary group "nobody" (will retain primary membership)
usermod -a -G nobody nobody

# setup env for user nobody
mkdir -p /home/nobody
chown -R nobody:users /home/nobody
chmod -R 775 /home/nobody

# set user "nobody" home directory (needs defining for pycharm, and possibly other apps)
usermod -d /home/nobody nobody
 
# set shell for user nobody
chsh -s /bin/bash nobody
 
# force re-install of ncurses 6.x with 5.x backwards compatibility (can be removed onced all apps have switched over to ncurses 6.x)
curl --connect-timeout 5 --max-time 600 --retry 5 --retry-delay 0 --retry-max-time 60 -o /tmp/ncurses5-compat.tar.xz -L https://github.com/binhex/arch-packages/raw/master/compiled/ncurses5-compat-libs-6.0+20161224-1-x86_64.pkg.tar.xz
pacman -U /tmp/ncurses5-compat.tar.xz --noconfirm

# find latest tini release tag from github
curl --connect-timeout 5 --max-time 600 --retry 5 --retry-delay 0 --retry-max-time 60 -o /tmp/tini_release_tag -L https://github.com/krallin/tini/releases
tini_release_tag=$(cat /tmp/tini_release_tag | grep -P -o -m 1 '(?<=/krallin/tini/releases/tag/)[^"]+')

# download tini, used to do graceful exit when docker stop issued and correct reaping of zombie processes.
curl --connect-timeout 5 --max-time 600 --retry 5 --retry-delay 0 --retry-max-time 60 -o /usr/bin/tini -L "https://github.com/krallin/tini/releases/download/${tini_release_tag}/tini-amd64" && chmod +x /usr/bin/tini

# cleanup
yes|pacman -Scc
rm -rf /usr/share/locale/*
rm -rf /usr/share/man/*
rm -rf /usr/share/gtk-doc/*
rm -rf /root/*
rm -rf /tmp/*
