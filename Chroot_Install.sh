#!/bin/bash

# Update reflector list
reflector -a 47 -c IN -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syy

# Grub Install
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=QWinGRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Locale-Gen
echo en_US.UTF-8 UTF-8 >/etc/locale.gen && locale-gen

# Window manager & Other install
curl -LO https://raw.githubusercontent.com/QWinOS/Q-Script/master/Q-Script.sh
chmod +x Q-Script.sh
./Q-Script.sh

# Enable Network Manager
systemctl enable NetworkManager
