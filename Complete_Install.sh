#!/bin/sh

execute() {
    case "$(readlink -f /sbin/init)" in
    *systemd*)
        exec "arch-chroot /mnt ./root/Q-OS/$1_Install.sh"
    ;;
    *)
        exec "artix-chroot /mnt ./root/Q-OS/$1_Install.sh"
    ;;
    esac
}

sh Bare_Install.sh

execute "Chroot"

echo "Bare Linux installation complete"
echo "Continue installing dotfiles and setup complete linux? (y/n)"
read choice
if [ $choice == "y" ]; then
    execute "Final"
fi

rm -rf /root/Q-OS
rm -rf /mnt/root/Q-OS
exit
echo "Installation complete!!!"
