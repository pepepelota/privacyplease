#!/bin/bash

# This scirpt will recover all aliases from Public Tahoe and prompt user to chose his/her ALIAS name and PASSWORD on recovering installation.
# Will download the ALIAS file from Public Tahoe and use PASSWORD to decrypt it and get the pb:// value for the private Tahoe where the 
# restoration files had been saved. 
#
# This script must be launched AFTER app_install_tahoe.sh and AFTER app_start_tahoe.sh
# if NEW_INSTALL as part of APP_CONFIGURATION_SCRIPT.
#
# This script is the light pink area on the flow drawing

# This user interface will detect the enviroment and will chose a method based
# on this order : X no GTK, X with GTK , dialaog, none )


collect_alias() {
    # Creates a hash with ALL existing alias, instead to fetch every time from the /var/public_node
    # this is going to be used as help  to remember your alias from entered characters, no case sensitive
    aliasesdb=$(dir /var/public_node -l  | grep ^- | cut -c 42-)
    # for names in $aliasdb; do echo $names; done
}

alias_help() {
    textmsg="Please select you ALIAS from the list:";
    echo -n "Enter your ALIAS:"
    while [[ $alias != *$'\n'* ]]; do
        read -s -n 1  myalias2
        if [[ $myalias2 == $'' ]]; then
           break
        fi
        if [[ $myalias2 == $'\b' ]]; then
           alias=${alias::-1}
           echo -n -e "\r$alias "
        fi
        if [[ $myalias2 == [Aa-Zz,.,-,0-9,_] ]]; then
           alias=$alias$myalias2
        fi
        clear
        alias_lc=${alias,,}
        for names in $aliasesdb; do
           names=${names,,}
           if [[ $names == *$alias_lc* ]]; then
              echo -n -e "$names\t"
              
           fi
        done
        echo
        echo -n $textmsg
        echo -n -e "$alias"

    done
    echo "has metido alias=$alias"
    exit
    # Show some alias that can match yours
}



select_dialog() {
if [ -x /usr/bin/dialog ] || [ -x /bin/dialog ]; then
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
}

select_alias() {

#This will offer a dialog to the user to chose his/her ALIAS to be used on recovery tasks
textmsg="Please select you ALIAS from the list:\n\n:";

if [ $interface = "dialog" ]; then
    
    dialog --colors --menu "$textmsg" 0 0 15 alias1 "" alias2 "" alias3 "" alias4 "" alias5 ""  2> /tmp/alias
    alias=$(cat /tmp/alias)
else 
    read -p "$textmsg" -e alias
fi

echo "El alias seleccionado es $alias"

}



prompt_pass() {

textmsg="Enter $alias PASSWORD for system recovery from backup\n\n";

if [ ${#errmsg} -gt 0 ]; then
    textmsg=$textmsg\\Z1$errmsg
    errmsg=""
fi



if [ $interface = "dialog" ]; then

    dialog --colors --form "$textmsg" 0 0 1 "Passwod:" 1 2 "" 1 20 20 20 2> /tmp/inputbox.tmp
    passwd=$(cat /tmp/inputbox.tmp)
    rm /tmp/inputbox.tmp
else
    read -p "$textmsg" -e passwd
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
done
  
}

deofuscate () {
    deo='';
    thiscounter=0
    com="????";
    while [ $thiscounter -lt 30 ]; do
        deo=$deo${alias:$thiscounter:1}$com
        ((thiscounter++));
    done
}


moving () {

    if [ "$moving_char" == "-" ]; then
        moving_char="\\"
        return
    fi
    if [ "$moving_char" == "|" ]; then
        moving_char="/"
        return
    fi
    if [ "$moving_char" == "\\" ]; then
        moving_char="|"
        return
    fi
    if [ "$moving_char" == "/" ]; then
        moving_char="-"
        return
    fi

}


check_tahoe_cpu_load () {
    moving_char="-"
    # if cpu load used by tahoe instances are higher than 10% all operations through tahoe services
    # are too slow
    # we would need to wait until there enough resources to start tasks on tahoe services
    # usually on idle status ( only offered space ) CPU load must be < 2%

    # This is also notciable on tcpdump -n port 9001 or port 443 , tracking the Tor entry point IP

    tahoe_node_1_load=99
    while [ $tahoe_node_1_load -gt 10 ]; do
        tahoe_node_1_load=$(ps auxwwww | grep tahoe | grep -v grep | grep node_1 | cut -c 15-19 | cut -d \. -f 1)
        echo -n -e "\rTahoe node_1 load is $tahoe_node_1_load ... please wait $moving_char"
        sleep 5
        moving
    done

    tahoe_public_node_load=99
    while [ $tahoe_public_node_load -gt 10 ]; do
        tahoe_public_node_load=$(ps auxwwww | grep tahoe | grep -v grep | grep public_node  | cut -c 15-19 | cut -d \. -f 1)
        echo -n -e "\rTahoe public_node load is $tahoe_public_node_load ... please wait $moving_char"
        sleep 5
        moving
    done
}

collect_alias
select_dialog
#select_alias
alias_help
prompt_pass
echo "Se usara el pass $passwd para desencriptar el alias $alias"
deofuscate
echo "DEO:$deo";
check_tahoe_cpu_load

# tomamos el ficheor $alias de /var/public_node
# necesitamos la key priv protegida con la clave subida en una intalación inicial por el usuario que 
# al habriamos subido con otro nombre secreto a /var/public_node/.keys
# Save on pb_point the node ID to mount /var/node_1 and recover all files from it

pb_point=$(echo $passwd | openssl rsautl -decrypt -inkey /var/public_node/.keys/$deo -in /var/public_node/$alias -passin stdin)

# if running, stop private node
/home/tahoe-lafs/venv/bin/tahoe stop node_1

# reconfigure node_1 mapping point
# we need no just to restore my files, also my storage that contents file chunks from others to rebuild the full lost node
# and avoid damages in the grid performance and realibility
# we need to check there not existing node with same node_1 directory mounted in other box

echo $pb_point | cut -d \  -f 1,2 > /root/.tahoe/node_1  # save credentials for node_1 restoration
echo $pb_point > /usr/node_1/private/accounts            # save cap for node_1 restoration

# now we will able start to node_1 ,mount /var/node_1 and first of all recover node_1.tar.gz for the full node_1 restoration
# including the shares 

/home/tahoe-lafs/venv/bin/tahoe start /usr/node_1

# Check connected enough good nodes before to continue 

connnode_1=0
while [ $connnode_1 -lt 7 ]; do
    connnode_1=$(curl http://127.0.0.1:3456/ 2> /dev/null| grep "Connected to tor" | wc -l)
done

# Now we know node_1 is ready, let's go to do paranoic check/repair on it

/home/tahoe-lafs/venv/bin/tahoe deep-check --repair -u http://127.0.0.1:3456 node_1:

# Recover the backup file 
echo "Please wait. This will take over 30 minutes..."
/home/tahoe-lafs/venv/bin/tahoe cp -u http://127.0.0.1:3456 node_1:sys.backup.tar.gz /tmp/. &

# Mostramos progreso del download 
progress="00.00.00"
while [ ${#progress} -gt 5 ];do
    progress=$(curl http://127.0.0.1:3456/status/down-1 2> /dev/null | grep Progress:)
    echo -e -n "\r$progress"
    if [[ $progress =~ "100.0" ]]; then
        progress=""
    fi
    sleep 10
done

# Gracefully stop all Tahoe nodes before to extract files from backup
/home/tahoe-lafs/venv/bin/tahoe stop /usr/node_1
/home/tahoe-lafs/venv/bin/tahoe stop /usr/public_node







umount /var/node_1
user=$(cat /root/.tahoe/node_1 | cut -d \  -f 1)
pass=$(cat /root/.tahoe/node_1 | cut -d \  -f 2)
sleep 20s
echo $pass | sshfs $user@127.0.0.1:  /var/node_1  -p 8022 -o no_check_root -o password_stdin -o StrictHostKeyChecking=no

cp /var/node_1/node_1.tar.gz /tmp/.
cp /var/node_1/box.tar.gz /tmp/.

# stop node_1 and umount it
umount /var/node_1
/home/tahoe-lafs/venv/bin/tahoe stop /usr/node_1

# decompress :
# node_1.tar.gz is a backup of full node_1 /usr/node_1 
#               created : tar -czpPf /tmp/node_1.tar.gz /usr/node_1 && cp /tmp/node_1.tar.gz /var/node_1/. 
#               &&  tahoe cp -u https://127.0.0.1:3456 node_1: /tmp/node_1.tar.gz /.
# box.tar.gz    is a backup of other required files. This is based on the /etc/backup/backup.cfg file used by app_backup.sh
#               where app_backup.sh is called from crond



exit

