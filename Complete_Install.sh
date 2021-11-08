#!/bin/sh
sh Bare_Install.sh
arch-chroot /mnt /root/Q-OS/Chroot_Install.sh
rm -rf /root/Q-OS
