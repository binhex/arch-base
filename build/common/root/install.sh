#!/bin/bash

# exit script if return code != 0
set -e

# app name from buildx arg, used in healthcheck to identify app and monitor correct process
APPNAME="${1}"
shift

# release tag name from buildx arg, stripped of build ver using string manipulation
RELEASETAG="${1}"
shift

# target arch from buildx arg
TARGETARCH="${1}"
shift

if [[ -z "${APPNAME}" ]]; then
	echo "[warn] App name from build arg is empty, exiting script..."
	exit 1
fi

if [[ -z "${RELEASETAG}" ]]; then
	echo "[warn] Release tag name from build arg is empty, exiting script..."
	exit 1
fi

if [[ -z "${TARGETARCH}" ]]; then
	echo "[warn] Target architecture name from build arg is empty, exiting script..."
	exit 1
fi

# construct snapshot date (cannot use todays as archive wont exist) and set url for archive.
# note: for arch linux arm archive repo that the snapshot date has to be at least 5 days
# previous as the mirror from live to the archive for arm packages is slow
snapshot_date=$(date -d "5 days ago" +%Y/%m/%d)

# define path to mirrorlist file
mirrorlist_filepath='/etc/pacman.d/mirrorlist'

# blank mirrorlist file
rm -f "${mirrorlist_filepath}"

# write APPNAME and RELEASETAG to file to record the app name and release tag used to build the image
# note as this is a base image there is no app name
echo -e "export BASE_RELEASE_TAG=${RELEASETAG}\n" >> '/etc/image-build-info'

# now set pacman to use snapshot for packages for snapshot date
if [[ "${TARGETARCH}" == "amd64" ]]; then
	server_list='europe.archive.pkgbuild.com america.archive.pkgbuild.com asia.archive.pkgbuild.com'
	for server in ${server_list}; do
		echo "Server = https://${server}/repos/${snapshot_date}/\$repo/os/\$arch" >> "${mirrorlist_filepath}"
	done
elif [[ "${TARGETARCH}" == "arm64" ]]; then
	# arm archive is extremely slow (unusable), switching to live repo for now
	server_list='de3.mirror.archlinuxarm.org de4.mirror.archlinuxarm.org de5.mirror.archlinuxarm.org eu.mirror.archlinuxarm.org ca.us.mirror.archlinuxarm.org'
	for server in ${server_list}; do
		echo "Server = https://${server}/\$arch/\$repo" >> "${mirrorlist_filepath}"
	done
	# server_list='tardis.tiny-vps.com aarm alaa.ad24.cz'
	# for server in ${server_list}; do
	# 	echo "Server = https://${server}/repos/${snapshot_date}/\$arch/\$repo" >> "${mirrorlist_filepath}"
	# done
else
	echo "[warn] Target architecture name '${TARGETARCH}' from build arg is empty or unexpected, exiting script..."
	exit 1
fi

echo "[info] content of arch mirrorlist file..."
cat "${mirrorlist_filepath}"

# reset gpg (not required when source is bootstrap tarball, but keeping for historic reasons)
rm -rf '/etc/pacman.d/gnupg/' '/root/.gnupg/' || true

# refresh gpg keys
gpg --refresh-keys

if [[ "${TARGETARCH}" == "arm64" ]]; then
	pacman_arch="archlinuxarm"
else
	pacman_arch="archlinux"
fi

# initialise key for pacman and populate keys
pacman-key --init && pacman-key --populate "${pacman_arch}"

echo "[info] set pacman to ignore signatures - required due to rolling release nature of archlinux"
sed -i -E "s~^SigLevel(\s+)?=.*~SigLevel = Never~g" '/etc/pacman.conf'

echo "[info] set pacman to disable sandbox - required as sandbox prevents packages from installing"
sed -i -E "s~^#DisableSandbox~DisableSandbox~g" '/etc/pacman.conf'

# force pacman db refresh and install sed package (used to do package folder exclusions)
pacman -Sy sed --debug --noconfirm

# configure pacman to not extract certain folders from packages being installed
# this is done as we strip out locale, man, docs etc when we build the arch-scratch image
sed -i '\~\[options\]~a # Do not extract the following folders from any packages being installed\n'\
'NoExtract   = usr/share/locale* !usr/share/locale/en* !usr/share/locale/locale.alias\n'\
'NoExtract   = usr/share/doc*\n'\
'NoExtract   = usr/share/man*\n'\
'NoExtract   = usr/lib/firmware*\n'\
'NoExtract   = usr/lib/modules*\n'\
'NoExtract   = usr/share/gtk-doc*\n' \
'/etc/pacman.conf'

# list all packages that we want to exclude/remove
unneeded_packages="\
filesystem \
cryptsetup \
device-mapper \
dhcpcd \
iproute2 \
jfsutils \
libsystemd \
linux \
lvm2 \
man-db \
man-pages \
mdadm \
netctl \
openresolv \
pciutils \
pcmciautils \
reiserfsprogs \
s-nail \
systemd \
systemd-sysvcompat \
usbutils \
xfsprogs"

# split space separated string into list for install paths
IFS=' ' read -ra unneeded_packages_list <<< "${unneeded_packages}"

# construct string to ensure removal of any packages that might be part of tarball
pacman_remove_unneeded_packages='pacman --noconfirm -Rsc'

for i in "${unneeded_packages_list[@]}"; do
	pacman_remove_unneeded_packages="${pacman_remove_unneeded_packages} ${i}"
done

echo "[info] Removing unneeded packages that might be part of the tarball..."
echo "${pacman_remove_unneeded_packages} || true"
eval "${pacman_remove_unneeded_packages} || true"

echo "[info] Adding required packages to pacman ignore package list to prevent upgrades..."

# add filesystem to pacman ignore list to prevent buildx issues with
# /etc/hosts and /etc/resolv.conf being read only, see issue -
# https://github.com/moby/buildkit/issues/1267#issuecomment-768903038
#
sed -i -e 's~#IgnorePkg.*~IgnorePkg = filesystem~g' '/etc/pacman.conf'

echo "[info] Displaying contents of pacman config file, showing ignored packages..."
cat '/etc/pacman.conf'

echo "[info] Updating packages currently installed..."
pacman -Syu --debug --noconfirm

echo "[info] Install base group and additional packages..."
pacman -S base which awk sed grep gzip supervisor nano vi rsync ldns moreutils bind-tools net-tools dos2unix unzip unrar htop jq openssl-1.1 openbsd-netcat --noconfirm

echo "[info] set locale..."
echo en_GB.UTF-8 UTF-8 > '/etc/locale.gen'
locale-gen
echo LANG="en_GB.UTF-8" > '/etc/locale.conf'

home_path='/home/nobody'

# create home directory for user "nobody"
mkdir -p "${home_path}"

# add user "nobody" to primary group "users" (will remove any other group membership)
usermod -g users nobody

# add user "nobody" to secondary group "nobody" (will retain primary membership)
usermod -a -G nobody nobody

# set user "nobody" home directory (needs defining for pycharm, and possibly other apps)
usermod -d "${home_path}" nobody

# ensure there is no expiry date for user nobody
usermod --expiredate= nobody

# set shell for user nobody
chsh -s /bin/bash nobody

# find latest dumb-init release tag from github
curl --connect-timeout 5 --max-time 600 --retry 5 --retry-delay 0 --retry-max-time 60 -o "/tmp/dumbinit_release_tag" -L "https://github.com/Yelp/dumb-init/releases"
dumbinit_release_tag=$(grep -P -o -m 1 '(?<=/Yelp/dumb-init/releases/tag/)[^"]+' < /tmp/dumbinit_release_tag)

# remove first character 'v' from string, used for url to download binary
dumbinit_release_tag_strip="${dumbinit_release_tag#?}"

if [[ "${TARGETARCH}" == "arm64" ]]; then
	dumbinit_arch="aarch64"
else
	dumbinit_arch="x86_64"
fi

# download dumb-init, used to do graceful exit when docker stop issued and correct reaping of zombie processes.
curl --connect-timeout 5 --max-time 600 --retry 5 --retry-delay 0 --retry-max-time 60 -o "/usr/bin/dumb-init" -L "https://github.com/Yelp/dumb-init/releases/download/${dumbinit_release_tag}/dumb-init_${dumbinit_release_tag_strip}_${dumbinit_arch}" && chmod +x "/usr/bin/dumb-init"

# build scripts
####

refresh_script_name='refresh.sh'
refresh_filepath="/tmp/${refresh_script_name}"
github_url="https://raw.githubusercontent.com/binhex/scripts/refs/heads/master/scripts/docker/${refresh_script_name}"

# remove refresh script if it exists
rm -f "${refresh_filepath}"

# download build scripts from github
curl --connect-timeout 5 --max-time 600 --retry 5 --retry-delay 0 --retry-max-time 60 -o "${refresh_filepath}" -L "${github_url}"

chmod +x "${refresh_filepath}"

# execute script to git clone all scripts from repository
eval "${refresh_filepath}"

# set scripts path and permissions
####

create_root_paths='/usr/local/bin/system /usr/local/bin/run'

for path in ${create_root_paths}; do
	mkdir -p "${path}"
	chown -R nobody:users "${path}"
	chmod -R 775 "${path}"
done

# create directories for scripts and ensure they are owned by user "nobody" and group "users"
create_paths='/usr/local/bin/system/scripts/docker /usr/local/bin/run/scripts /usr/local/bin/run/configs /usr/local/bin/run/utils'

for path in ${create_paths}; do
	mkdir -p "${path}"
	chown -R nobody:users "${path}"
	chmod -R 775 "${path}"
done

bashrc_paths='/home/nobody/.bashrc /root/.bashrc'

# convert space-separated paths to colon-separated format
create_paths_format=$(echo "${create_paths}" | tr ' ' ':')

# add script paths to bashrc files if not already present
for dest_paths in ${bashrc_paths}; do
	if ! grep -q "${create_paths_format}" "${dest_paths}" &>/dev/null || true; then
		echo "export PATH=\"${create_paths_format}:\${PATH}\"" >> "${dest_paths}"
	fi
done

# ensure ownership/permissions are set for all files generated in home directory
chown -R nobody:users "${home_path}"
chmod -R 775 "${home_path}"

# identify if base-devel package installed
if pacman -Qg "base-devel" > /dev/null ; then

	# remove base devel excluding useful core packages
	pacman -Ru $(pacman -Qgq base-devel | grep -v awk | grep -v pacman | grep -v sed | grep -v grep | grep -v gzip | grep -v which) --noconfirm

fi

# remove any build tools that maybe present from the build
pacman -Ru dotnet-sdk yarn git yay-bin reflector gcc binutils --noconfirm 2> /dev/null || true

# general cleanup
yes|pacman -Scc
pacman --noconfirm -Rns $(pacman -Qtdq) 2> /dev/null || true
rm -rf /var/cache/* \
/var/empty/.cache/* \
/usr/share/locale/* \
/usr/share/man/* \
/usr/share/gtk-doc/* \
/tmp/*

# additional cleanup for base only
rm -rf /root/* \
/boot/* \
/var/cache/pacman/pkg/* \
/usr/lib/firmware \
/usr/lib/modules \
/.dockerenv \
/.dockerinit \
/usr/share/info/* \
/README \
/bootstrap
