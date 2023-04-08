#!/bin/sh

source ./Functions.sh

getrootpass() {
    # Prompts user for root password.
    pas1=$(dialog --no-cancel --passwordbox "Enter a password for the root user." 10 60 3>&1 1>&2 2>&3 3>&1)
    pas2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
    while ! [ "$pas1" = "$pas2" ]; do
        unset pas2
        pas1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
        pas2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
    done
    clear
}
addrootuserpass() {
    # Adds root password $pas1.
    echo root:$pas1 | chpasswd
    unset pas1 pas2
}

# Update time zone
timezone=$(curl -s https://ipapi.co/timezone)
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc

# Locale-Gen, Hostname setup
sed -i '/^#en_US.UTF-8* /s/^#//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >>/etc/locale.conf
echo "Enter Hostname (ex: archlinux): "
read hostname
echo $hostname >>/etc/hostname
echo "127.0.0.1 localhost" >>/etc/hosts
echo "::1       localhost" >>/etc/hosts
echo "127.0.1.1 $hostname.localdomain $hostname" >>/etc/hosts

# Add root user's password
getrootpass || error "Root user error"
addrootuserpass || error "Root user password error"

updatePacmanConf
addEssentialReposToPacmanConf
updateMirrorList
useAllCoreCompilation

# Determine processor type and install microcode
proc_type=$(lscpu | awk '/Vendor ID:/ {print $3}')
case "$proc_type" in
GenuineIntel)
    print "Installing Intel microcode"
    pacman -S --noconfirm intel-ucode
    proc_ucode=intel-ucode.img
    ;;
AuthenticAMD)
    print "Installing AMD microcode"
    pacman -S --noconfirm amd-ucode
    proc_ucode=amd-ucode.img
    ;;
esac

# Graphics Drivers find and install
if lspci | grep -E "NVIDIA|GeForce"; then
    pacman -S nvidia --noconfirm --needed
    nvidia-xconfig
elif lspci | grep -E "Radeon"; then
    pacman -S xf86-video-amdgpu --noconfirm --needed
elif lspci | grep -E "Integrated Graphics Controller"; then
    pacman -S libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils --needed --noconfirm
elif lspci | grep -E "VMware"; then
    pacman -S lib32-vulkan-radeon lib32-vulkan-radeon-mesa --needed --noconfirm
    pacman -S xf86-video-vmware --noconfirm --needed
elif lspci | grep -E "VGA compatible controller"; then
    pacman -S xf86-video-vesa --noconfirm --needed
fi

# Grub Install
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Grub
grub-mkconfig -o /boot/grub/grub.cfg

# Adding btrfs filesystem into mkinitcpio
sed -i "s/^MODULES=()$/MODULES=(btrfs)/" /etc/mkinitcpio.conf
mkinitcpio -p linux

# Enable Network Manager/Connman, ssh
case "$(readlink -f /sbin/init)" in
	*systemd*)
        systemctl enable NetworkManager
        systemctl enable sshd
	;;
	*)
		s6-service add default connmand
        s6-service add default sshd
        s6-db-reload
	;;
esac
