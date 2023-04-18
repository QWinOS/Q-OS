#!/bin/sh

source ./root/Q-OS/Functions.sh

### OPTIONS AND VARIABLES ###

dotfilesrepo="dummy"
progsfile="dummy"
repobranch="dummy"
aurhelper="paru"

### FUNCTIONS ###

choosetheme() {
    choice=$(dialog --menu "Choose theme" 10 60 25 1 "QKlean Qtile (X11)" 2 "Dracula Qtile (X11)" 3 "Bare Qtile (X11)" 4 "Hyprland (XWayland)" 3>&1 1>&2 2>&3 3>-)
    case $choice in
        1)
            dotfilesrepo="https://github.com/QWinOS/QKleanDot"
            repobranch="master"
            progsfile="https://raw.githubusercontent.com/QWinOS/QKleanDot/$repobranch/packages.csv"
        ;;
        2)
            dotfilesrepo="https://github.com/QWinOS/Qtile-Dracula.git"
            repobranch="main"
            progsfile="https://raw.githubusercontent.com/QWinOS/Qtile-Dracula/$repobranch/packages.csv"
        ;;
        3)
            repobranch="main"
            progsfile="https://raw.githubusercontent.com/QWinOS/Q-Script/$repobranch/packages.csv"
        ;;
        4)
            dotfilesrepo="https://github.com/coderangshu/dotfile-hyprland"
            repobranch="master"
        ;;
    esac
    clear
}

settimedate() {
    echo "Final step \nSynchronizing system time to ensure successful and secure installation of software..."
    case "$(readlink -f /sbin/init)" in
        *systemd*)
            systemctl enable --now ntpd
            timedatectl set-ntp true
        ;;
        *s6*)
            s6-rc -u change ntpd
            s6-service add default ntpd
            s6-db-reload
        ;;
        *openrc*)
            rc-update add ntpd default
        ;;
    esac
}

getuserandpass() {
    # Prompts user for new username an password.
    name=$(dialog --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
    while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
        name=$(dialog --no-cancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
    done
    pass1=$(dialog --no-cancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
    pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
    while ! [ "$pass1" = "$pass2" ]; do
        unset pass2
        pass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
        pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
    done
    clear
}

usercheck() {
    ! { id -u "$name" >/dev/null 2>&1; } ||
    dialog --colors --title "WARNING!" --yes-label "CONTINUE" --no-label "No wait..." --yesno "The user \`$name\` already exists on this system. The script can install for a user already existing, but it will \\Zboverwrite\\Zn any conflicting settings/dotfiles on the user account.\\n\\nThe script will \\Zbnot\\Zn overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\\n\\nNote also that the script will change $name's password to the one you just gave." 14 70
    clear
}

adduserandpass() {
    # Adds user `$name` with password $pass1.
    dialog --infobox "Adding user \"$name\"..." 4 50
    useradd -m -g wheel -s /bin/zsh "$name" >/dev/null 2>&1 ||
    usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
    export repodir="/home/$name/.local/src"
    mkdir -p "$repodir"
    chown -R "$name":wheel "$(dirname "$repodir")"
    echo "$name:$pass1" | chpasswd
    unset pass1 pass2
    clear
}

preinstallmsg() {
    dialog --title "Let's get this party started!" --yes-label "Let's go!" --no-label "No, nevermind!" --yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\\n\\nIt will take some time, but when done, you can relax even more with your complete system.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || {
        clear
        exit 1
    }
}

newperms() { # Set special sudoers settings for install (or after).
    sed -i "/#added-by-script/d" /etc/sudoers
    echo "$* #added-by-script" >>/etc/sudoers
}

installFromAUR() { # args : username package-name-to-install
    sudo -u "$name" mkdir -p "$repodir/$1"
    sudo -u "$name" git clone --depth 1 "https://aur.archlinux.org/$1.git" "$repodir/$1" ||
    {
        cd "$repodir/$1" || return 1
        sudo -u "$name" git pull --force origin master
    }
    cd "$repodir/$1"
    sudo -u "$name" -D "$repodir/$1" makepkg --noconfirm -si || return 1
}

maininstall() {
    echo "Installing \`$1\` ($n of $total)\nDescription: $2"
    pacman --noconfirm --needed -S "$1"
}

aurinstall() {
    echo "Installing \`$1\` from the AUR ($n of $total)\nDescription: $2"
    echo "$aurinstalled" | grep -q "^$1$" && return 1
    sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1
}

pipinstall() {
    echo "Installing the Python package \`$1\` ($n of $total)\nDescription: $2"
    [ -x "$(command -v "pip")" ] || pacman --noconfirm --needed -S python-pip
    yes | pip install "$1"
}

gitmakeinstall() {
    progname="$(basename "$1" .git)"
    dir="$repodir/$progname"
    dialog --title "Q-Script Installation" --infobox "Installing \`$progname\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 5 70
    sudo -u "$name" git clone --depth 1 "$1" "$dir" >/dev/null 2>&1 || {
        cd "$dir" || return 1
        sudo -u "$name" git pull --force origin master
    }
    cd "$dir" || exit 1
    make >/dev/null 2>&1
    make install >/dev/null 2>&1
    cd /tmp || return 1
}

installationloop() {
    ([ -f "$progsfile" ] && cp "$progsfile" /tmp/packages.csv) || curl -Ls "$progsfile" | sed '/^#/d' >/tmp/packages.csv
    total=$(wc -l </tmp/packages.csv)
    aurinstalled=$(pacman -Qqm)
    while IFS=, read -r tag program comment; do
        n=$((n + 1))
        echo "$comment" | grep -q "^\".*\"$" && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
        case "$tag" in
            "A") aurinstall "$program" "$comment" ;;
            "G") gitmakeinstall "$program" "$comment" ;;
            "P") pipinstall "$program" "$comment" ;;
            *) maininstall "$program" "$comment" ;;
        esac
        [ "$?" = "0" ] || echo "$tag,$program,\"$comment\"" >>/tmp/failinstall.csv
        
    done </tmp/packages.csv
}

failinstallationloop() { # Try installing failed packages, else save package name to failinstall.csv
    ([ -f "/tmp/failinstall.csv" ])
    total=$(wc -l </tmp/failinstall.csv)
    aurinstalled=$(pacman -Qqm)
    while IFS=, read -r tag program comment; do
        n=$((n + 1))
        echo "$comment" | grep -q "^\".*\"$" && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
        case "$tag" in
            "A") aurinstall "$program" "$comment" ;;
            "G") gitmakeinstall "$program" "$comment" ;;
            "P") pipinstall "$program" "$comment" ;;
            *) maininstall "$program" "$comment" ;;
        esac
        [ "$?" = "0" ] || echo "$tag,$program,\"$comment\"" >>/home/$name/failinstall.csv
        
    done </tmp/failinstall.csv
}

putgitrepo() {
    # Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts (commented)
    # dialog --infobox "Downloading and installing config files..." 4 60
    # [ -z "$3" ] && branch="master" || branch="$repobranch"
    # dir=$(mktemp -d)
    # [ ! -d "$2" ] && mkdir -p "$2"
    # chown "$name":wheel "$dir" "$2"
    # sudo -u "$name" git clone --recursive -b "$branch" --depth 1 --recurse-submodules "$1" "$dir" >/dev/null 2>&1
    # sudo -u "$name" cp -rfT "$dir" "$2"
    
    # clone dotfiles and initialize git tracking of dotfiles
    cd $1
    rm .gitignore .bashrc
    git clone --bare $dotfilesrepo $1/.cfg
    track="git --git-dir=$1/.cfg/ --work-tree=$1"
    $track checkout -f
    $track config --local status.showUntrackedFiles no
}

systembeepoff() {
    dialog --infobox "Getting rid of that retarded error beep sound..." 10 50
    # rmmod pcspkr
    echo "blacklist pcspkr" >/etc/modprobe.d/nobeep.conf
}

plymouthinstall() {
    # Add options to grub for smoother transitions
    sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3\ quiet\"/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3\ quiet\ fbcon=nodefer\ vga=current\ splash\ vt.global_cursor_default=3\ rd.systemd.show_status=auto\"/" /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg > /dev/null 2>&1
    
    # Include plymouth in mkinitcpio hook
    sed -i "s/^HOOKS=(base\ udev\ autodetect\ modconf\ block\ filesystems\ keyboard\ fsck)/HOOKS=(base\ udev\ plymouth\ autodetect\ modconf\ block\ filesystems\ keyboard\ fsck)/" /etc/mkinitcpio.conf
    
    # Set theme for splash screen
    plymouth-set-default-theme -R cuts
    
    # Delete line using sed
    sed -i "/DeviceTimeout=8/d" /etc/plymouth/plymouthd.conf
    mkinitcpio -p linux > /dev/null 2>&1
}

zramInstallEnable(){
    case "$(readlink -f /sbin/init)" in
        *systemd*)
            sudo -u $name paru -S --noconfirm zramd || error "Error in zram installation"
            systemctl enable --now zramd
        ;;
        *openrc*)
            sudo -u $name paru -S --noconfirm zram-openrc || error "Error in zram installation"
            rc-update add zram boot
            rc-service zram start
        ;;
        *s6*)
            sudo -u $name paru -S --noconfirm zram-s6 || error "Error in zram installation"
            s6-service add default zram
            s6-rc -u change zram
        ;;
    esac
}

finalize() {
    dialog --infobox "Preparing welcome message..." 4 50
    dialog --title "All done!" --msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\\n\\nTo run the new graphical environment, log out and log back in as your new user, then run the command \"startx\" to start the graphical environment (it will start automatically in tty1).\\n\\n.t Enjoy your freshly baked Archlinux" 12 80
}

### THE ACTUAL SCRIPT ###

# Check if user is root on Arch distro. Install dialog.
pacman --noconfirm --needed -Sy dialog || error "Are you sure you're running this as the root user, are on an Arch-based distribution and have an internet connection?"

# Welcome user
echo "Welcome! \nWelcome to Final Script\nThis script will automatically install a fully-featured Linux"

# Last chance for user to back out before install.
preinstallmsg || error "User exited."

# Get and add username and password.
getuserandpass || error "Error getting username and/or password."
usercheck || error "User already exist check error." # Give warning if user already exists.
adduserandpass || error "Error adding username and/or password."

# pick dotfiles to install
choosetheme || error "Wrong option chosen for dotfile installation."

### The rest of the script requires no user input.

# Setting time zone.
settimedate || error "Error setting time and date."

[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in case

# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
newperms "%wheel ALL=(ALL) NOPASSWD: ALL"

useAllCoreCompilation

# The command that does all the installing. Reads the packages.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.
installationloop

# Install the dotfiles in the user's home directory
if [ $choice != 3 ]; then
    putgitrepo "/home/$name"
    rm -f "/home/$name/README.md" "/home/$name/LICENSE" "/home/$name/packages.csv"
    # make git ignore deleted LICENSE packages.csv & README.md files
    git update-index --assume-unchanged "/home/$name/README.md" "/home/$name/LICENSE" "/home/$name/packages.csv"
fi

# Install Paru
installFromAUR paru-bin || error "Failed to install Paru."

# Install and enable zram
zramInstallEnable

# Most important command! Get rid of the beep!
systembeepoff

# Make zsh the default shell for the user.
chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"

# dbus UUID must be generated for Artix runit.
# dbus-uuidgen >/var/lib/dbus/machine-id

# Use system notifications for Brave on Artix
# echo "export \$(dbus-launch)" >/etc/profile.d/dbus.sh

# Tap to click | Natural Scrolling
if [ $choice != 4 ]; then
    [ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass"
			Identifier "libinput touchpad catchall"
			MatchIsTouchpad "on"
			MatchDevicePath "/dev/input/event*"
			Driver "libinput"
		# Enable left mouse button by tapping
		Option "Tapping" "on"
	# Change acceleration to usable standards
	Option "AccelSpeed" "0.5"
	# Enable Natural Scrolling
	Option "NaturalScrolling" "true"
    EndSection' >/etc/X11/xorg.conf.d/40-libinput.conf
fi

# Fix fluidsynth/pulseaudio issue.
#grep -q "OTHER_OPTS='-a pulseaudio -m alsa_seq -r 48000'" /etc/conf.d/fluidsynth || echo "OTHER_OPTS='-a pulseaudio -m alsa_seq -r 48000'" >>/etc/conf.d/fluidsynth

# Start/restart PulseAudio.
#pkill -15 -x 'pulseaudio'
#sudo -u "$name" pulseaudio --start

# This line, overwriting the `newperms` command above will allow the user to run
# serveral important commands, `shutdown`, `reboot`, updating, etc. without a password.
newperms "%wheel ALL=(ALL) ALL #added-by-script
%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/packer -Syu,/usr/bin/packer -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/rc-service NetworkManager restart,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/paru,/usr/bin/pacman -Syyuw --noconfirm"

# Try installing failed packages if not installed save to file
#failinstallationloop

# Last message! Install complete!
finalize

# Install Plymouth
#plymouthinstall

clear
