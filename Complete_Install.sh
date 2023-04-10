#!/bin/sh
sh Bare_Install.sh

case "$(readlink -f /sbin/init)" in
    *systemd*)
        arch-chroot /mnt ./root/Q-OS/Chroot_Install.sh
    ;;
    *s6*)
        artix-chroot /mnt ./root/Q-OS/Chroot_Install.sh 
    ;;
esac

# ./root/Q-OS/Chroot_Install.sh
echo "Bare Linux installation complete"
echo "Should I continue installing dotfiles and setup complete linux? (y/n)"
read choice
if [ $choice == "y" ]; then
    case "$(readlink -f /sbin/init)" in
    *systemd*)
        arch-chroot /mnt ./root/Q-OS/Final_Install.sh
    ;;
    *s6*)
        artix-chroot /mnt ./root/Q-OS/Final_Install.sh 
    ;;
esac
fi
    # ./root/Q-OS/Final_Install.sh
# END

rm -rf /root/Q-OS
rm -rf /mnt/root/Q-OS
exit
echo "Installation complete!!!"