#!/bin/sh

source ./Functions.sh

# confirm you can access the internet
if [[ ! $(curl -Is http://www.google.com/ | head -n 1) =~ "200 OK" ]]; then
	echo "Your Internet seems broken. Press Ctrl-C to abort or enter to continue."
	read
fi

echo "Enter drive name (ex: sda)"
read drive

# make 2 partitions on the disk.
echo "Should I create boot and root partitions? (ex: yes/y/no/n)"
read isParted
isParted=$(echo $isParted | tr '[:upper:]' '[:lower:]')
if [ $isParted == "yes" ] || [ $isParted == "y" ]
then
	pacman -S --noconfirm --needed parted 
	parted -s /dev/$drive mktable gpt
	parted -s /dev/$drive mkpart "'EFI File System'" fat32 0% 512m
	parted -s /dev/$drive set 1 esp on
	parted -s /dev/$drive mkpart "'Linux'" btrfs 512m 100%
	bootPart=$drive"1"
	rootPart=$drive"2"
else
	echo "Enter boot partition number (ex: 1/2/3/...)"
	read bootPartNum
	echo "Enter root partition number (ex: 1/2/3/...)"
	read rootPartNum
	bootPart=$drive$bootPartNum
	rootPart=$drive$rootPartNum
fi

# make filesystems
# /boot
mkfs.fat -F32 /dev/$bootPart
# /
mkfs.btrfs -f /dev/$rootPart

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

updatePacmanConf
addEssentialReposToPacmanConf
updateMirrorList
useAllCoreCompilation

# install base packages (take a coffee break if you have slow internet)
case "$(readlink -f /sbin/init)" in
	*systemd*)
		pacstrap /mnt base base-devel linux linux-firmware linux-headers reflector sudo git vim btrfs-progs grub grub-btrfs efibootmgr networkmanager network-manager-applet ntp zsh man-db most dialog jq --noconfirm --needed
		genfstab -U /mnt >>/mnt/etc/fstab
	;;
	*s6*)
		basestrap /mnt base base-devel s6-base elogind-s6 connman-s6 linux linux-firmware linux-headers sudo git vim btrfs-progs grub efibootmgr wpa_supplicant dhcpcd openssh-s6 ntp-s6 zsh man-db most dialog jq --noconfirm --needed
		fstabgen -U /mnt >> /mnt/etc/fstab
	;;
	*openrc*)
		basestrap /mnt base base-devel openrc elogind-openrc connman-openrc linux linux-firmware linux-headers sudo git vim btrfs-progs grub efibootmgr wpa_supplicant dhcpcd openssh-openrc ntp-openrc zsh man-db most dialog jq --noconfirm --needed
		fstabgen -U /mnt >> /mnt/etc/fstab
	;;
esac

cp -r /root/Q-OS /mnt/root/
