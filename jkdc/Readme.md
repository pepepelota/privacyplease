Generate automatic installation of operating system started from usb. Full disk encryption with Luks must be applied. After installation, the encryption key must be displayed.
Steps:
1-Generate Bootable USB: generate USB installation with .iso
2-Apply configuration file preseed for iso installation (authomatic installation not supervised): make preseed file wich build installation authomatic. Autoinstall Preseed is a file configuration wich make the complete installation for os (select all options of live cd installation preconfigurated: language, timezone, partintions,etc). Example --> https://www.debian.org/releases/jessie/example-preseed.txt
3-Generate script to change the temporary password: On the step 2, the configuration file apply a cypher Luks using temporary password, this script must change for new password ramdon and show on the screen. The script will be called before preseed file finish.

DEBIAN UNATTENDED AUTOINSTALL
----------------------------------------------------------------------------------------------------------------------------------------

steps for mount image:

1-use unetbootin, rufus, ect for create a usb installable debian.

2-create syslinux.cfg file -> this file is the first read in boot and it task to init the installation of debian. It include the call of kernel and initrd.gz with preseed. 

3-create preseed.cfg file -> This file include all answer of questions wich debian installation make. Preseed file configure language, keymap, hardware, network, partitions, users account, kernel, apt, grub, etc.

3.1-configure all answer of question to debian installer

3.2-generate with partman the partitions and configure the luks encription. -> This configuration cypher the hdd with LUKS format an apply a temporary passphrase.

3.3-configure run command after install for change key luks-> With late_command we can run new commands, before debian installation finish,  for run a script, install new packages or make something. In our case, we run a script (app-installation-script.sh) and configure other script (app-configuration-script.sh) for init on first boot. I copy setup_iso.sh to /root path and give run permissons. Then run setup_iso.sh and download and install app-installation-script.sh, after I download  app-configuration-script.sh in /root path and I give run permissons. For init app-configuration-script.sh on init a use systemctl (this command and action is explained below)

4-create script run finish installation for change key luks passphrase -> This script generate a new random password for user root and hdd cypher with LUKS. The commands change the temporary passphrase of LUKS and copy in usb archive with date in name and make the same with root password.

*LUKS passphrase: For this I use a command cryptsetup with necessary params. The password must be read of file, then we must create two file with passwords. Create file key1 with temporary password luks and create file key2 for save new random password luks. Then we copy the new password on the LUSK free slot and remove the slot wich contain the temporary password

*Root password: For this I use a command chpasswd. In this case the password must be read of file too, with a correct format -> root:NEWPASSWORD


5-For use in virtual machine download plpbt.iso for run usb to init.

6-The usb init and unattended autoinstall debian.
This action is not performed -> (7-Whend finish the installation the news passwords exist in the usb which name clave_'date'

7.1-configure script for init on startup with systemcld for setup.sh)

----------------------------------------------------------------------------------------------------------------------------------------
Init script on startup:

-Systemd service unit

*create file in /etc/systemd/system/setup.service whit this:

--------------------------------------------------/

[Unit]

After=mysql.service

[Service]

ExecStart=/root/setup.sh

[Install]

WantedBy=default.target

--------------------------------------------------/

*In [Service] we must put the path of script wich we want to run

-Configure and Install. Run this commands:


chmod 744 /root/setup.sh

chmod 664 /etc/systemd/system/setup.service

systemctl enable setup.service


-Disable after run the script for not run never again:


systemctl disable setup.service

----------------------------------------------------------------------------------------------------------------------------------------
