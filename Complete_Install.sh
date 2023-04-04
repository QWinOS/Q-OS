#!/bin/sh
sh Bare_Install.sh
artix-chroot /mnt /root/Q-OS/Chroot_Install.sh
rm -rf /root/Q-OS
