FROM base/archlinux:2014.07.03
MAINTAINER binhex

# base
######

# update repo list, set locale, install supervisor, create user nobody home dir
RUN echo 'Server = http://mirror.bytemark.co.uk/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist && \
	echo en_GB.UTF-8 UTF-8 > /etc/locale.gen && \
	locale-gen && \
	echo LANG="en_GB.UTF-8" > /etc/locale.conf && \
	pacman -Sy --noconfirm && \
	pacman -S pacman --noconfirm && \
	pacman-db-upgrade && \
	pacman -Syu --ignore filesystem --noconfirm && \
	pacman -S supervisor --noconfirm && \
	pacman -Scc --noconfirm
	rm -rf /archlinux/usr/share/locale && \
	rm -rf /archlinux/usr/share/man && \
	rm -rf /root/* && \
	rm -rf /tmp/*

# env
#####

# set environment variables for root and language
ENV HOME /root
ENV LANG en_GB.UTF-8

# additional files
##################

# add supervisor configuration file
ADD supervisor.conf /etc/supervisor.conf
