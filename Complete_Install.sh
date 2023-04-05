#!/bin/sh
sh Bare_Install.sh
artix-chroot /mnt /root/Q-OS/Chroot_Install.sh
cp -r /root/Q-OS/AfterInstall/ /mnt/root/AfterInstall/
rm -rf /root/Q-OS
echo "PLEASE CHECK /root/AfterInstall folder for the NEXT STEPS"
