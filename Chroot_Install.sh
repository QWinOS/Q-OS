#!/bin/sh

getrootpass() {
    # Prompts user for root password.
    pas1=$(dialog --no-cancel --passwordbox "Enter a password for the root user." 10 60 3>&1 1>&2 2>&3 3>&1)
    pas2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
    while ! [ "$pas1" = "$pas2" ]; do
        unset pas2
        pas1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
        pas2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
    done
}
addrootuserpass() {
    # Adds root password $pas1.
    echo root:$pas1 | chpasswd
    unset pas1 pas2
}

# Update reflector list
iso=$(curl -4 ifconfig.co/country-iso)
reflector -a 47 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syy

# Locale-Gen, Hostname setup
sed -i '/^#en_US.UTF-8* /s/^#//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >>/etc/locale.conf
echo "QWINOS" >>/etc/hostname
echo "127.0.0.1 localhost" >>/etc/hosts
echo "::1       localhost" >>/etc/hosts
echo "127.0.1.1 qwinos.localdomain qwinos" >>/etc/hosts

# Add root user's password
getrootpass || error "Root user error"
addrootuserpass || error "Root user password error"
clear

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
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=QWinGRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Window manager & Other install
curl https://raw.githubusercontent.com/QWinOS/Q-Script/master/Q-Script.sh --output /tmp/Q-Script.sh
chmod +x /tmp/Q-Script.sh
/tmp/./Q-Script.sh

# Create the directories Desktop, Documents, Downloads, Music, Pictures, Public, Templates, Videos
xdg-user-dirs-update

# Enable Network Manager
systemctl enable NetworkManager
