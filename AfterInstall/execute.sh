# Update user password accordingly
passwd="123"

# Install Paru
git clone https://aur.archlinux.org/paru-bin
cd paru-bin
echo $passwd | makepkg --needed --noconfirm -si
cd ..
rm -rf paru-bin

# Install required packages
echo $passwd | paru --noconfirm --needed -S timeshift timeshift-autosnap zram-s6

# Activate zram service
echo $passwd | s6-rc -u change zram
echo $passwd | sudo s6-service add default zram
echo $passwd | sudo s6-db-reload
