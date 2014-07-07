FROM base/archlinux
MAINTAINER binhex

# base
######

# update mirror list for uk server
RUN echo 'Server = http://mirror.bytemark.co.uk/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist

# set locale
RUN sed -i 's/#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/g' /etc/locale.gen
RUN locale-gen
RUN echo LANG="en_GB.UTF-8" > /etc/locale.conf
RUN export LANG=en_GB.UTF-8

# perform system update (must ignore package "filesystem")
RUN pacman -Syu --ignore filesystem --noconfirm

# add in pre-req from official repo
RUN pacman -S wget supervisor --noconfirm

# add in development tools to build packer
RUN pacman -S --needed base-devel --noconfirm

# add supervisor configuration file
ADD supervisor.conf /etc/supervisor.conf

# packer
########

# download packer from aur
RUN wget https://aur.archlinux.org/packages/pa/packer/packer.tar.gz

# untar packer tarball
RUN tar -xzf packer.tar.gz

# change dir to untar and run makepkg (cd and makepkg must be single command)
RUN cd /packer && \
	makepkg -s --asroot --noconfirm

# install packer using pacman
RUN pacman -U /packer/packer*.tar.xz --noconfirm

# cleanup
#########

# remove old packages
RUN pacman -Sc --noconfirm

# remove unwanted files
RUN rm -rf /archlinux/usr/share/locale
RUN rm -rf /archlinux/usr/share/man

# remove temporary tarball for packer
RUN rm -rf /packer
RUN rm -rf packer*