#!/bin/bash

# This scirpt will prompt user for ALIAS name and PASSWORD on clean installation.
# This clean ALIAS will be saved to Public tahoe area with contents an encrypted string
# The decrypted string will point to the Private tahoe area for this box
#
# This script must be launched AFTER app_install_tahoe.sh and AFTER app_start_tahoe.sh
# if NEW_INSTALL as part of APP_CONFIGURATION_SCRIPT.
#
# This script is the light green area on the flow drawing

#if [ -f /tmp/.X0-lock ];
#then
#Dialog=Xdialog
#else
#Dialog=dialog
#fi

# This user interface will detect the enviroment and will chose a method based
# on this order : X no GTK, X with GTK , dialaog, none )

interface=0
if [ -x n/usr/bin/dialog ] || [ -x n/bin/dialog ]; then
    interface=dialog
else 
    inteface=none
    if [ -f /tmp/.X0-lock ]; then
        interface=X
        if [ -x /usr/bin/gtk]; then
            inteface=Xdialog
        fi
    fi
fi



prompt() {

textmsg="Enter some easy to remember ID here. \nThis will be used in case you need to recover your full system configuration from backup\n\
This id may be public visible\n\n\
Use an enough hard password with minimum 8 bytes and write down in a safe place.\n\n";

if [ ${#errmsg} -gt 0 ]; then
    color='\033[0;31m'
    nocolor='\033[0m'
    textmsg="${nocolor}$textmsg ${color} $errmsg"
    errmsg=""
fi



if [ $interface = "dialog" ]; then

dialog --colors --form "$textmsg" 0 0 3 "Enter your alias:" 1 2 "$myalias"  1 20 20 20 "Passwod:" 2 2 "" 2 20 20 20 "Repeat Password:" 3 2 "" 3 20 20 20 2> /tmp/inputbox.tmp

credentials=$(cat /tmp/inputbox.tmp)
rm /tmp/inputbox.tmp
thiscounter=0
local IFS='
'
for lines in $credentials; do
#while IFS= read -r lines; do
    if [ $thiscounter = "0" ]; then 
        myalias="$lines"
    fi
    if [ $thiscounter = "1" ]; then 
        myfirstpass="$lines"
    fi
    if [ $thiscounter = "2" ]; then 
        mysecondpass="$lines"
    fi
    ((thiscounter++));    
done 

else
echo -e $textmsg${nocolor}
# echo -e "Enter some easy to remember ID here. \nThis will be used in case you need to recover your full system configuration from backup\nThis id may be public visible\n\n"
read -p "What is your username? " -e myalias

echo -e "Use an enough hard password with minimum 8 bytes and write down in a safe place.\n\n"
read -p "Passwod:" -e myfirstpass

read -p "Repeat Passwod:" -e mysecondpass

fi


}


check_inputs() {

errmsg="";
# Are valid all these inputs ?
if [ -z "${myalias##*" "*}" ]; then
    errmsg="Spaces are not allowed";
fi

strleng=${#myalias}
if [[ $strleng -lt 8 ]]; then
    errmsg="$myalias ${#myalias} Must be at least 8 characters long"
fi

if [ -z "${myfirstpass##*" "*}" ]; then
    errmsg="Spaces are not allowed";
fi

strleng=${#myfirstpass}
if [[ $strleng -lt 8 ]]; then
    errmsg="$myfirstpass ${#myalias} Must be at least 8 characters long"
fi

if [ $myfirstpass != $mysecondpass ]; then
    errmsg="Please repeat same password"
fi

while [ ${#errmsg} -gt 0 ]; do
    echo "ERROR: $errmsg$errmsg2"
    prompt
    check_inputs
done
  
}


ofuscate () {
    thiscounter=0
    output=''
    while [ $thiscounter -lt 30 ]; do
        ofuscated=$ofuscated${myalias:$thiscounter:1}$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-4})
        ((thiscounter++));
    done
}


/etc/init.d/start_tahoe
prompt
check_inputs

# Convert this alias to encrypted key with pass=$myfirstpass and save as $myalias

# creates PEM 
rm /tmp/ssh_keys*
ssh-keygen -N $myfirstpass -f /tmp/ssh_keys 2> /dev/null
openssl rsa  -passin pass:$myfirstpass -outform PEM  -in /tmp/ssh_keys -pubout > /tmp/rsa.pem.pub

# create a key phrase for the private backup Tahoe node config and upload to public/$myalias file
# the $phrase is the entry point to the private area (pb:/ from /usr/node_1/tahoe.cfg )
# $phrase will be like "user pass URI:DIR2:guq3z6e68pf2bvwe6vdouxjptm:d2mvquow4mxoaevorf236cjajkid5ypg2dgti4t3wgcbunfway2a"
#frase=$(/home/tahoe-lafs/venv/bin/tahoe manifest -u http://127.0.0.1:3456 node_1: | head -n 1)
frase=$(cat /usr/node_1/private/accounts | head -n 1)
echo $frase | openssl rsautl -encrypt -pubin -inkey /tmp/rsa.pem.pub  -ssl > /tmp/$myalias
mv /tmp/$myalias /var/public_node/$myalias
ofuscate
cp /tmp/ssh_keys  /var/public_node/.keys/$ofuscated


# Decrypt will be used for restore only, and will discover the requied URI:DIR2 value for the private area node
# cat /var/public_node/$myalias | openssl rsautl -decrypt -inkey /tmp/ssh_keys # < Will prompt for password to decrypt it




exit


