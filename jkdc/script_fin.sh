#!/bin/sh
echo "script change password"

head /dev/urandom | tr -dc A-Za-z0-9 | head -c 18 >> /root/key2
head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10 >> /root/passroot
printf "librerouter" >> /root/key1
printf "root:" >> /root/pass1
cat /root/passroot >> /root/pass1

cat /root/key2 | cryptsetup luksAddKey /dev/sda5 -d=/root/key1 -S 6
cat /root/key1 | cryptsetup luksRemoveKey /dev/sda5 -S=1


mount -o remount,rw /cdrom
cp /root/key2 /cdrom/clave.$(date '+%Y-%m-%d_%H-%M')
cp /root/passroot /cdrom/passroot.$(date '+%Y-%m-%d_%H-%M')


#cat /target/root/pass1 | chroot /target chpasswd
cat /root/pass1 | chpasswd

echo "End script"
