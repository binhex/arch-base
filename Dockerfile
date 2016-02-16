FROM base/archlinux:2015.06.01
MAINTAINER binhex

# additional files
##################

# add install bash script
ADD setup/root/*.sh /root/

# install app
#############

# run bash script to update base image, set locale, install supervisor and cleanup
RUN chmod +x /root/*.sh && \
	/bin/bash /root/install.sh

# env
#####

# set environment variables for user nobody
ENV HOME /home/nobody

# set environment variable for terminal
ENV TERM xterm

# set environment variables for language
ENV LANG en_GB.UTF-8

# additional files
##################

# add supervisor configuration file
ADD setup/supervisor.conf /etc/supervisor.conf
