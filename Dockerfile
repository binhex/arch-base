FROM base/archlinux
MAINTAINER binhex

# base
######

RUN echo 'Server = http://mirror.bytemark.co.uk/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist && \
	echo en_GB.UTF-8 UTF-8 > /etc/locale.gen && \
	locale-gen && \
	echo LANG="en_GB.UTF-8" > /etc/locale.conf && \
	pacman -Syu --ignore filesystem --noconfirm && \
	pacman -S supervisor --noconfirm && \
	mkdir -p /home/nobody && \
	chown -R nobody:users /home/nobody && \
	chmod -R 775 /home/nobody

# packer
########

# download packer from aur
ADD https://aur.archlinux.org/packages/pa/packer/packer.tar.gz /root/packer.tar.gz

# download packer from aur
RUN cd /root && \
	tar -xzf packer.tar.gz && \
	cd /root/packer && \
	makepkg -s --asroot --noconfirm && \
	pacman -U /root/packer/packer*.tar.xz --noconfirm && \
	rm -rf /archlinux/usr/share/locale && \
	rm -rf /archlinux/usr/share/man && \
	pacman -Scc --noconfirm && \
	rm -rf /root/* && \
	rm -rf /tmp/*

# env
#####

# set environment variables
ENV HOME /root
ENV LANG en_GB.UTF-8

# supervisor
############

# add supervisor configuration file
ADD supervisor.conf /etc/supervisor.conf
