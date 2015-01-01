FROM base/archlinux:2014.07.03
MAINTAINER binhex

# base
######

# update repo list, set locale, install supervisor, create user nobody home dir
RUN echo 'Server = http://mirror.bytemark.co.uk/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist && \
	echo en_GB.UTF-8 UTF-8 > /etc/locale.gen && \
	locale-gen && \
	echo LANG="en_GB.UTF-8" > /etc/locale.conf && \
	pacman -Syu --ignore filesystem --noconfirm && \
	pacman -S supervisor --noconfirm && \
	mkdir -p /home/nobody && \
	chown -R nobody:users /home/nobody && \
	chmod -R 775 /home/nobody && \
	sed -i -e 's/nobody:x:99:99:nobody:\/:\/usr\/bin\/nologin/nobody:x:99:99:nobody:\/home\/nobody:\/bin\/bash/g' /etc/passwd && \
	pacman -Scc --noconfirm

# env
#####

# set environment variables for root and language
ENV HOME /root
ENV LANG en_GB.UTF-8

# additional files
##################

# add supervisor configuration file
ADD supervisor.conf /etc/supervisor.conf
