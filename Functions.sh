#!/bin/sh

# update mirror list
updateMirrorList() {
    case "$(readlink -f /sbin/init)" in
        *systemd*)
        pacman -S --noconfirm --needed jq reflector
        iso=$(curl -s ipinfo.io/ | jq ".country")
        reflector -a 24 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
        pacman -Syy
    ;;
    esac
}

# Update pacman.conf for parallel download, add some colors too man!!
updatePacmanConf() {
    grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
    sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/;s/^#Color$/Color/" /etc/pacman.conf
}

# add all essential repositories to pacman.conf
addEssentialReposToPacmanConf() {
    # Installing chaotic-aur.
    # pacman-key --recv-key FBA220DFC880C036 --keyserver keyserver.ubuntu.com >/dev/null 2>&1
    # pacman-key --lsign-key FBA220DFC880C036 >/dev/null 2>&1
    # pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' >/dev/null 2>&1
    # sed -i "/#\ An\ example\ of\ a\ custom\ package\ repository.\  See\ the\ pacman\ manpage\ for/i [chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n" /etc/pacman.conf
    # pacman -Syy
    case "$(readlink -f /sbin/init)" in
        *systemd*)
            pacman --noconfirm --needed -S archlinux-keyring
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

# Function to print error
error() {
	printf "%s\n" "$1" >&2
	exit 1
}
