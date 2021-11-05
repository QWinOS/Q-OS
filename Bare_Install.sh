#!/bin/bash

# confirm you can access the internet
if [[ ! $(curl -Is http://www.google.com/ | head -n 1) =~ "200 OK" ]]; then
	echo "Your Internet seems broken. Press Ctrl-C to abort or enter to continue."
	read
fi

# make 2 partitions on the disk.
parted -s /dev/sda mktable gpt
parted -s /dev/sda mkpart "'EFI File System'" fat32 0% 300m
parted -s /dev/sda set 1 esp on
parted -s /dev/sda mkpart "'Linux'" btrfs 300m 100%

# make filesystems
# /boot
mkfs.fat -F32 /dev/sda1
# /
mkfs.btrfs /dev/sda2

# set up /mnt
mount /dev/sda2 /mnt
mkdir /mnt/boot
cd /mnt
btrfs su cr @
btrfs su cr @home
cd
umount /mnt
mount -o noatime,compress=zstd,space_cache=v2,subvol=@ /dev/sda2 /mnt
mkdir -p /mnt/{boot,home}
mount -o noatime,compress=zstd,space_cache=v2,subvol=@home /dev/sda2 /mnt/home
mount /dev/sda1 /mnt/boot

# install base packages (take a coffee break if you have slow internet)
pacstrap /mnt base base-devel linux linux-firmware linux-headers reflector sudo git vim btrfs-progs grub grub-btrfs efibootmgr networkmanager network-manager-applet --noconfirm --needed # amd-ucode
genfstab -U /mnt >>/mnt/etc/fstab

cp -r /root/Q-OS /mnt/root/
