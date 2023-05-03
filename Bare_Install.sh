#!/bin/sh

source ./Functions.sh

# confirm you can access the internet
if [[ ! $(curl -Is http://www.google.com/ | head -n 1) =~ "200 OK" ]]; then
    echo "Your Internet seems broken. Press Ctrl-C to abort or enter to continue."
    read
fi

echo "Encrypted drives are not supported by this installation script. (ex: /dev/mapper/root)"
echo "Are you sure drives are not encrypted? Press Ctrl-C to abort or enter to continue."
read

# Ask if installation is to be done in the same drive
echo "Do you want to install boot and root in same drive? (ex: yes/y/no/n)"
read isSameDrive
isSameDrive=$(echo $isSameDrive | tr '[:upper:]' '[:lower:]')
if [ $isSameDrive == "no" ] || [ $isSameDrive == "n" ]
then
    # if not in same drive ask for complete partition names for boot and root
    echo "Enter boot partition name (ex: sda1 / nvme0n1p1)"
    read bootPart
    echo "Enter root partition name (ex: sda1 / nvme0n1p1)"
    read rootPart
else
    # if same drive ask for the drive name only
    echo "Enter drive name (ex: sda / nvme0n1)"
    read drive

    # append p to drive name and store to exactDrive if drive is a SSD
    if [ ${drive:0:1} == "n" ]
    then
        exactDrive=$drive"p"
    else
        exactDrive=$drive
    fi
        
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
        bootPart=$exactDrive"1"
        rootPart=$exactDrive"2"
    else
        echo "Enter boot partition number (ex: 1/2/3/...)"
        read bootPartNum
        echo "Enter root partition number (ex: 1/2/3/...)"
        read rootPartNum
        bootPart=$exactDrive$bootPartNum
        rootPart=$exactDrive$rootPartNum
    fi
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
if [ ${rootPart:0:1} == "n" ]
then
    # if root partition is installed in a SSD
    mount -o noatime,compress=zstd,space_cache=v2,ssd,discard=async,subvol=@ /dev/$rootPart /mnt
    mkdir -p /mnt/{boot/efi,home}
    mount -o noatime,compress=zstd,space_cache=v2,ssd,discard=async,subvol=@home /dev/$rootPart /mnt/home
else
    mount -o noatime,compress=zstd,space_cache=v2,subvol=@ /dev/$rootPart /mnt
    mkdir -p /mnt/{boot/efi,home}
    mount -o noatime,compress=zstd,space_cache=v2,subvol=@home /dev/$rootPart /mnt/home
fi
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
