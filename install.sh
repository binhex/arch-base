#!/bin/bash

# exit script if return code != 0
set -e

# update arch repo list with uk mirrors
echo 'Server = http://archlinux.mirrors.uk2.net/$repo/os/$arch' > /etc/pacman.d/mirrorlist
echo 'Server = http://mirror.cinosure.com/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = http://mirrors.manchester.m247.com/arch-linux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = http://www.mirrorservice.org/sites/ftp.archlinux.org/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = http://arch.serverspace.co.uk/arch/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = http://mirror.bytemark.co.uk/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist

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
 
# update pacman and db
pacman -Sy --noconfirm
pacman -S pacman --noconfirm
pacman-db-upgrade

# refresh keys for pacman
dirmngr </dev/null
pacman-key --refresh-keys

# update packages
pacman -Syu --ignore filesystem --noconfirm

# install supervisor
pacman -S supervisor --noconfirm

# force re-install of ncurses 6.x with 5.x backwards compatibility (can be removed onced all apps have switched over to ncurses 6.x)
curl -o /tmp/ncurses5-compat-libs-6.0-2-x86_64.pkg.tar.xz -L https://github.com/binhex/arch-packages/releases/download/ncurses5-compat-libs-6.0-2/ncurses5-compat-libs-6.0-2-x86_64.pkg.tar.xz
pacman -U --force /tmp/ncurses5-compat-libs-6.0-2-x86_64.pkg.tar.xz --noconfirm

# cleanup
yes|pacman -Scc
rm -rf /usr/share/locale/*
rm -rf /usr/share/man/*
rm -rf /root/*
rm -rf /tmp/*
