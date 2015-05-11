#!/bin/bash

# update arch repo list with uk mirrors
echo 'Server = http://mirror.bytemark.co.uk/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
echo 'Server = http://mirror.cinosure.com/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = http://mirrors.manchester.m247.com/arch-linux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = http://www.mirrorservice.org/sites/ftp.archlinux.org/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = http://arch.serverspace.co.uk/arch/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = http://archlinux.mirrors.uk2.net/$repo/os/$arch' >> /etc/pacman.d/mirrorlist

# set locale
echo en_GB.UTF-8 UTF-8 > /etc/locale.gen
locale-gen
echo LANG="en_GB.UTF-8" > /etc/locale.conf

# setup env for user nobody
mkdir -p /home/nobody
chown -R nobody:users /home/nobody
chmod -R 775 /home/nobody

# update pacman and db
pacman -Sy --noconfirm
pacman -S pacman --noconfirm
pacman-db-upgrade

# refresh keys for pacman
mkdir -p /home/nobody/.gnupg/
touch /home/nobody/.gnupg/dirmngr_ldapservers.conf
pacman-key --refresh-keys

# update packages
pacman -Syu --ignore filesystem --noconfirm

# install supervisor
pacman -S supervisor --noconfirm

# cleanup
yes|pacman -Scc
rm -rf /usr/share/locale/*
rm -rf /usr/share/man/*
rm -rf /root/*
rm -rf /tmp/*
