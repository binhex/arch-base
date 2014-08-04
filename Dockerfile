FROM base/archlinux
MAINTAINER binhex

# base
######

# update mirror list for uk server
RUN echo 'Server = http://mirror.bytemark.co.uk/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist

# set environment variables
ENV HOME /root
ENV LANG en_GB.UTF-8

# set locale
RUN echo en_GB.UTF-8 UTF-8 > /etc/locale.gen
RUN locale-gen
RUN echo LANG="en_GB.UTF-8" > /etc/locale.conf

# perform system update (must ignore package "filesystem")
RUN pacman -Syu --ignore filesystem --noconfirm

# add in pre-req from official repo
RUN pacman -S supervisor --noconfirm

# add in development tools to build packer
RUN pacman -S --needed base-devel --noconfirm

# add supervisor configuration file
ADD supervisor.conf /etc/supervisor.conf

# home
######

# create user nobody home directory
RUN mkdir -p /home/nobody

# set permissions
RUN chown -R nobody:users /home/nobody
RUN chmod -R 775 /home/nobody

# packer
########

# download packer from aur
ADD https://aur.archlinux.org/packages/pa/packer/packer.tar.gz /root/packer.tar.gz

# download packer from aur
RUN cd /root && \
	tar -xzf packer.tar.gz

# change dir to untar and run makepkg (cd and makepkg must be single command)
RUN cd /root/packer && \
	makepkg -s --asroot --noconfirm

# install packer using pacman
RUN pacman -U /root/packer/packer*.tar.xz --noconfirm

# cleanup
#########

# remove unwanted system files
RUN rm -rf /archlinux/usr/share/locale
RUN rm -rf /archlinux/usr/share/man

# completely empty pacman cache folder
RUN pacman -Scc --noconfirm

# remove temporary files
RUN rm -rf /root/*
RUN rm -rf /tmp/*