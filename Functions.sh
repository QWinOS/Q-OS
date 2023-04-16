#!/bin/sh

# update mirror list
updateMirrorList() {
	pacman -S --noconfirm --needed jq reflector
	iso=$(curl -s ipinfo.io/ | jq ".country")
	reflector -a 47 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
	pacman -Syy
}

# Update pacman.conf for parallel download, add some colors too man!!
updatePacmanConf() {
    grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
    sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/;s/^#Color$/Color/" /etc/pacman.conf
}

# add all essential repositories to pacman.conf
addEssentialReposToPacmanConf() {
    case "$(readlink -f /sbin/init)" in
        *systemd*)
            pacman --noconfirm -S archlinux-keyring
            pacman-key --init
        ;;
        *)
            # Adding universe repository if not present
            grep -q "^\[universe\]" /etc/pacman.conf || echo "[universe]
Server = https://universe.artixlinux.org/\$arch" >>/etc/pacman.conf
            pacman --noconfirm --needed -Syy artix-keyring artix-archlinux-support >/dev/null 2>&1
            for repo in extra community multilib; do
                grep -q "^\[$repo\]" /etc/pacman.conf || echo "[$repo]
Include = /etc/pacman.d/mirrorlist-arch" >>/etc/pacman.conf
            done
            pacman-key --init
            pacman-key --populate archlinux
        ;;
    esac
    pacman -Sy --noconfirm
}

# Use all cores for compilation
useAllCoreCompilation() {
    sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf
}   

installFromAUR() { # args : username package-name-to-install
	name=$1
	package=$2
	sudo -u "$name" git clone --depth 1 "https://aur.archlinux.org/$package.git" ||
		{
			cd "$package" || return 1
			sudo -u "$name" git pull --force origin master
		}
	cd "$package"
	sudo -u "$name" -D "$package" makepkg --noconfirm -si || return 1
}

# Function to print error
error() {
	printf "%s\n" "$1" >&2
	exit 1
}
