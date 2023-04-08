#!/bin/sh
sh Bare_Install.sh

arch-chroot /mnt /bin/bash << END
./root/Q-OS/Chroot_Install.sh
echo "Bare Linux installation complete"
echo "Should I continue installing dotfiles and setup complete linux? (y/n)"
read choice
if [ $choice == "y" ]; then
    ./root/Q-OS/Final_Install.sh
fi
END

rm -rf /root/Q-OS
rm -rf /mnt/root/Q-OS
exit
echo "Installation complete!!!"