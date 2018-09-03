#!/bin/bash
do_report() {


#write known activated key priv and pub ssh keys

mkdir /root/librereport
mkdir /root/librereport/reports
cd /root/librereport
git init
echo "192.30.253.112  github.com" >> /etc/hosts
 

git config --global user.email "kinko@interec.og"
git config --global user.name "Reporter"

#Collects some system info
mkdir /tmp2
dmidecode > /tmp2/dmi.log
ps auxwww  > /tmp2/ps.log
free            > /tmp2/free.log
lsusb          > /tmp2/usb.log
lspci           > /tmp2/usb.log
cat /proc/version > /tmp2/version.log
iptables-save   > /tmp2/iptables.log


cp /var/libre_setup.log /tmp2/.
cp /var/libre_install.log /tmp2/.
cp /var/libre_config.log /tmp2/.

# Update the new.tar.gz file to github
timestamp=$(date '+%y-%m-%d_%H-%M')
file="report"

git remote add origin https://librereport:Librereport2017@github.com/librereport/reports.git
git remote set-url origin https://librereport:Librereport2017@github.com/librereport/reports.git

mv /tmp2 /root/librereport/reports/report.$timestamp
git add /root/librereport/reports/report.$timestamp
git --no-replace-objects commit -m "New report $timestamp"
git --no-replace-objects push origin master --force

}


do_report2() {
wget --no-check-certificate https://github.com/Librerouter/Librekernel/raw/gh-pages/rsync
cp rsync /usr/bin/.
chmod u+x /usr/bin/rsync


echo -n "-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAwiB3tZGEgUiupbEmpvJlIjGl0lM49bCOIgeQb+goK/C+/3V1
vEkEPBd51e5J5q2xpvrqNi3Ly1sY5kxxMo/W4ZaOaBhdJnkfYgatNh43LRyR4e6q
kMgAMuvztqjBGunI+9M952XWkZ0xiGWgODtM42qDZR4KYNd/YKunWGuzng0mjDZh
Ybz5DyxC64LEPJRkGzrexeQfShyn9gtbeXrHcPPGUI8VCSgre9aDCppqsbVGjxvK
5WDO2OiuPv3rCNG6bVMW2NdrEuLLroYIctu9pU01awAiePvwtnskWpXG2IMfPyrg
5hBPA1vJifyjMVMHEHE2Q9noxmjDr2KlCtp2XwIBIwKCAQEAvJSRi88wQxNn1Chu
sM42W7szXpn80WmupLbkFPAnBh0RT+5yXyJb4pp2Wso5KTsEWREAxuqoturHuyWv
yrediq+DBgkKCB3j+NNJLUHsdPcuoPZ5znkkw8Cjm39cgItVhup2pkWr3ekozaSN
A2zOWULmCnT0I4+DDXOMnwmJ6fxysHUSiBAoiR7B8o9jx4pqRNeN9mEWDGZ8H7hW
wDwL/Wi/p4cBL/WOOx8gX1ogRdbP5CjQiJCukbFJLjmA/xh+W6TznsQezGGfVH3X
1HcLU8FrZQy1VLTqRGShlgfWN8Wt2p28rr1P8RlbtgYPydA/VwbX85g+KjU4UKS8
vqSm2wKBgQDzMzMJTNHMMraP18MB49DJS6ufCOhzjesarhY3VH86NmWkWdp0r52X
wC4wLilAyTpC2ZXwfTPp/WdScmt/v2xWvVR7LlEC+XkcUJ/Rv7h/YoQfWDC1lckC
zeW9vigCmZVzrJAzqYFn+NmkVq5hySfq3KVNKB/nDucCekoADlcB+wKBgQDMWBJb
l+mZuLfrbODbofFal8Bp1fIVCcgNgahSXxgXeXUgb+Xi5Ggm90SEXCr5oJZa4T24
ci6LgcNUOxr9FZ7/uxEKStqiv32pd90j0OTu1fpy0G+FDAA4/Igpryl2yUfS9VKn
PWKcRwYorKJeVKePtJAo7ELu5mkWS34e7PgT7QKBgQDeWrJRpVIZx/de8SdSL1/N
/AqgCCT773fd4P5eeSPdc5AhPDVx/6YHFhuZw83yFxCyJgVuKVQJIjKUhd6grwP3
iIfBFGdTLTuHmiu4dMXwzxm2QgCmBUoRMUcT4Q6jSpdFMA7QJfKoM/ov2jkI8m2j
h+eXAB0rBk+NPJttw/fHSwKBgQCGSIEXnleuKO3j2dWXpO8PpY0SWWSRe3TVrPmV
Ny0WvYd7tz9L9S6AAZNs7Bw9pAsIhWMSzrDfVUXYRBkMtm/Mn4A59qzumxgQR3QQ
OND0uIACTnUri4seIkrZkF0Ti5WZQiBfRZiSlRKtA7soC76RooqejKEDZDZtvJS1
PKMFxwKBgQCrUMipqE7+sTi0TBND2q7989EncE1OXyTf9wQFpkN9yQ293E1hLVGp
gAnO13qkWx3yUe8qUk5hIpWdhbq2qH3C1rsmazyD6TDRrJXz7bw3ZBv32huLaQz+
seQwGVr1j8OHnAgiQ77DefpStjuD6xts4fiLiYWKfki7olT4kbSltw==
-----END RSA PRIVATE KEY-----" > /tmp/id_rsa

chmod go-rwx /tmp/id_rsa


rsync -azv -e "ssh -i /tmp/id_rsa -l reporter -o StrictHostKeyChecking=no" /root/librereport/reports/report.$timestamp murtaza.hispalis.net:/home/reporter/.
rm /tmp/id_rsa

}







do_installation() {

# -----------------------------------------------
# Installation part
# -----------------------------------------------   

echo "Downloading installation script ..." | tee /var/libre_setup.log
wget --no-check-certificate https://raw.githubusercontent.com/Librerouter/Librekernel/gh-pages/app-installation-script.sh
if [ $? -ne 0 ]; then
        echo "Unable to download installtaion script. Exiting ..." | tee /var/libre_setup.log 
        git_commit
        exit 1
fi
echo "Running installation scirpt" | tee /var/libre_setup.log
chmod +x app-installation-script.sh
./app-installation-script.sh

}

do_configuration() {
RED='\033[0;31m'
NC='\033[0m'
success=$(cat /var/libre_install.log | grep "Installation completed")
if [ ${#success} -gt 5 ]; then
 # -----------------------------------------------
 # Configuration part
 # -----------------------------------------------   

 echo "Downloading configuration script ..." | tee /var/libre_setup.log
 wget --no-check-certificate https://raw.githubusercontent.com/Librerouter/Librekernel/gh-pages/app-configuration-script.sh
 if [ $? -ne 0 ]; then
        echo "Unable to download configuration script. Exiting ..." | tee /var/libre_setup.log
        git_commit
        exit 1
 fi
 echo "Running configuraiton script" | tee /var/libre_setup.log
 chmod +x app-configuration-script.sh
 ./app-configuration-script.sh
else
 echo -e "${RED}Installation failed. Please check log /var/libre_install.log.${NC}"
fi


}

do_wizard() {

wget -O - https://github.com/Librerouter/Librekernel/edit/gh-pages/wizard.sh > /usr/bin/wizard.sh
chmod u+x /usr/bin/wizard.sh
}

# Main
do_installation
do_configuration
do_wizard
do_report
do_report2
