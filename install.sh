#!/bin/bash

# update arch repo list
echo 'Server = http://mirror.bytemark.co.uk/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist

# set locale
echo en_GB.UTF-8 UTF-8 > /etc/locale.gen
locale-gen
echo LANG="en_GB.UTF-8" > /etc/locale.conf

# setup env for user nobody
mkdir -p /home/nobody
chown -R nobody:users /home/nobody
chmod -R 775 /home/nobody	

# update pacman, upgrade packages
pacman -Sy --noconfirm
pacman -S pacman --noconfirm
pacman-db-upgrade
pacman -Syu --ignore filesystem --noconfirm

# install supervisor
pacman -S supervisor --noconfirm

# cleanup
yes|pacman -Scc
rm -rf /usr/share/locale/*
rm -rf /usr/share/man/*
rm -rf /root/*
rm -rf /tmp/*
