#!/bin/sh

bootPart="sda1"
rootPart="sda2"

# confirm you can access the internet
if [[ ! $(curl -Is http://www.google.com/ | head -n 1) =~ "200 OK" ]]; then
	echo "Your Internet seems broken. Press Ctrl-C to abort or enter to continue."
	read
fi

# make 2 partitions on the disk.
# parted -s /dev/sda mktable gpt
# parted -s /dev/sda mkpart "'EFI File System'" fat32 0% 300m
# parted -s /dev/sda set 1 esp on
# parted -s /dev/sda mkpart "'Linux'" btrfs 300m 100%

# make filesystems
# /boot
mkfs.fat -F32 /dev/$bootPart
# /
mkfs.btrfs /dev/$rootPart

# set up /mnt
mount /dev/$rootPart /mnt
mkdir /mnt/boot
cd /mnt
btrfs su cr @
btrfs su cr @home
cd
umount /mnt
mount -o noatime,compress=zstd,space_cache=v2,subvol=@ /dev/$rootPart /mnt
mkdir -p /mnt/{boot/efi,home}
mount -o noatime,compress=zstd,space_cache=v2,subvol=@home /dev/$rootPart /mnt/home
mount /dev/$bootPart /mnt/boot/efi

grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/;s/^#Color$/Color/" /etc/pacman.conf

s6-rc -u change ntpd

pacman -Syy

# install base packages (take a coffee break if you have slow internet)
basestrap /mnt base base-devel linux linux-firmware linux-headers sudo git vim btrfs-progs grub efibootmgr dialog --noconfirm --needed
fstabgen -U /mnt >> /mnt/etc/fstab

cp -r /root/Q-OS /mnt/root/
