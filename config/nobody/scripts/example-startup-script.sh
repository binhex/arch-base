#!/bin/bash

# Example script showing how to install packages from AOR/AUR.

# IMPORTANT
# This script adds in the ability to install addtional application the end user may want,
# please do bear in mind every time the image is updated the container will be deleted
# and reinstallation of all packages listed will occur.

# remove previous pacman lock file if it exists
rm -f /var/lib/pacman/db.lck

# AOR packages
###

# Define AOR (Arch Official Repository) packages you want to install at startup.
# Go to the following URL for a list of available packages:- https://archlinux.org/packages/
#
# If you want to install more than one package then please user a space as a separator.
# Example: To install Docker and Java Runtime 11 you would specify:-
# pacman_packages="docker jre11-openjdk-headless"
pacman_packages=""

# install compiled packages using pacman
if [[ ! -z "${pacman_packages}" ]]; then
	pacman -S --needed ${pacman_packages} --noconfirm
fi

# AUR packages
###

# IMPORTANT
# AUR packages may require compiling and thus time to install the application maybe
# (depending on the applications complexity) considerable, plwease be patient and monitor
# progress in the '/config/supervisord.log' file.

# Define AUR (Arch User Repository) packages you want to install at startup.
# Go to the following URL for a list of available packages:- https://aur.archlinux.org/packages/
#
# If you want to install more than one package then please user a space as a separator.
# Example: To install Powershell you would specify:-
# aur_packages="powershell"
aur_packages=""

# install compiled packages using helper 'yay'
if [[ ! -z "${aur_packages}" ]]; then
	source 'aur.sh'
fi
