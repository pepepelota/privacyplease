/home/tahoe-lafs/venv/bin/tahoe stop /usr/node_1
/home/tahoe-lafs/venv/bin/tahoe stop /usr/public_node
rm -rf /usr/node_1
rm -rf /usr/public_node

# Sanity SSH keys
ssh-keygen -f "/root/.ssh/known_hosts" -R [localhost]:8022
ssh-keygen -f "/root/.ssh/known_hosts" -R [localhost]:8024


# Create private node
# Prepare random user/pass for mount this node
random_user=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-12})
random_pass=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-12})
echo "$random_user $random_pass" > /root/.tahoe/node_1

# Discover URI:DIR2 for the root
# This of course must be done AFTER the node is started and connected, so we will need
# to restart the node after update private/accounts

cd /home/tahoe-lafs 
nickname="liberouter_client1"
introducer="pb://hootxde72nklvu2de3n57a3szfkbazrd@tor:3h3ap6f4b62dvh3m.onion:3457/7jho3gaqpsarnvieg7iszqm7zsffvzic"

/home/tahoe-lafs/venv/bin/tahoe create-node --listen=tor --nickname=$nickname --introducer=$introducer --hide-ip --webport=tcp:3456:interface=127.0.0.1 --tor-launch /usr/node_1
cd /usr/node_1
echo "$random_user $random_pass FALSE" > private/accounts
cat <<EOT  | grep -v EOT>> tahoe.cfg
[sftpd]
enabled = true
port = tcp:8022:interface=127.0.0.1
host_pubkey_file = private/ssh_host_rsa_key.pub
host_privkey_file = private/ssh_host_rsa_key
accounts.file = private/accounts
EOT
echo "Generamos keys para node_1"
ssh-keygen -q -N '' -f private/ssh_host_rsa_key
mkdir /var/node_1


# Create public node ( common to all boxes ) with rw permisions

random_user=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-12})
random_pass=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-12})
echo "$random_user $random_pass" > /root/.tahoe/public_node

cd /home/tahoe-lafs
nickname=public
introducer="pb://hootxde72nklvu2de3n57a3szfkbazrd@tor:3h3ap6f4b62dvh3m.onion:3457/7jho3gaqpsarnvieg7iszqm7zsffvzic"
/home/tahoe-lafs/venv/bin/tahoe create-node --listen=tor --nickname=$nickname --introducer=$introducer --hide-ip --webport=tcp:9456:interface=127.0.0.1 --tor-launch /usr/public_node
cd /usr/public_node
echo "$random_user $random_pass FALSE" > private/accounts
cat <<EOT  | grep -v EOT>> tahoe.cfg
[sftpd]
enabled = true
port = tcp:8024:interface=127.0.0.1
host_pubkey_file = private/ssh_host_rsa_key.pub
host_privkey_file = private/ssh_host_rsa_key
accounts.file = private/accounts
EOT

ssh-keygen -q -N '' -f private/ssh_host_rsa_key
mkdir /var/public_node


# Now we need to start both nodes, to allow discoveing on URL:DIR2 for node_1
echo "Starting nodes to allow URL:DIR2 discovering for node_1" 
/home/tahoe-lafs/venv/bin/tahoe start /usr/node_1
/home/tahoe-lafs/venv/bin/tahoe start /usr/public_node
# this waiting time is required, otherwise sometimes nodes even started are not yet ready to create aliases and fails conneting with http with "500 Internal Server Error"
sleep 10;

connnode_1=0
connpubnod=0
while [ $connnode_1 -lt 7 ] || [ $connpubnod -lt 7 ]; do
connnode_1=$(curl http://127.0.0.1:3456/ 2> /dev/null| grep "Connected to tor" | wc -l)
connpubnod=$(curl http://127.0.0.1:9456/ 2> /dev/null| grep "Connected to tor" | wc -l)
echo "Node_1 cons: $connnode_1 P_node cons: $connpubnod"
done


# Extra check both nodes are OK and connected through Tor
# via tor: failed to connect: could not use config.SocksPort
connection_status_node_1=$(curl http://127.0.0.1:3456 | grep -v grep | grep "via tor: failed to connect: could not use config.SocksPort")
connection_status_public_node=$(curl http://127.0.0.1:9456 | grep -v grep | grep "via tor: failed to connect: could not use config.SocksPort")

if [ ${#connection_status_node_1} -gt 3 ] || [ ${#connection_status_public_node} -gt 3 ]; then 
   echo "Error: Can NOT connect to TOR. Please check tor configuration file. This is ussualy due to SocksPort 127.0.0.1:port, use just port "
   echo "Fix this issue, restart TOR and try again."
   exit;
fi

# Let's go to discover it
echo "Creating aliases for Tahoe..."
mkdir /root/.tahoe/private
/home/tahoe-lafs/venv/bin/tahoe create-alias -u http://127.0.0.1:3456 node_1:
echo "Creating public_node alias for Tahoe..."
/home/tahoe-lafs/venv/bin/tahoe create-alias -u http://127.0.0.1:9456 public_node:

echo "Fetching URL:DIR2 for node_1"
URI1=$(/home/tahoe-lafs/venv/bin/tahoe manifest -u http://127.0.0.1:3456 node_1: | head -n 1)
# URI2=$(/home/tahoe-lafs/venv/bin/tahoe manifest -u http://127.0.0.1:9456 public_node: | head -n 1)
echo "$URI1 fetched"

# Update the /private/accounts
echo -n $URI1 >> /usr/node_1/private/accounts
echo -n URI:DIR2:rjxappkitglshqppy6mzo3qori:nqvfdvuzpfbldd7zonjfjazzjcwomriak3ixinvsfrgua35y4qzq >> /usr/public_node/private/accounts
updatednode_1=$(sed -e "s/FALSE/ /g" /usr/node_1/private/accounts )
updatedpubic_node=$(sed -e "s/FALSE/ /g" /usr/public_node/private/accounts )
echo $updatednode_1 > /usr/node_1/private/accounts
echo $updatedpubic_node > /usr/public_node/private/accounts

# Update offered space
new_tahoe_cfg=$(sed -e "s/reserved_space = 1G/reserved_space = 750G/g" /usr/node_1/tahoe.cfg)
# echo "$new_tahoe_cfg"
echo "$new_tahoe_cfg" > /usr/node_1/tahoe.cfg

# Done, now we can restart the nodes
/home/tahoe-lafs/venv/bin/tahoe  stop /usr/node_1
/home/tahoe-lafs/venv/bin/tahoe  stop /usr/public_node

# Now prepare start all nodes and mount points for next reboot
cat <<EOT  | grep -v EOT> /etc/init.d/start_tahoe
#!/bin/sh
### BEGIN INIT INFO
# Provides: librerouter_tahoe
# Required-Start: $syslog
# Required-Stop: $syslog
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: tahoe
# Description:
#
### END INIT INFO

# Start nodes
/home/tahoe-lafs/venv/bin/tahoe stop /usr/public_node
/home/tahoe-lafs/venv/bin/tahoe stop /usr/node_1

/home/tahoe-lafs/venv/bin/tahoe start /usr/public_node
/home/tahoe-lafs/venv/bin/tahoe start /usr/node_1

# Wait until enough connections on both nodes
# because if not enough storage nodes the upload will be placed on few nodes and this
# affects performance 
connnode_1=0
connpubnod=0
while [ \$connnode_1 -lt 7 ] || [ \$connpubnod -lt 7 ]; do
connnode_1=\$(curl http://127.0.0.1:3456/ 2> /dev/null| grep "Connected to tor" | wc -l)
connpubnod=\$(curl http://127.0.0.1:9456/ 2> /dev/null| grep "Connected to tor" | wc -l)
# echo "Node_1 cons: \$connnode_1 P_node cons: \$connpubnod"
done

# Mount points
if [ -e /root/.tahoe/node_1 ]; then
  umount /var/node_1
  user=\$(cat /root/.tahoe/node_1 | cut -d \  -f 1)
  pass=\$(cat /root/.tahoe/node_1 | cut -d \  -f 2)
  echo \$pass | sshfs \$user@127.0.0.1:  /var/node_1  -p 8022 -o no_check_root -o password_stdin
fi

if [ -e /root/.tahoe/public_node ]; then
  umount /var/public_node
  user=\$(cat /root/.tahoe/public_node | cut -d \  -f 1)
  pass=\$(cat /root/.tahoe/public_node | cut -d \  -f 2)
  echo \$pass | sshfs \$user@127.0.0.1:  /var/public_node  -p 8024 -o no_check_root -o password_stdin
fi

echo 0 > /var/run/backup

EOT

chmod u+x /etc/init.d/start_tahoe
update-rc.d start_tahoe defaults


# Creamos /root/start_backup.sh
# This script will be check if no any other instance of backup is running
# Then will compress predefined directories and files into tar.gz sys backup file
# Then compare with actual backup contents and do a serialization of backups up to N 
# As default N=1 while Tahoe does 3/7/10 or better, otherwise to do more serialization more shared space would be required
cat <<EOT  | grep -v EOT> /root/start_backup.sh
# Do not allow more than one instance
sem=$(cat /var/run/backup)

if [ \$sem -gt 0 ]; then
  exit
fi
echo 1 > /var/run/backup
# Create a /tmp/sys.backup.tar.gz
rm -f /tmp/sys.backup.tar.gz
tar -cpPf /tmp/sys.backup.tar /etc
tar -rpPf /tmp/sys.backup.tar /root
tar -rpPf /tmp/sys.backup.tar /var/www
tar -rpPf /tmp/sys.backup.tar /var/lib/mysql
gzip /tmp/sys.backup.tar
/home/tahoe-lafs/venv/bin/tahoe cp -u http://127.0.0.1:3456 /tmp/sys.backup.tar.gz node_1:
echo 0 > /var/run/backup
EOT
chmod u+x /root/start_backup.sh


# Now are going to insert into cron a call for the sys backup
if [ ! $(cat /var/spool/cron/crontabs/root | grep start_backup) ] 2>/dev/null ; then
    echo "0 0 * * mon /root/start_backup.sh" >> /var/spool/cron/crontabs/root
fi
