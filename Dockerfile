FROM base/archlinux:2014.07.03
MAINTAINER binhex

# base
######

# update repo list, set locale, install packer, install runit, create user nobody home dir, cleanup
RUN echo 'Server = http://mirror.bytemark.co.uk/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist && \
	echo en_GB.UTF-8 UTF-8 > /etc/locale.gen && \
	locale-gen && \
	echo LANG="en_GB.UTF-8" > /etc/locale.conf && \
	pacman -Syu --ignore filesystem --noconfirm && \	
	pacman -S --needed base-devel --noconfirm && \	
	cd /root && \
	tar -xzf packer.tar.gz && \
	cd /root/packer && \
	makepkg -s --asroot --noconfirm && \
	pacman -U /root/packer/packer*.tar.xz --noconfirm && \
	packer -S runit --noconfirm && \
	pacman -Ru base-devel packer --noconfirm && \
	pacman -Scc --noconfirm && \
	mkdir -p /home/nobody && \
	chown -R nobody:users /home/nobody && \
	chmod -R 775 /home/nobody && \
	rm -rf /archlinux/usr/share/locale && \
	rm -rf /archlinux/usr/share/man && \
	rm -rf /root/* && \
	rm -rf /tmp/*
	
# env
#####

# set environment variables for root and language
ENV HOME /root
ENV LANG en_GB.UTF-8