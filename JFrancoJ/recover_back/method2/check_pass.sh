
read -p "Enter your root passwd here:" -e plain_pass

method=$(cat /etc/shadow | head -n 1 | cut -d \$ -f 2)
salt=$(cat /etc/shadow | head -n 1 | cut -d \$ -f 3 | cut -d : -f 1)
enc_pass=$(cat /etc/shadow | head -n 1 | cut -d \$ -f 4 | cut -d : -f 1)

if [ $method == "6" ]; then method_name="-msha-512"; fi
if [ $method == "5" ]; then method_name="-msha-256"; fi
if [ $method == "2a" ]; then method_name="-mdes"; fi
if [ $method == "1" ]; then method_name="-mmd5"; fi

new_enc=$(mkpasswd $method_name $plain_pass $salt)

new_enc_pass=$(echo $new_enc | cut -d \$ -f 4 | cut -d : -f 1)

if [ $enc_pass == $new_enc_pass ]; then 
    echo "Premio"
else
    echo "oooooooopssssss it's wrong"
fi

exit

# GENERAL
# The goal is to use hashed credentials instead encrypted only phrases
# At same time avoid to prompt user for unneceary inputs


# Update credentials to tahoe grid public_node when the user changes his librerouter root password
# This info is valid to recover the URI:DIR2 from serial_number + /etc/shadow/passwd 
# or in the event the installation is recovering from a new one from user input serial_number + old_password 
#
# The  files in the public grid:
# /var/public_node/DMS1-DFMF-PMM7-RFY6 this is named with the serial number and contents the salt in clear text
# /var/public_node/161Lkz2v_Jm1sUuwLJlJlTufENw3DZwV3T5TXIsWIrE.Bw3pneziGSBvNuicYKA_3Ub11nxzRqJcBvrYfQq8ozMvT4GmwqZoU. have the encripted URI:DIR2
# /var/public_node/.keys/161Lkz2v_Jm1sUuwLJlJlTufENw3DZwV3T5TXIsWIrE.Bw3pneziGSBvNuicYKA_3Ub11nxzRqJcBvrYfQq8ozMvT4GmwqZoU. contents ssh key
#      the one that was used to generated the PEM certificate
serial_number=$(cat /root/libre_scripts/sn)
salt=$(cat /etc/shadow | head -n 1 | cut -d \$ -f 3 | cut -d : -f 1)
sne=$(mkpasswd  -msha-512 $serial_number $salt | tr / _ | tr \$ 1)
echo $salt > /var/public_node/$serial_number
p=$(cat /etc/shadow | head -n 1 | cut -d \$ -f 4 | cut -d : -f 1)
rm /tmp/ssh_keys
ssh-keygen -N $p -f /tmp/ssh_keys 2> /dev/null
openssl rsa  -passin pass:$p -outform PEM  -in /tmp/ssh_keys -pubout > /tmp/rsa.pem.pub
frase=$(cat /usr/node_1/private/accounts | head -n 1)
echo $frase | openssl rsautl -encrypt -pubin -inkey /tmp/rsa.pem.pub  -ssl > /tmp/$sne
mv /tmp/$sne /var/public_node/$sne
cp /tmp/ssh_keys /var/public_node/.keys/$sne


#For recovering:

#First case: Recovering is runing on same machine, same Serial_Number and same root password
#We know the Serial_Number and the /etc/shadow, so we will not prompt user for credentials
#And will discover the URI:DIR2 from Serial_Number and /etc/shadow hashed root password
# 
#
p=$(cat /etc/shadow | head -n 1 | cut -d \$ -f 4 | cut -d : -f 1)
serial_number=$(cat /root/libre_scripts/sn)
salt=$(cat /etc/shadow | head -n 1 | cut -d \$ -f 3 | cut -d : -f 1)
sne=$(mkpasswd  -msha-512 $serial_number $salt | tr / _ | tr \$ 1)
frase=$(cat /var/public_node/$sne)
pb_point=$(echo $p | openssl rsautl -decrypt -inkey /var/public_node/.keys/$sne -in /var/public_node/$sne -passin stdin)
echo $pb_point > /usr/node_1/private/accounts
/etc/init.d/start_tahoe
/home/tahoe-lafs/venv/bin/tahoe cp node_1:sys.backup.tar.gz /tmp/.


#Second case: The user is going to recover a lost librerouter, then he/she knows his older Serial_Number and root password
#The key is to regenerate the hash again and recover using same salt he used on older box , then we will know the internal
#hash and we can recover the encrypted URI:DIR2

read -p "Please find your Serial Number of the box your are going to recover:" -e serial_number
read -p "Please enter the root password of the box you are going to recover:" -e pass
salt=$(cat /var/public_node/$serial_number)
sne=$(mkpasswd  -msha-512 $serial_number $salt | tr / _ | tr \$ 1)
frase=$(cat /var/public_node/$sne)
encpass=$(mkpasswd  -msha-512 $pass $salt)
p=$(echo $encpass | head -n 1 | cut -d \$ -f 4 | cut -d : -f 1)
pb_point=$(echo $p | openssl rsautl -decrypt -inkey /var/public_node/.keys/$sne -in /var/public_node/$sne -passin stdin)
echo $pb_point > /usr/node_1/private/accounts
/etc/init.d/start_tahoe
/home/tahoe-lafs/venv/bin/tahoe cp node_1:sys.backup.tar.gz /tmp/.






# Dos caminos :
#  1  Estamos en la misma maquina desde la que se hizo el backup.
#     Por lo tanto conocemos el SN y el shadow completo
#  2  Estamos en una instlacion nueva, con lo que conocemos
#     el SN y el passwd plano del root ( de la anterior instalacion )
#
#  Desde cualquiera de ambos caminos se debe obtener el DIR:URI2 del nodo_1 para recuperar
#
#  No podemos guardar en el public_node ninguna cosa secreta sin hashearla ( no solo encriptarla ) 
#  Tenemos guardado en un principio un fichero con nombre tipo
#  /var/public_node/161454345431QyCYpD4axT4NOJuh.a.Y3d8bAjDnhGbIpOjrgr_CXkr4kPSLgGuHzrMSm4kh2XCnpllLfy1hAFdBTOL1sIPbJ1
#  el cual es localizable porque se hizo con  $(mkpasswd  -msha-512 $serial_number $salt | tr / _ | tr \$ 1) su nombre
#  dentro del cual podremos guardar encriptada como hasta ahora la URI:DIR2 del node_1 y que se desencripta con la llave
#  que hay en /var/public_node/$ofuscado y que antes usaba la clave del usuario y ahora usara un trozo del hash  
#  En el caso 1 desencriptariamos con otra cosa que fuera la clave root, p.e. un trozo del hash de /etc/shadow
#
#  En el caso 2, teniendo el pass del root y el SN hay que obtener el $salt del root anterior que hizo la copia de backup
#  Con el pass del root y el salt, generamos una encpass que correspondera al /etc/shadow anterior, con lo cual ... problema resuelto
#
#  La subida de credenciales hace:
#  Toma SN y salto con lo que $(mkpasswd  -msha-512 $serial_number $salt | tr / _ | tr \$ 1) crea un nombre de fichero $sne
#  Mete en $sn el valor $salt sin encriptar del /etc/shadow
#  Toma parte del hash encpass del /etc/shadow => $p
#  Encripta URI:DIR2 con clave $p y key /tmp/key.pem y la pone en fichero $sne
#  Copia /tmp/ssh_keys a /var/public_node/.keys/$sne_ofuscated

serial_number=$(cat /root/libre_scripts/sn)
salt=$(cat /etc/shadow | head -n 1 | cut -d \$ -f 3 | cut -d : -f 1)
sne=$(mkpasswd  -msha-512 $serial_number $salt | tr / _ | tr \$ 1)
echo $salt > /var/public_node/$serial_number
p=$(cat /etc/shadow | head -n 1 | cut -d \$ -f 4 | cut -d : -f 1)
rm /tmp/ssh_keys
ssh-keygen -N $p -f /tmp/ssh_keys 2> /dev/null
openssl rsa  -passin pass:$p -outform PEM  -in /tmp/ssh_keys -pubout > /tmp/rsa.pem.pub
frase=$(cat /usr/node_1/private/accounts | head -n 1)
echo $frase | openssl rsautl -encrypt -pubin -inkey /tmp/rsa.pem.pub  -ssl > /tmp/$sne
mv /tmp/$sne /var/public_node/$sne
cp /tmp/ssh_keys /var/public_node/.keys/$sne

# Caso 1: La recuperacion desde misma maquina hace:
# Lee del hash encapss del /etc/shdow -> $p
# Hace  mkpasswd  -msha-512 $serial_number $salt | tr / _ | tr \$ 1 para obtener $sne2
# Baja $sne y desencripta su contenido con la key /var/public_node/.keys/$sne_ofuscated y password $p extrayendo URI:DIR2

p=$(cat /etc/shadow | head -n 1 | cut -d \$ -f 4 | cut -d : -f 1)
serial_number=$(cat /root/libre_scripts/sn)
salt=$(cat /etc/shadow | head -n 1 | cut -d \$ -f 3 | cut -d : -f 1)
sne=$(mkpasswd  -msha-512 $serial_number $salt | tr / _ | tr \$ 1)
frase=$(cat /var/public_node/$sne)
pb_point=$(echo $p | openssl rsautl -decrypt -inkey /var/public_node/.keys/$sne -in /var/public_node/$sne -passin stdin)
echo $pb_point > /usr/node_1/private/accounts
/etc/init.d/start_tahoe
/home/tahoe-lafs/venv/bin/tahoe cp node_1:sys.backup.tar.gz /tmp/.


# Caso 2: La recuperacion desde otra instalacion o otra maquina hace:
# Pregunta al usuario SN y password anteriores
# Abre $sn ( $serial_number ) y obtiene $salt
# Localiza que $sne es el suyo con $(mkpasswd  -msha-512 $serial_number $salt | tr / _ | tr \$ 1)
# Regenera hash encap a partir de $salt y $password y obtiene $p
# Baja $sne y desencripta su contenido con la key /var/public_node/.keys/$sne_ofuscated y password $p extrayendo URI:DIR2

read -p "Please find your Serial Number of the box your are going to recover:" -e serial_number
read -p "Please enter the root password of the box you are going to recover:" -e pass
salt=$(cat /var/public_node/$serial_number)
sne=$(mkpasswd  -msha-512 $serial_number $salt | tr / _ | tr \$ 1)
frase=$(cat /var/public_node/$sne)
encpass=$(mkpasswd  -msha-512 $pass $salt)
p=$(echo $encpass | head -n 1 | cut -d \$ -f 4 | cut -d : -f 1)
pb_point=$(echo $p | openssl rsautl -decrypt -inkey /var/public_node/.keys/$sne -in /var/public_node/$sne -passin stdin)
echo $pb_point > /usr/node_1/private/accounts
/etc/init.d/start_tahoe
/home/tahoe-lafs/venv/bin/tahoe cp node_1:sys.backup.tar.gz /tmp/.

# Por defecto todo el sistema usara sha-512
# La subida de credenciales se realiza cada vez que el usuario CAMBIE de password de root en su librerouter
# El backup ya es realizado desde el cron llamando al script start_backup.sh
# La recuperacion es siempre llamada manual desde el wizard.sh

#
#
# Como evitar collisions de passwd plano ( mas de un usuario de librerouter puso el mismo passwd )
# No hay peligro, para ello deberian coincidir ambos valores el $serial_number y el password del root
#
