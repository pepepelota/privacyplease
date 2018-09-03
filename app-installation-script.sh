#!/bin/bash
# ---------------------------------------------
# Variables list
# ---------------------------------------------
PROCESSOR="Not Detected"   	# Processor type (ARM/Intel/AMD)
HARDWARE="Not Detected"    	# Hardware type (Board/Physical/Virtual)
PLATFORM="Not Detected"         # Platform type	(U12/U14/D7/D8/T7)
EXT_INTERFACE="Not Detected"	# External Interface (Connected to Internet) 
INT_INTERFACE="Not Detected"	# Internal Interface (Connected to local network)


# ----------------------------------------------
# Env Variables
# ----------------------------------------------
export GIT_SSL_NO_VERIFY=true
export INSTALL_HOME=`pwd`
export DEBIAN_FRONTEND=noninteractive


#----------------------------------------------
# This function detects platform.
#
# Suitable platform are:
#
#  * Ubuntu 12.04
#  * Ubuntu 14.04
#  * Debian GNU/Linux 7
#  * Debian GNU/Linux 8  
#  * Trisquel 7
# ----------------------------------------------
get_platform() 
{
        echo "Detecting platform ..." | tee /var/libre_install.log
	FILE=/etc/issue
	if cat $FILE | grep "Ubuntu 12.04" >> /var/libre_install.log; then
		PLATFORM="U12"
	elif cat $FILE | grep "Ubuntu 14.04" >> /var/libre_install.log; then
		PLATFORM="U14"
	elif cat $FILE | grep "Debian GNU/Linux 7" >> /var/libre_install.log; then
		PLATFORM="D7"
	elif cat $FILE | grep "Debian GNU/Linux 8" >> /var/libre_install.log; then
		PLATFORM="D8"
	elif cat $FILE | grep "Trisquel GNU/Linux 7.0" >> /var/libre_install.log; then
		PLATFORM="T7"
	else 
		echo "ERROR: UNKNOWN PLATFORM" | tee -a /var/libre_install.log
		exit
	fi
	echo "Platform: $PLATFORM" | tee -a /var/libre_install.log
}


# ----------------------------------------------
# check_internet
# ----------------------------------------------
check_internet() 
{
	# Removing firewall
	iptables -F
	iptables -t nat -F
	iptables -t mangle -F
	
	echo "Checking Internet access ..." | tee -a /var/libre_install.log
	if ! ping -c1 8.8.8.8 >> /var/libre_install.log; then
		echo "You need internet to proceed. Exiting" | tee -a /var/libre_install.log
		exit 1
	fi
	
	echo "Checking DNS resolution ..." | tee -a /var/libre_install.log
	if ! getent hosts github.com >> /var/libre_install.log; then
                echo "You need DNS resolution to proceed... Exiting" | tee -a /var/libre_install.log
                exit 1
	fi
	
        echo "Showing the interface configuration ..." | tee -a /var/libre_install.log
	CLINKUP=$(ip link |grep UP |grep eth | cut -d: -f2 |sed -n 1p)
        CWANIP=$(wget -qO- ipinfo.io/ip)
        CLANIP=$(ifconfig $CLINKUP | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
        CNETMASK=$(ifconfig $CLINKUP | grep 'Mask:' | cut -d: -f4 | awk '{ print $1}')
        CGWIP=$(route -n | grep 'UG[ \t]' | awk '{print $2}')
        CDNS=$(cat /etc/resolv.conf | cut -d: -f2 | awk '{ print $2}')
        echo 'Wired interface:' $CLINKUP
        echo 'Public IP:' $CWANIP
        echo 'LAN IP:' $CLANIP
        echo 'Netmask:' $CNETMASK
        echo 'Gateway:' $CGWIP
        echo 'DNS Servers:' $CDNS
}


# ----------------------------------------------
# check_root
# ----------------------------------------------
check_root()
{
	echo "Checking user root ..." | tee -a /var/libre_install.log
	if [ "$(whoami)" != "root" ]; then
		echo "You need to be root to proceed. Exiting" | tee -a /var/libre_install.log
		exit 2
	fi
}


# ----------------------------------------------
# configure_repositories
# ----------------------------------------------
configure_repositories() 
{
	# Configuring main repositories before any installation
        cat << EOF >  /etc/apt/sources.list
deb http://ftp.debian.org/debian jessie main 
deb http://ftp.debian.org/debian jessie-updates main 
deb http://security.debian.org jessie/updates main 
deb http://ftp.debian.org/debian jessie-backports main 
deb-src http://ftp.debian.org/debian jessie main 
deb-src http://ftp.debian.org/debian jessie-updates main 
deb-src http://security.debian.org jessie/updates main 
deb-src http://ftp.debian.org/debian jessie-backports main 
EOF

	echo "Time sync ..." | tee -a /var/libre_install.log
	
	# Installing ntpdate package
	apt-get update >> /var/libre_install.log
	apt-get -y --force-yes install ntp ntpdate >> /var/libre_install.log
	
	# Time synchronization
	/etc/init.d/ntp stop >> /var/libre_install.log 2>> /var/libre_install.log
        if ntpdate -u ntp.ubuntu.com; then
            echo "Date and time have been set" | tee -a /var/libre_install.log
        elif ntpdate -u 0.ubuntu.pool.ntp.org; then
            echo "Date and time have been set" | tee -a /var/libre_install.log
        elif ntpdate -u 1.ubuntu.pool.ntp.org; then
            echo "Date and time have been set" | tee -a /var/libre_install.log
        elif ntpdate -u 2.ubuntu.pool.ntp.org; then
            echo "Date and time have been set" | tee -a /var/libre_install.log
        elif ntpdate -u 3.ubuntu.pool.ntp.org; then
            echo "Date and time have been set" | tee -a /var/libre_install.log
        elif [ $? -ne 0 ]; then
            echo "Error: unable to set time" | tee -a /var/libre_install.log
            exit 3
        fi
	/etc/init.d/ntp restart >> /var/libre_install.log 2>> /var/libre_install.log
	date | tee -a /var/libre_install.log
	
	# Configuring hostname and domain name
	echo "librerouter" > /etc/hostname
	echo "127.0.0.1 localhost.librenet librerouter localhost" > /etc/hosts
	sysctl kernel.hostname=librerouter
	
	echo "Configuring repositories ... " | tee -a /var/libre_install.log

	# echo "adding unauthenticated upgrade"
	apt-get  -y --force-yes --allow-unauthenticated upgrade

	echo "
Acquire::https::dl.dropboxusercontent.com::Verify-Peer \"false\";
Acquire::https::deb.nodesource.com::Verify-Peer \"false\";
        " > /etc/apt/apt.conf.d/apt.conf 


	if [ $PLATFORM = "D8" ]; then
		# Avoid macchanger asking for information
		export DEBIAN_FRONTEND=noninteractive

		# Configuring Repositories for Debian 8
		#echo "deb http://ftp.es.debian.org/debian/ jessie main" > /etc/apt/sources.list
		#echo "deb http://ftp.es.debian.org/debian/ jessie-updates main" >> /etc/apt/sources.list
		#echo "deb http://security.debian.org/ jessie/updates main" >> /etc/apt/sources.list
		cat << EOF >  /etc/apt/sources.list
deb http://ftp.debian.org/debian jessie main 
deb http://ftp.debian.org/debian jessie-updates main 
deb http://security.debian.org jessie/updates main
deb http://ftp.debian.org/debian jessie-backports main 
deb-src http://ftp.debian.org/debian jessie main
deb-src http://ftp.debian.org/debian jessie-updates main 
deb-src http://security.debian.org jessie/updates main
deb-src http://ftp.debian.org/debian jessie-backports main 
EOF

		# There is a need to install apt-transport-https 
		# package before preparing third party repositories
		echo "Updating repositories ..." | tee -a /var/libre_install.log
       		apt-get update 2>&1 > /var/apt-get-update-default.log
 		echo "Installing apt-transport-https ..." | tee -a /var/libre_install.log
		apt-get install -y --force-yes apt-transport-https 2>&1 > /var/apt-get-install-aptth.log
		if [ $? -ne 0 ]; then
			echo "Error: Unable to install apt-transport-https" | tee -a /var/libre_install.log
			exit 3
		fi

		# Prepare owncloud repo
		echo 'deb http://download.opensuse.org/repositories/isv:/ownCloud:/community/Debian_8.0/ /' > /etc/apt/sources.list.d/owncloud.list
		wget http://download.opensuse.org/repositories/isv:/ownCloud:/community/Debian_8.0/Release.key -O- | apt-key add -
		
		# Prepare Sogo repo
                apt-key adv --keyserver keys.gnupg.net --recv-key 0x810273C4
                echo 'deb http://packages.inverse.ca/SOGo/nightly/3/debian/ jessie jessie' > /etc/apt/sources.list.d/sogo.list
		
		# Prepare prosody repo
#		echo 'deb http://packages.prosody.im/debian wheezy main' > /etc/apt/sources.list.d/prosody.list
#		wget https://prosody.im/files/prosody-debian-packages.key -O- | apt-key add -
 
		# Prepare tahoe repo
		# echo 'deb https://dl.dropboxusercontent.com/u/18621288/debian wheezy main' > /etc/apt/sources.list.d/tahoei2p.list

		# Prepare yacy repo
		echo 'deb http://debian.yacy.net ./' > /etc/apt/sources.list.d/yacy.list
		apt-key advanced --keyserver pgp.net.nz --recv-keys 03D886E7

		# Prepare i2p repo
		echo 'deb https://deb.i2p2.de/ stable main' > /etc/apt/sources.list.d/i2p.list
		wget --no-check-certificate https://geti2p.net/_static/i2p-debian-repo.key.asc -O- | apt-key add -

		# Prepare tor repo
		echo 'deb http://deb.torproject.org/torproject.org jessie main'  > /etc/apt/sources.list.d/tor.list
		gpg --keyserver pgp.net.nz --recv 886DDD89
		gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | apt-key add -
		
		# Prepare Webmin repo
		echo 'deb http://download.webmin.com/download/repository sarge contrib' > /etc/apt/sources.list.d/webmin.list
		if [ -e jcameron-key.asc ]; then
			rm -r jcameron-key.asc
		fi
		wget http://www.webmin.com/jcameron-key.asc
		apt-key add jcameron-key.asc 

		# Prepare kibaba repo
		wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | apt-key add -
		echo "deb https://packages.elastic.co/kibana/4.6/debian stable main" > /etc/apt/sources.list.d/kibana.list

		# Prepare lohstash repo
		wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | apt-key add -
		echo "deb https://packages.elastic.co/logstash/2.4/debian stable main" > /etc/apt/sources.list.d/elastic.list

	
		# Prepare backports repo (suricata, roundcube)
#		echo 'deb http://ftp.debian.org/debian jessie-backports main' > /etc/apt/sources.list.d/backports.list

		# Prepare bro repo
#		wget http://download.opensuse.org/repositories/network:bro/Debian_8.0/Release.key -O- | apt-key add -
#		echo 'deb http://download.opensuse.org/repositories/network:/bro/Debian_8.0/ /' > /etc/apt/sources.list.d/bro.list

		# Prepare elastic repo
#		wget https://packages.elastic.co/GPG-KEY-elasticsearch -O- | apt-key add -
#		echo "deb http://packages.elastic.co/kibana/4.5/debian stable main" > /etc/apt/sources.list.d/kibana.list
#		echo "deb https://packages.elastic.co/logstash/2.3/debian stable main" > /etc/apt/sources.list.d/logstash.list
#		echo "deb https://packages.elastic.co/elasticsearch/2.x/debian stable main" > /etc/apt/sources.list.d/elastic.list

		# Prepare passenger repo
#		apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7
#		echo "deb https://oss-binaries.phusionpassenger.com/apt/passenger jessie main" > /etc/apt/sources.list.d/passenger.list

# Preparing repositories for Trisquel GNU/Linux 7.0

	else 
		echo "ERROR: UNKNOWN PLATFORM" 
		exit 4
	fi
}


# ----------------------------------------------
# Function to configure WLAN AP
# ----------------------------------------------
install_apmode()
{
echo "Preparing wlan AP script ..."

mkdir -p /root/libre_scripts/
rm -rf /root/libre_scripts/apmode.sh

echo "Downloading apmode script ..."
wget --no-check-certificate https://raw.githubusercontent.com/Librerouter/Librekernel/gh-pages/apmode.sh
if [ $? -ne 0 ]; then
	echo "Unable to download apmode script. Exiting ..."
	exit 1
fi

# Moving script to permanent location
mv apmode.sh /root/libre_scripts/
chmod +x /root/libre_scripts/apmode.sh
}


# ----------------------------------------------
# install_packages
# ----------------------------------------------
install_packages() 
{
	echo "Updating repositories packages ... " | tee -a /var/libre_install.log
	apt-get update 2>&1 > /var/apt-get-update.log
	echo "Installing packages ... " | tee -a /var/libre_install.log

if [ $PLATFORM = "D8" ]; then
	DEBIAN_FRONTEND=noninteractive
 	
	# libs and tools
	apt-get install -y --force-yes \
        php5-common php5-fpm php5-cli php5-json php5-mysql \
        php5-curl php5-intl php5-mcrypt php5-memcache \
        php-xml-parser php-pear phpmyadmin php5 mailutils \
        apache2 libapache2-mod-php5 libapache2-modsecurity \
        libapache2-mod-fcgid libapache2-mod-passenger \
        openjdk-7-jre-headless \
        php5-gd php5-imap smarty3 git ntpdate macchanger \
        bridge-utils hostapd librrd-dev \
        curl macchanger ntpdate bc sudo lsb-release dnsutils \
        ca-certificates-java openssh-server ssh wireless-tools usbutils \
        unzip debian-keyring subversion build-essential libncurses5-dev \
        i2p-keyring virtualenv pwgen gcc g++ make automake \
        killyourtv-keyring libcurl4-gnutls-dev \
        libicapapi-dev libssl-dev perl screen aptitude \
        deb.torproject.org-keyring u-boot-tools php-zeta-console-tools \
        gnupg openssl python-virtualenv python-pip python-lxml git \
        libjpeg62-turbo libjpeg62-turbo-dev zlib1g-dev python-dev \
        libxml2-dev libxslt1-dev python-jinja2 python-pgpdump spambayes \
        flex bison libpcap-dev libnet1-dev libpcre3-dev iptables-dev \
        libnetfilter-queue-dev libdumbnet-dev autoconf rails \
        roundcube-mysql roundcube-plugins ntop libndpi-bin \
        argus-server argus-client libnids-dev flow-tools libfixbuf3 \
        libgd-perl libgd-graph-perl rrdtool librrd-dev librrds-perl \
        libsqlite3-dev libtool elasticsearch conky ruby bundler \
        pmacct tomcat7 dpkg-dev devscripts javahelper openjdk-7-jdk ant \
        librrds-perl libapache2-mod-php5- apache2-prefork-dev \
        libmysqlclient-dev wkhtmltopdf libpcre3 mysql-server \
	mysql-client-5.5 iw rfkill \
        libfile-tail-perl libfile-pid-perl libwww-perl \
        dialog wpasupplicant \
        2>&1 | tee -a /var/libre_install.log

	# services
	apt-get install -y --force-yes \
        privoxy unbound owncloud isc-dhcp-server \
        yacy c-icap clamav clamav-daemon  squidguard \
	tor i2p roundcube tinyproxy prosody \
        memcached sogo webmin mat \
        dovecot-mysql dovecot-imapd postgrey \
        amavis spamassassin php5-imap fail2ban libsystemd-dev \
        2>&1 | tee -a /var/libre_install.log

fi
	if [ $? -ne 0 ]; then
		echo "Error: unable to install packages" | tee -a /var/libre_install.log
		exit 3
	fi

# Getting classified domains list from shallalist.de
if [ ! -e /opt/shallalist.tar.gz ]; then
	echo "Getting classified domains list ..." | tee -a /var/libre_install.log
	wget -P /opt/ http://www.shallalist.de/Downloads/shallalist.tar.gz
	if [ $? -ne 0 ]; then
       		echo "Error: Unable to download domain list. Exithing" | tee -a /var/libre_install.log
       		exit 5
	fi
fi

# Getting Friendica 
echo "Getting Friendica ..." | tee -a /var/libre_install.log
if [ ! -e  /var/www/friendica ]; then
	cd /var/www
	git clone https://github.com/friendica/friendica.git
	if [ $? -ne 0 ]; then
		echo "Error: unable to download friendica" | tee -a /var/libre_install.log
		exit 3
	fi
	cd friendica
	git clone https://github.com/friendica/friendica-addons.git addon
	if [ $? -ne 0 ]; then
		echo "Error: unable to download friendica addons" | tee -a /var/libre_install.log
		exit 3
	fi

	chown -R www-data:www-data /var/www/friendica/view/smarty3
	chmod g+w /var/www/friendica/view/smarty3
	touch /var/www/friendica/.htconfig.php
	chown www-data:www-data /var/www/friendica/.htconfig.php
	chmod g+rwx /var/www/friendica/.htconfig.php
fi

# Getting DNSCrypt
if [ ! -e dnscrypt-proxy ]; then
        echo "Download dnscrypt from https://github-cloud.s3.amazonaws.com" | tee -a /var/libre_install.log
        curl https://codeload.github.com/jedisct1/libsodium/tar.gz/1.0.12 > libsodium-1.0.12.tar.gz
        # curl "https://github-cloud.s3.amazonaws.com/releases/7710647/84828ba8-07cf-11e7-815a-bd618ee0f1c2.gz?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAISTNZFOVBIJMK3TQ%2F20170321%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20170321T140522Z&X-Amz-Expires=300&X-Amz-Signature=78c8f5607a6ad3b6d53e85a19d9519e61ab7c011757939e785a005355c1c949f&X-Amz-SignedHeaders=host&actor_id=24979456&response-content-disposition=attachment%3B%20filename%3Dlibsodium-1.0.12.tar.gz&response-content-type=application%2Foctet-stream" > libsodium-1.0.12.tar.gz
        tar xzf libsodium-1.0.12.tar.gz
        cd libsodium-1.0.12
        ./autogen.sh
        ./configure && make
        make install
        ldconfig
        if [ $? -ne 0 ]; then
                echo "Error: Unable to install libsodium. Exiting" | tee -a /var/libre_install.log
        fi
        echo "Getting & Installing DNSCrypt ..."
        git clone https://github.com/jedisct1/dnscrypt-proxy.git dnscrypt-proxy
        cd dnscrypt-proxy
        ./autogen.sh
        ./configure --with-systemd && make
        make install
        cd .. && rm -rf dnscrypt-proxy
        if [ $? -ne 0 ]; then
                echo "Error: Unable to download DNSCrypt. Exiting" | tee -a /var/libre_install.log
                exit 5
        fi
fi
}


# ----------------------------------------------
# This function checks hardware 
# Hardware can be.
# 1. ARM for odroid board.
# 2. INTEL or AMD for Physical/Virtual machine.
# Function gets Processor and Hardware types and saves
# them in PROCESSOR and HARDWARE variables.
# ----------------------------------------------
get_hardware()
{
        echo "Detecting hardware ..." | tee -a /var/libre_install.log
      
        # Checking CPU for ARM and saving
	# Processor and Hardware types in
	# PROCESSOR and HARDWARE variables
	if grep ARM /proc/cpuinfo >> /var/libre_install.log 2>>/var/libre_install.log; then    
           PROCESSOR="ARM"	                           
           HARDWARE=`cat /proc/cpuinfo | grep Hardware | awk {'print $3'}`   
        # Checking CPU for Intel and saving
	# Processor and Hardware types in
	# PROCESSOR and HARDWARE variables
	elif grep Intel /proc/cpuinfo >> /var/libre_install.log 2>>/var/libre_install.log;  then 
           PROCESSOR="Intel"	                             
           HARDWARE=`dmidecode -s system-product-name`       
        # Checking CPU for AMD and saving
	# Processor and Hardware types in
	# PROCESSOR and HARDWARE variables
	elif grep AMD /proc/cpuinfo >> /var/libre_install.log 2>>/var/libre_install.log;  then 
           PROCESSOR="AMD"	                             
           HARDWARE=`dmidecode -s system-product-name`       
	fi
	
	# Detecting Architecture
 	ARCH=`uname -m`

        # Printing Processor Hardware and Architecture types     

	echo "Processor: $PROCESSOR" | tee -a /var/libre_install.log
        echo "Hardware: $HARDWARE" | tee -a /var/libre_install.log
	echo "Architecture: $ARCH" | tee -a /var/libre_install.log

}


# ----------------------------------------------
# This script checks requirements for Physical 
# Machines.
# 
#  Minimum requirements are:
#
#  * 2 Network Interfaces.
#  * 4 GB Physical Memory (RAM).
#  * 16 GB Free Space On Hard Drive.
#
# ----------------------------------------------
check_requirements()
{
	echo "Checking requirements ..." | tee -a /var/libre_install.log

        # This variable contains network interfaces quantity.  
	# NET_INTERFACES=`ls /sys/class/net/ | grep -w 'eth0\|eth1\|wlan0\|wlan1' | wc -l`

        # This variable contains total physical memory size.
	echo -n "Physical memory size: " | tee -a /var/libre_install.log
        MEMORY=`grep MemTotal /proc/meminfo | awk '{print $2}'`
	echo "$MEMORY KB"	| tee -a /var/libre_install.log

	# This variable contains total free space on root partition.
	echo -n "Root partition size: " | tee -a /var/libre_install.log
	STORAGE=`df / | grep -w "/" | awk '{print $4}'`
	echo "$STORAGE KB" 	| tee -a /var/libre_install.log
       
        # Checking network interfaces quantity.
	# if [ $NET_INTERFACES -le 1 ]; then
        #	echo "You need at least 2 network interfaces. Exiting"
        #	exit 4 
        # fi
	
	# Checking physical memory size.
        if [ $MEMORY -le 1900000 ]; then 
		echo "You need at least 2GB of RAM. Exiting" | tee -a /var/libre_install.log
                exit 5
        fi

	# Checking free space. 
	MIN_STORAGE=12000000
	STORAGE2=`echo $STORAGE | awk -F. {'print $1'}`
	if [ $STORAGE2 -lt $MIN_STORAGE ]; then
		echo "You need at least 16GB of free space. Exiting" | tee -a /var/libre_install.log
		exit 6
	fi
	
	# Checking architecture.
        if [ "$ARCH" != "x86_64" ]; then
                echo "You need amd64 architecture to continue. Exiting" | tee -a /var/libre_install.log
                exit 7
        fi
}


# ----------------------------------------------
# This function enables DHCP client and checks 
# for Internet on predefined network interface.
#
# Steps to define interface are:
#
# 1. Checking Internet access. 
# *
# *
# ***** If success. 
# *
# *     2. Get Interface name 
# *
# ***** If no success. 
#     *
#     * 2. Checking for DHCP server and Internet in  
#       *  network connected to eth0.
#       *
#       ***** If success.
#       *   *
#       *   * 2. Enable DHCP client on eth0 and   
#       *        default route to eth0
#       *
#       ***** If no success. 
#           * 
#           * 2. Checking for DHCP server and Internet 
#           *  in network connected to eth1
#           *
#           ***** If success.
#           *   * 
#           *   * 3. Enable DHCP client on eth1.
#           *
#           *
#           ***** If no success.
#               *
#               * 3. Warn user and exit with error.
#
# ----------------------------------------------
get_interfaces()
{
	# Check internet Connection. If Connection exist then get 
	# and save Internet side network interface name in 
	# EXT_INTERFACE variable
	if ping -c1 8.8.8.8 >> /var/libre_install.log 2>>/var/libre_install.log; then
		EXT_INTERFACE=`route -n | awk {'print $1 " " $8'} | grep "0.0.0.0" | awk {'print $2'} | sed -n '1p'`
		echo "Internet connection established on interface $EXT_INTERFACE" | tee -a /var/libre_install.log
	else
		# Test all available ethernet interfaces for internet connection.
		# Useful if there are more than two ethernet interfaces.

		for i in `ifconfig -s | awk '{print $1}' | grep eth`
		do 
			iface="$i"
			echo "Getting Internet access on eth0"
			echo "# interfaces(5) file used by ifup(8) and ifdown(8) " > /etc/network/interfaces
			echo -e "auto lo\niface lo inet loopback\n" >> /etc/network/interfaces
			echo -e  "auto $iface\niface $iface inet dhcp" >> /etc/network/interfaces
			/etc/init.d/networking restart 
			if ping -c1 8.8.8.8 >> /var/libre_install.log 2>>/var/libre_install.log; then
				echo "Internet conection established on: $iface"	
				EXT_INTERFACE="$iface"
				break
			fi
		done
			if [ ! -z $EXT_INTERFACE ]; then
				echo "Warning: Unable to get Internet access on available interfaces"
				echo "Please plugin Internet cable and enable DHCP on gateway"
				echo "Error: Unable to get Internet access. Exiting" | tee -a /var/libre_install.log
				exit 7
			fi
		
	fi


	# Getting internal interface name
	
                # Getting internal interface name        
		# First of all will create a temporall bridge with eth1+wlan1 called br1        
		# The INT_INTERFACE now is br1    
		apt-get install -y --force-yes bridge-utils
		brctl addbr br1
		brctl addif br1 eth1
		brctl addif br1 wlan1        
		INT_INTERFACE="br1"
		# INT_INTERFACE=`ls /sys/class/net/ | grep -w 'eth0\|eth1\|wlan0\|wlan1' | grep -v "$EXT_INTERFACE" | sed -n '1p'`
		echo "Internal interface: $INT_INTERFACE" | tee -a /var/libre_install.log        
		brctl show | tee -a /var/libre_install.log
}


# ----------------------------------------------
# This scripts check odroid board to find out if
# it assembled or not.
# There are list of additional modules that need
# to be connected to board.
# Additional modules are.
# 	1. ssd 8gbc10
#	2. HDD 2TB
#	3. 2xWlan interfaces
#	4. TFT screen
# ----------------------------------------------
check_assemblance()
{
	echo "Checking assemblance ..." | tee -a /var/libre_install.log
	
	echo "Checking network interfaces ..."  
	# Script should detect 4 network 
	# interfaces.
	# 1. eth0
	# 2. eth1
	# 3. wlan0
	# 4. wlan1
	if   ! ls /sys/class/net/ | grep -w 'eth0'; then
		echo "Error: Interface eth0 is not connected. Exiting"
		exit 8
	elif ! ls /sys/class/net/ | grep -w 'eth1'; then
		echo "Error: Interface eth1 is not connected. Exiting"
		exit 9
	elif ! ls /sys/class/net/ | grep -w 'wlan0'; then
		echo "Error: Interface wlan0 is not connected. Exiting"
		exit 10
	elif ! ls /sys/class/net/ | grep -w 'wlan1'; then
		echo "Error: Interface wlan1 is not connected. Exiting"
		exit 11  
	fi
	echo "Network interfaces checking finished. OK" | tee -a /var/libre_install.log

	echo ""


}


# ----------------------------------------------
# Function to install libressl
# ----------------------------------------------
install_libressl()
{
        echo "Installing libressl ..." | tee -a /var/libre_install.log

        if [ ! -e libressl-2.4.2 ]; then
        echo "Downloading libressl ..." | tee -a /var/libre_install.log
        cd $INSTALL_HOME
        wget http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-2.4.2.tar.gz
                if [ $? -ne 0 ]; then
                        echo "Error: unable to download libressl" | tee -a /var/libre_install.log
                        exit 3
                fi
        tar -xzf libressl-2.4.2.tar.gz
        fi

        echo "Building libressl ..." | tee -a /var/libre_install.log
        cd $INSTALL_HOME

        cd libressl-2.4.2/
        ./configure
        make &&  make install 

        if [ $? -ne 0 ]; then
                echo "Error: unable to install libressl. Exiting ..." | tee -a /var/libre_install.log
                exit 3
        fi
        cd ../

        # Cleanup
        rm -rf libressl-2.4.2.tar.gz
}


# ----------------------------------------------
# Function to install modsecurity
# ----------------------------------------------
install_modsecurity()
{
        echo "Installing modsecurity OWASP Core Rule Set..." | tee -a /var/libre_install.log

        # Downloading the OWASP Core Rule Set
        cd /usr/src/
        rm -rf owasp-modsecurity-crs
        git clone https://github.com/SpiderLabs/owasp-modsecurity-crs.git
        if [ $? -ne 0 ]; then
                echo "Error: unable to download modsecurity rules. Exiting ..." | tee -a /var/libre_install.log
                exit 3
        fi

        cd $INSTALL_HOME
}


# ---------------------------------------------------------
# Function to install WAF-FLE (Modsecurity GUI)
# ---------------------------------------------------------
install_waffle() 
{
        echo "Installing WAF-FLE ..." | tee -a /var/libre_install.log

	# installing dependencies
        apt-get install -y --force-yes php5-geoip php-apc


        rm -rf /usr/local/waf-fle
        mkdir -p /usr/local/waf-fle/


        if [ ! -e waf-fle ]; then
                echo "Downloading waf-fle ..." | tee -a /var/libre_install.log
                git clone https://github.com/klaubert/waf-fle/
                if [ $? -ne 0 ]; then
                        echo "Unable to download waf-fle. Exiting ..." | tee -a /var/libre_install.log
                        exit 3
                fi 
        fi
      
        # Decompressing package
        cp -r waf-fle/ /usr/local/

        # Download MaxMind GeoIP Database
	
        mkdir /usr/share/GeoIP/
        cd /usr/share/GeoIP/
        rm -r /usr/share/GeoIP/*

        if [ ! -e GeoIP.dat.gz ]; then
                echo "Downloading GeoIP.dat ..." | tee -a /var/libre_install.log
                wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz
                if [ $? -ne 0 ]; then
                        echo "Unable to download GeoIP.dat. Exiting ..." | tee -a /var/libre_install.log
                        exit 3
                fi
        fi

        if [ ! -e GeoLiteCity.dat.gz ]; then
                echo "Downloading GeoLiteCity.dat ..." | tee -a /var/libre_install.log
                wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz
                if [ $? -ne 0 ]; then
                        echo "Unable to download GeoLiteCity.dat. Exiting ..." | tee -a /var/libre_install.log
                        exit 3
                fi
        fi

        if [ ! -e GeoIPASNum.dat.gz ]; then
                echo "Downloading GeoIPASNum.dat ..." | tee -a /var/libre_install.log
                wget http://geolite.maxmind.com/download/geoip/database/asnum/GeoIPASNum.dat.gz
                if [ $? -ne 0 ]; then
                        echo "Unable to download GeoIPASNum.dat. Exiting ..." | tee -a /var/libre_install.log
                        exit 3
                fi
        fi

        # Decompressing packages
        gzip -d GeoIP.dat.gz
        gzip -d GeoLiteCity.dat.gz
        gzip -d GeoIPASNum.dat.gz

        mv GeoLiteCity.dat GeoIPCity.dat
        # To make php GeoIP extension work with ASNum database
        cp GeoIPASNum.dat GeoIPISP.dat
}


# -----------------------------------------------
# Function to install ssl certificates
# -----------------------------------------------
install_certificates()
{
        echo "Installing certificates ..." | tee -a /var/libre_install.log
        if [ ! -e certs ]; then
                echo "Downloading certificates ..." | tee -a /var/libre_install.log
                svn co https://github.com/Librerouter/Librekernel/trunk/certs
                if [ $? -ne 0 ]; then
                        echo "Error: unable to download certificates. Exiting ..." | tee -a /var/libre_install.log
                        exit 3
                fi
        fi

        # Moving certificates to nginx directory
        rm -rf /etc/ssl/apache/*
	mkdir -p /etc/ssl/apache/
        cp -r certs/* /etc/ssl/apache/

        # Cleanup
        # rm -rf certs
}


# -----------------------------------------------
# Function to install ModSecurity Rules
# -----------------------------------------------
install_modsecrules()
{
        echo "Installing ModSecurity Rules ..." | tee -a /var/libre_install.log
        if [ ! -e ModSecurityRules ]; then
                echo "Downloading ModSecurity Rules ..." | tee -a /var/libre_install.log
                svn co https://github.com/Librerouter/Librekernel/trunk/ModSecurityRules  
                if [ $? -ne 0 ]; then
                        echo "Error: unable to download ModSecurity Rules. Exiting ..." | tee -a /var/libre_install.log
                        exit 3
                fi
        fi

        # Moving ModSecurity Rules to nginx /usr/src/ModSecurityRules directory
        mkdir -p /usr/src/ModSecurityRules
        rm -rf /usr/src/ModSecurityRules/*
        cp -r ModSecurityRules/* /usr/src/ModSecurityRules/

        # Cleanup
        # rm -rf /usr/src/ModSecurityRules/
}


# ----------------------------------------------
# Function to install mailpile package
# ----------------------------------------------
install_mailpile() 
{
	echo "Installing Mailpile ..." | tee -a /var/libre_install.log
        apt-get install -y --force-yes libffi-dev
 	if [ ! -e /opt/Mailpile ]; then
                echo "Downloading mailpile ..." | tee -a /var/libre_install.log
        	git clone --recursive \
		https://github.com/mailpile/Mailpile.git /opt/Mailpile
                if [ $? -ne 0 ]; then
                        echo "Error: unable to download Mailpile. Exiting ..." | tee -a /var/libre_install.log
                        exit 3
                fi

	fi
	virtualenv -p /usr/bin/python2.7 --system-site-packages /opt/Mailpile/mailpile-env
	source /opt/Mailpile/mailpile-env/bin/activate
	
	pip install packaging
        pip install appdirs
        pip install --upgrade six

	pip install -r /opt/Mailpile/requirements.txt
	if [ $? -ne 0 ]; then
		echo "Error: unable to install Mailpile. Exiting ..." | tee -a /var/libre_install.log
		exit 3
	fi
}


# ----------------------------------------------
# Function to install EasyRTC package
# ----------------------------------------------
install_easyrtc() 
{
	echo "Installing EasyRTC package ..." | tee -a /var/libre_install.log

	# Creating home folder for EasyRTC
	if [ -e /opt/easyrtc ]; then
		rm -r /opt/easyrtc
	fi
	
	# Installing Node.js. Includes npm, then npm have been rmeoved from top apt-get
        echo "Install Nodejs/npm from sources" | tee -a /var/libre_install.log
        wget -O - https://nodejs.org/dist/v7.7.4/node-v7.7.4.tar.gz > node-v7.7.4.tar.gz
        tar xzf node-v7.7.4.tar.gz
        cd node-v7.7.4
        ./configure
        make && make install

	# Getting EasyRTC 
	if [ ! -e easyrtc ]; then
		echo "Downloading EasyRTC ..." | tee -a /var/libre_install.log
		git clone --recursive \
       		https://github.com/priologic/easyrtc 
	        if [ $? -ne 0 ]; then
                  echo "Error: Unable to download EasyRTC. Exiting ..." | tee -a /var/libre_install.log
                  exit 3
 	        fi
	fi
	
	# Moving server_example to /opt
	cp -r easyrtc /opt/
	
	# Downloading the required dependencies
	cd /opt/easyrtc
	npm install
	cd /opt/easyrtc/server_example/
	npm install
	if [ $? -ne 0 ]; then
		echo "Error: unable to install EasyRTC. Exiting" | tee -a /var/libre_install.log
		exit 3
	fi
	cd $INSTALL_HOME
}


# ---------------------------------------------------------
# Function to install hublin
# ---------------------------------------------------------
install_hublin()
{
        echo "installing hublin ..." | tee -a /var/libre_install.log

        # Install nvm
        curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.32.1/install.sh | bash

        source ~/.bashrc

        # Install node 0.10
        nvm install 0.10
        nvm use 0.10

        if [ ! -e meetings ]; then
                echo "Downloading hublin ..." | tee -a /var/libre_install.log
                git clone --recursive https://ci.open-paas.org/stash/scm/meet/meetings.gi
                if [ $? -ne 0 ]; then
                        echo "Error: unable to download hublin. Exiting ..." | tee -a /var/libre_install.log
                        exit 3
                fi

        fi

        # Installing mongodb
        echo 'deb http://downloads-distro.mongodb.org/repo/debian-sysvinit dist 10gen' > /etc/apt/sources.list.d/mongodb.list
        apt-get install -y --force-yes mongodb-org=2.6.5 mongodb-org-server=2.6.5 mongodb-org-shell=2.6.5 mongodb-org-mongos=2.6.5 mongodb-org-tools=2.6.5
    service mongod start

        # Installing radis-server
        apt-get -y --force-yes  install redis-server

        # Installing hublin dependencies
        npm install -g mocha grunt-cli bower karma-cli

        cd meetings/modules/hublin-easyrtc-connector
        npm install

        cd ../../
        npm install
        if [ $? -ne 0 ]; then
               echo "Error: unable to install hublin. Exiting ..." | tee -a /var/libre_install.log
               exit 3
        fi

        cd ../
}


# -----------------------------------------------
# Function to install owncloud 
# -----------------------------------------------            
install_owncloud()
{
	echo "Installing owncloud ..." | tee -a /var/libre_install.log
	
	# Deleting previous packages
	rm -rf /var/www/owncloud
	
	if [ ! -e  owncloud-9.1.1.tar.bz2 ]; then
		echo "Downloading owncloud ..." | tee -a /var/libre_install.log
		wget https://download.owncloud.org/community/owncloud-9.1.1.tar.bz2
                if [ $? -ne 0 ]; then
	                echo "Error: Unable to download owncloud. Exiting ..." | tee -a /var/libre_install.log
       		        exit 3
                fi
		
	fi

	tar xf owncloud-9.1.1.tar.bz2
	mv owncloud /var/www/owncloud

	# Installing ojsxc xmpp client
	if [ ! -e ojsxc-3.0.1.zip ]; then
		echo "Downlouding ojsxc ..." | tee -a /var/libre_install.log
		wget https://github.com/owncloud/jsxc.chat/releases/download/v3.0.1/ojsxc-3.0.1.zip
		if [ $? -ne 0 ]; then 
                        echo "Error: Unable to download ojsxc. Exiting ..." | tee -a /var/libre_install.log
                        exit 3
                fi
	fi

	unzip ojsxc-3.0.1.zip
	mv ojsxc /var/www/owncloud/apps

	chown -R www-data /var/www/owncloud
}


# -----------------------------------------------
# Function to install libecap 
# -----------------------------------------------
install_libecap()
{
        echo "Installing libecap ..." | tee -a /var/libre_install.log

        if [ ! -e libecap-1.0.0 ]; then
        echo "Downloading libecap ..." | tee -a /var/libre_install.log
        wget http://www.measurement-factory.com/tmp/ecap/libecap-1.0.0.tar.gz
                if [ $? -ne 0 ]; then
                        echo "Error: unable to download libecap" | tee -a /var/libre_install.log
                        exit 3
                fi
		tar xzf libecap-1.0.0.tar.gz
        fi

        echo "Building libecap ..." | tee -a /var/libre_install.log
        
	cd libecap-1.0.0/
	
	./configure 
	make &&  make install

        if [ $? -ne 0 ]; then
                echo "Error: unable to install libecap" | tee -a /var/libre_install.log
                exit 3
        fi
        cd ../

	# Cleanup
	rm -rf libecap-1.0.0.tar.gz
}


# -----------------------------------------------
# Function to install fg-ecap
# -----------------------------------------------
install_fg-ecap()
{
        echo "Installing fg-ecap ..." | tee -a /var/libre_install.log

        if [ ! -e fg_ecap ]; then
        echo "Downloading fg-ecap ..." | tee -a /var/libre_install.log
        git clone https://github.com/androda/fg_ecap $INSTALL_HOME/fg_ecap
                if [ $? -ne 0 ]; then
                        echo "Error: unable to download fg-ecap. Exitingi ..." | tee -a /var/libre_install.log
                        exit 3
                fi
        fi

        echo "Building fg-ecap ..." | tee -a /var/libre_install.log

        cd fg_ecap

	chmod +x autogen.sh
        ./autogen.sh
        ./configure 
        make && make install
        if [ $? -ne 0 ]; then
                echo "Error: unable to install fg-ecap" | tee -a /var/libre_install.log
                exit 3
        fi
        cd ../
}


# -----------------------------------------------
# Function to install squid
# -----------------------------------------------
install_squid()
{
	echo "Installing squid dependences ..." | tee -a /var/libre_install.log
	aptitude -y build-dep squid

	echo "Installing squid ..." | tee -a /var/libre_install.log
	if [ ! -e /tmp/squid-3.5.21.tar.gz ]; then
		echo "Downloading squid ..." | tee -a /var/libre_install.log
		wget -P /tmp/ http://www.squid-cache.org/Versions/v3/3.5/squid-3.5.21.tar.gz
	fi

	if [ ! -e squid-3.5.21 ]; then
		echo "Extracting squid ..." | tee -a /var/libre_install.log
		tar zxvf /tmp/squid-3.5.21.tar.gz
	fi

	echo "Building squid ..." | tee -a /var/libre_install.log
	cd squid-3.5.21
	./configure --prefix=/usr --localstatedir=/var \
		--libexecdir=/lib/squid --datadir=/usr/share/squid \
		--sysconfdir=/etc/squid --with-logdir=/var/log/squid \
		--with-pidfile=/var/run/squid.pid --enable-icap-client \
		--enable-linux-netfilter --enable-ssl-crtd --with-openssl \
		--enable-ltdl-convenience --enable-ssl \
		--enable-ecap PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
	make && make install
	if [ $? -ne 0 ]; then
		echo "Error: unable to install squid" | tee -a /var/libre_install.log
		exit 3
	fi
	cd ../

	# Getting squid startup script
	if [ ! -e /etc/squid/squid3.rc ]; then
		wget -P /etc/squid/ https://raw.githubusercontent.com/grosskur/squid3-deb/master/debian/squid3.rc
	fi

	# squid adservers
	curl -sS -L --compressed \
	"http://pgl.yoyo.org/adservers/serverlist.php?mimetype=plaintext" \
		> /etc/squid/squid.adservers

	# squid adzapper
	wget http://adzapper.sourceforge.net/scripts/squid_redirect
	chmod +x ./squid_redirect
	mv squid_redirect /usr/bin/
	
	# Adding library path
	echo "include /usr/local/lib" >> /etc/ld.so.conf 
	ldconfig
}


# ----------------------------------------------
# Function to install SquidClamav
# ----------------------------------------------
install_squidclamav()
{
	echo "Installing squidclamav ..." | tee -a /var/libre_install.log
	if [ ! -e /tmp/squidclamav-6.15.tar.gz ]; then
		echo "Downloading squidclamav ..." | tee -a /var/libre_install.log
		wget -P /tmp/ http://downloads.sourceforge.net/project/squidclamav/squidclamav/6.15/squidclamav-6.15.tar.gz
	fi

	if [ ! -e squidclamav-6.15 ]; then
		echo "Extracting squidclamav ..." | tee -a /var/libre_install.log
		tar zxvf /tmp/squidclamav-6.15.tar.gz
	fi

	echo "Building squidclamav ..." | tee -a /var/libre_install.log
	cd squidclamav-6.15
	./configure --with-c-icap
	make && make install
	if [ $? -ne 0 ]; then
		echo "Error: unable to install squidclamav" | tee -a /var/libre_install.log
		exit 3
	fi
	cd ../

	# Creating configuration file
	ln -sf /etc/c-icap/squidclamav.conf /etc/squidclamav.conf
}


# ----------------------------------------------
# Function to install squidguard blacklists
# ----------------------------------------------
install_squidguard_bl()
{
	echo "Installing squidguard blacklists ..." | tee -a /var/libre_install.log

#	# squidguard-adblock
#	echo "Downloading squidguard-adblock ..."
#	git clone https://github.com/jamesmacwhite/squidguard-adblock.git
#	if [ $? -ne 0 ]; then
#		echo "Error: unable to download squidguard-adblock"
#		exit 3
#	fi
#	cd squidguard-adblock
#	mkdir -p /etc/squid/squidguard-adblock
#	cp get-easylist.sh /etc/squid/squidguard-adblock/
#	cp patterns.sed /etc/squid/squidguard-adblock/
#	cp urls.txt /etc/squid/squidguard-adblock/
#	chmod +x /etc/squid/squidguard-adblock/get-easylist.sh
#	cd ..

	# Getting MESD blacklists
	if [ ! -e blacklists.tgz ]; then
	wget http://squidguard.mesd.k12.or.us/blacklists.tgz
	fi
	# Getting ads blacklists
        if [ ! -e serverlist.php ]; then
        wget https://pgl.yoyo.org/as/serverlist.php
	fi
	# Getting urlblacklist blacklists
	if [ ! -e urlblacklist ]; then
	wget http://urlblacklist.com/cgi-bin/commercialdownload.pl?type=download\\&file=bigblacklist -O urlblacklist.tar.gz
	rm -rf blacklistdomains
	mkdir blacklistdomains
	cd blacklistdomains
	tar xvzf urlblacklist.tar.gz
	cd ../
        fi
       
	# Making squidGuard blacklists directory
	mkdir -p /usr/local/squidGuard/db 
	# Extracting blacklists
        cp blacklists.tgz /usr/local/squidGuard/db
        tar xfv /usr/local/squidGuard/db/blacklists.tgz \
        -C /usr/local/squidGuard/db/
        # ads blacklists
        sed -n '57,2418p' < serverlist.php > /usr/local/squidGuard/db/blacklists/ads/domains
        # urlblacklist blacklists
        cat blacklistdomains/blacklists/ads/domains >> /usr/local/squidGuard/db/blacklists/ads/domains 
	# Shalalist domains
        cat BL/adv/domains >> /usr/local/squidGuard/db/blacklists/ads/domains
        cat BL/adv/urls >> /usr/local/squidGuard/db/blacklists/ads/urls
	# Cleanup
        rm -rf /usr/local/squidGuard/db/blacklists.tar
#	rm -rf squidguard-adblock
}


# ---------------------------------------------------------
# Function to install squidguardmgr (Manager Gui)
# ---------------------------------------------------------
install_squidguardmgr()
{
        echo "Installing squidguardmgr ..." | tee -a /var/libre_install.log
        if [ ! -e squidguardmgr ]; then
                echo "Downloading squidguardmgr ..." | tee -a /var/libre_install.log
                git clone https://github.com/darold/squidguardmgr
                if [ $? -ne 0 ]; then
                        echo "Error: unable to download quidguardmgr" | tee -a /var/libre_install.log
                        exit 3
                fi
        fi

        echo "Building quidguardmgr ..." | tee -a /var/libre_install.log
        cd squidguardmgr
        perl Makefile.PL \
        CONFFILE=/etc/squidguard/squidGuard.conf \
        SQUIDUSR=root SQUIDGRP=root \
        SQUIDCLAMAV=off \
        QUIET=1

        make
        make install
        cd ../

        chmod a+rw /etc/squidguard/squidGuard.conf
}


# ----------------------------------------------
# Function to install e2guardian
# ----------------------------------------------
install_e2guardian()
{
	echo "Installing e2guardian ..." | tee -a /var/libre_install.log

	if [ ! -e e2guardian ]; then
		echo "Downloading e2guardian ..." | tee -a /var/libre_install.log
		git clone https://github.com/e2guardian/e2guardian
		if [ $? -ne 0 ]; then
			echo "Error: unable to download e2guardian" | tee -a /var/libre_install.log
			exit 3
		fi
	fi

	echo "Building e2guardian ..." | tee -a /var/libre_install.log
	cd e2guardian

	# Adding ssl options
	echo "
	#define __SSLMITM
	#define __SSLCERT
	" > dgconfig.h
	sed  -i '/LIBS = -lz/c\LIBS = -lz -lcrypto -lssl' Makefile

	./autogen.sh
	./configure --prefix=/usr --enable-clamd=yes --enable-fancydm=no
	make && make install
	if [ $? -ne 0 ]; then
		echo "Error: unable to install e2guardian" | tee -a /var/libre_install.log
		exit 3
	fi
	cd ../

	# Cleanup
	rm -rf ./e2guardian
}


# ----------------------------------------------
# Function to install ecapguardian
# ----------------------------------------------
install_ecapguardian()
{
	echo "Installing ecapguardian ..." | tee -a /var/libre_install.log
        
        if [ ! -e ecapguardian ]; then
	echo "Downloading ecapguardian ..."
	git clone https://github.com/androda/ecapguardian
		if [ $? -ne 0 ]; then
			echo "Error: unable to download ecapguardian" | tee -a /var/libre_install.log
			exit 3
		fi
	fi

	echo "Building ecapguardian ..." | tee -a /var/libre_install.log

	cd ecapguardian

	# Adding category
	sed -i  "s/N\/A/Pornography/g" src/HTMLTemplate.cpp

	# Adding subdir for automake
        sed -i '/AM_INIT_AUTOMAKE/c\AM_INIT_AUTOMAKE([subdir-objects])' configure.ac

	./autogen.sh
	./configure '--prefix=/usr' '--enable-clamd=yes' '--with-proxyuser=e2guardian' '--with-proxygroup=e2guardian' '--sysconfdir=/etc' '--localstatedir=/var' '--enable-icap=yes' '--enable-commandline=yes' '--enable-email=yes' '--enable-ntlm=yes' '--enable-trickledm=yes' '--mandir=${prefix}/share/man' '--infodir=${prefix}/share/info' 'CXXFLAGS=-g -O2 -fstack-protector --param=ssp-buffer-size=4 -Wformat -Werror=format-security' 'LDFLAGS=-Wl,-z,relro' 'CPPFLAGS=-D_FORTIFY_SOURCE=2' 'CFLAGS=-g -O2 -fstack-protector --param=ssp-buffer-size=4 -Wformat -Werror=format-security' '--enable-pcre=yes' '--enable-locallists=yes' 
	make && make install
	if [ $? -ne 0 ]; then
		echo "Error: unable to install ecapguardian" | tee -a /var/libre_install.log
		exit 3
	fi
	cd ../

	# Cleanup
	# rm -rf ./ecapguardian
}


# ----------------------------------------------
# Function to install Suricata
# ----------------------------------------------
install_suricata()
{
        echo "Installing suricata ..." | tee -a /var/libre_install.log

        # Installing dependencies
        apt-get install -y --force-yes ethtool oinkmaster

        apt-get install -y -t jessie-backports ethtool suricata
        if [ $? -ne 0 ]; then
                echo "Error: unable to install suricata. Exiting ..." | tee -a /var/libre_install.log
                exit 3
        fi

        echo "Downloading rules ..." | tee -a /var/libre_install.log

        # Creating oinkmaster configuration
        echo "
skipfile local.rules
skipfile deleted.rules
skipfile snort.conf 
        " > /etc/oinkmaster.conf
        echo "url = https://rules.emergingthreats.net/open/suricata-3.1/emerging.rules.tar.gz" \
        >> /etc/oinkmaster.conf 
        oinkmaster -C /etc/oinkmaster.conf -o /etc/suricata/rules
        if [ $? -ne 0 ]; then
                echo "Error: unable to install suricata rules. Exiting ..." | tee -a /var/libre_install.log
                exit 3
        fi
}


# -----------------------------------------------
# Install kibana, elasticsearch and logstash
# -----------------------------------------------
install_kibana()
{
	echo "Installing kibana ..." | tee -a /var/libre_install.log
	apt-get install -y --force-yes kibana elasticsearch logstash >> /var/libre_install.log
	if [ $? -ne 0 ]; then
                echo "Error: unable to install kibaba. Exiting ..." | tee -a /var/libre_install.log
                exit 3
        fi

	# Enabling kibana daemon
	/bin/systemctl daemon-reload
	/bin/systemctl enable kibana.service

	# installing plugins
	/usr/share/elasticsearch/bin/plugin install license
	/usr/share/elasticsearch/bin/plugin install marvel-agent
	/opt/kibana/bin/kibana plugin --install elasticsearch/marvel/latest
}


# ----------------------------------------------
# Function to install scirius package
# ----------------------------------------------
install_scirius()
{
	echo "Installing scirius ..." | tee -a /var/libre_install.log

	echo "Downloading scirius ..." | tee -a /var/libre_install.log
	git clone https://github.com/StamusNetworks/scirius /opt/scirius
	if [ $? -ne 0 ]; then
		echo "Error: unable to download scirius" | tee -a /var/libre_install.log
		exit 3
	fi

	echo "Installing scirius ..." | tee -a /var/libre_install.log
	pip install -r /opt/scirius/requirements.txt && pip install pyinotify
	if [ $? -ne 0 ]; then
		echo "Error: unable to install scirius dependencies" | tee -a /var/libre_install.log
		exit 3
	fi
	python /opt/scirius/manage.py syncdb --noinput
	if [ $? -ne 0 ]; then
		echo "Error: unable to install scirius" | tee -a /var/libre_install.log
		exit 3
	fi
}


# ----------------------------------------------
# Function to install Snort
# ----------------------------------------------
install_snort()
{
	echo "Installing snort ..." | tee -a /var/libre_install.log

	# DAQ
	echo "Downloading daq ..." | tee -a /var/libre_install.log
	URL="https://www.snort.org/downloads/archive/snort"
	PKG="daq-2.0.6.tar.gz"
	wget -P /tmp/ $URL/$PKG
	tar xvf /tmp/$PKG
	rm -rf /tmp/$PKG

	echo "Building daq ..." | tee -a /var/libre_install.log
	cd daq-2.0.6
	./configure --prefix=/usr
	make && make install
	if [ $? -ne 0 ]; then
		echo "Error: unable to install daq" | tee -a /var/libre_install.log
		exit 3
	fi
	cd ../

	# Snort
	echo "Downloading snort ..." | tee -a /var/libre_install.log
	URL="https://www.snort.org/downloads/archive/snort"
	PKG="snort-2.9.8.3.tar.gz"
	wget -P /tmp/ $URL/$PKG
	tar xvf /tmp/$PKG
	rm -rf /tmp/$PKG

	echo "Building snort ..." | tee -a /var/libre_install.log
	cd snort-2.9.8.3
	./configure --prefix=/usr --enable-sourcefire \
		--enable-flexresp --enable-dynamicplugin \
		--enable-perfprofiling --enable-reload
	make && make install
	if [ $? -ne 0 ]; then
		echo "Error: unable to install snort" | tee -a /var/libre_install.log
		exit 3
	fi

	# Copy config files
	mkdir -p /etc/snort/preproc_rules /var/log/snort /etc/snort/rules
	mkdir -p /usr/lib/snort_dynamicrules
	cp ./etc/*.conf* ./etc/*.map /etc/snort/
	# Create Snort directories
	touch /etc/snort/rules/white_list.rules
	touch /etc/snort/rules/black_list.rules
	touch /etc/snort/rules/local.rules
	cd ../

	# Pulled Pork
	echo "Downloading pulledpork ..."
	git clone https://github.com/shirkdog/pulledpork.git
	if [ $? -ne 0 ]; then
		echo "Error: unable to download pulledpork" | tee -a /var/libre_install.log
		exit 3
	fi
	cd pulledpork
	cp pulledpork.pl /usr/bin/
	chmod +x /usr/bin/pulledpork.pl
	cp ./etc/*.conf /etc/snort/
	cd ../
	mkdir -p /etc/snort/rules/iplists
	touch /etc/snort/rules/iplists/default.blacklist

	echo "Updating Snort rules ..." | tee -a /var/libre_install.log
	# Comment current includes
	sed -i -e 's/include \$RULE\_PATH/#include \$RULE\_PATH/' /etc/snort/snort.conf
	# Fix pulledpork configuration
	sed -i -e 's/^\(rule_url.*<oinkcode>\)/#\1/g' /etc/snort/pulledpork.conf
	sed -i -e 's@/usr/local/lib/@/usr/lib/@g' /etc/snort/pulledpork.conf
	sed -i -e 's@/usr/local/@/@g' /etc/snort/pulledpork.conf
	# Fix Snort configuration
	sed -i -e 's@/usr/local/lib/@/usr/lib/@g' /etc/snort/snort.conf
	sed -i -e 's@var RULE_PATH .*@var RULE_PATH /etc/snort/rules@g' /etc/snort/snort.conf
	sed -i -e 's@var SO_RULE_PATH .*@var SO_RULE_PATH /etc/snort/rules/so_rules@g' /etc/snort/snort.conf
	sed -i -e 's@var PREPROC_RULE_PATH .*@var PREPROC_RULE_PATH /etc/snort/rules/preproc_rules@g' /etc/snort/snort.conf
	sed -i -e 's@var WHITE_LIST_PATH .*@var WHITE_LIST_PATH /etc/snort/rules@g' /etc/snort/snort.conf
	sed -i -e 's@var BLACK_LIST_PATH .*@var BLACK_LIST_PATH /etc/snort/rules@g' /etc/snort/snort.conf
	echo 'include $RULE_PATH/local.rules' >> /etc/snort/snort.conf
	echo 'include $RULE_PATH/snort.rules' >> /etc/snort/snort.conf
	# Download rules
	pulledpork.pl -c /etc/snort/pulledpork.conf -l
	if [ $? -ne 0 ]; then
		echo "Error: unable to update Snort rules" | tee -a /var/libre_install.log
		exit 3
	fi

	# Cleanup
	rm -rf daq-2.0.6
	rm -rf snort-2.9.8.3
	rm -rf pulledpork
}


# ----------------------------------------------
# Function to install Barnyard2
# ----------------------------------------------
install_barnyard()
{
	echo "Installing Barnyard ..." | tee -a /var/libre_install.log

	echo "Downloading Barnyard ..." | tee -a /var/libre_install.log
	git clone https://github.com/firnsy/barnyard2.git
	if [ $? -ne 0 ]; then
		echo "Error: unable to download Barnyard" | tee -a /var/libre_install.log
		exit 3
	fi

	cd barnyard2
	echo "Building Barnyard ..." | tee -a /var/libre_install.log
	./autogen.sh
	./configure --prefix=/usr --with-mysql CFLAGS='-g -O2 -DHAVE_DUMBNET_H' \
		--with-mysql-libraries=/usr/lib/x86_64-linux-gnu/
	make && make install
	if [ $? -ne 0 ]; then
		echo "Error: unable to install Barnyard" | tee -a /var/libre_install.log
		exit 3
	fi
	mv /usr/etc/barnyard2.conf /etc/snort/
	mkdir -p /var/log/barnyard2
	cd ..

	# Cleanup
	rm -rf barnyard2
}


# ----------------------------------------------
# Function to install vortex-ids package
# ----------------------------------------------
install_vortex_ids()
{
	echo "Installing vortex-ids ..." | tee -a /var/libre_install.log

	echo "Downloading vortex-ids ..." | tee -a /var/libre_install.log
	git clone https://github.com/lmco/vortex-ids
	if [ $? -ne 0 ]; then
		echo "Error: unable to download vortex-ids" | tee -a /var/libre_install.log
		exit 3
	fi

	cd vortex-ids
	echo "Building libbsf ..." | tee -a /var/libre_install.log
	gcc -Wall -fPIC -shared libbsf/libbsf.c -o libbsf.so
	if [ $? -ne 0 ]; then
		echo "Error: unable to build libbsf" | tee -a /var/libre_install.log
		exit 3
	fi
	cp libbsf/bsf.h /usr/include/ && cp libbsf.so /usr/lib/

	echo "Building vortex ..." | tee -a /var/libre_install.log
	gcc vortex/vortex.c -lpcap -lnids -lpthread -lbsf -Wall -DWITH_BSF -o vortex.bin -O2
	if [ $? -ne 0 ]; then
		echo "Error: unable to build vortex" | tee -a /var/libre_install.log
		exit 3
	fi
	cp vortex.bin /usr/bin/vortex

	echo "Building xpipes ..." | tee -a /var/libre_install.log
	gcc xpipes/xpipes.c -lpthread -Wall -o xpipes.bin -O2
	if [ $? -ne 0 ]; then
		echo "Error: unable to build xpipes" | tee -a /var/libre_install.log
		exit 3
	fi
	cp xpipes.bin /usr/bin/xpipes
	cd ../

	# Cleanup
	rm -rf vortex-ids
}


# ----------------------------------------------
# Function to install openwips-ng package
# ----------------------------------------------
install_openwips_ng()
{
	echo "Installing openwips-ng ..." | tee -a /var/libre_install.log

	echo "Downloading openwips-ng ..." | tee -a /var/libre_install.log
	git clone https://github.com/aircrack-ng/OpenWIPS-ng.git
	if [ $? -ne 0 ]; then
		echo "Error: unable to download openwips-ng" | tee -a /var/libre_install.log
		exit 3
	fi

	echo "Building openwips-ng ..." | tee -a /var/libre_install.log
	cd OpenWIPS-ng
	# disable Werror flag
	sed -i -e 's/-Werror//g' ./common.mak

	make LIBS+="-lpcap -lssl -lz -lcrypto -ldl -lm -lpthread -lsqlite3" &&
	make install
	if [ $? -ne 0 ]; then
		echo "Error: unable to install openwips-ng" | tee -a /var/libre_install.log
		exit 3
	fi
	cd ../

	# Cleanup
	rm -rf OpenWIPS-ng
}


# ----------------------------------------------
# Function to install hakabana
# ----------------------------------------------
install_hakabana()
{
	echo "Installing hakabana ..." | tee -a /var/libre_install.log

	echo "Downloading hakabana ..." | tee -a /var/libre_install.log
	URL="https://github.com/haka-security/hakabana/releases/download/0.2.1"
	PKG="hakabana_0.2.1_all.deb"
	wget -P /tmp/ $URL/$PKG

	echo "Installing hakabana ..." | tee -a /var/libre_install.log
	dpkg -i /tmp/$PKG && apt-get install -f
	if [ $? -ne 0 ]; then
		echo "Error: unable to install hakabana" | tee -a /var/libre_install.log
		exit 3
	fi

	# Cleanup
	rm -rf /tmp/$PKG
}


# ----------------------------------------------
# Function to install FlowViewer
# ----------------------------------------------
install_flowviewer()
{
	echo "Installing FlowViewer ..." | tee -a /var/libre_install.log

	echo "Downloading SiLK ..." | tee -a /var/libre_install.log
	URL="http://tools.netsa.cert.org/releases"
	PKG="silk-3.12.2.tar.gz"
	wget -P /tmp/ $URL/$PKG
	tar xvf /tmp/$PKG
	rm -rf /tmp/$PKG

	cd silk-3.12.2
	./configure --prefix=/usr --with-python --with-libfixbuf --enable-ipv6
	make && make install
	if [ $? -ne 0 ]; then
		echo "Error: unable to install SiLK" | tee -a /var/libre_install.log
		exit 3
	fi
	cd ../

	echo "Downloading FlowViewer ..." | tee -a /var/libre_install.log
	URL="https://sourceforge.net/projects/flowviewer/files"
	PKG="FlowViewer_4.6.tar"
	wget -P /tmp/ $URL/$PKG
	tar xvf /tmp/$PKG
	if [ $? -ne 0 ]; then
		echo "Error: unable to download FlowViewer" | tee -a /var/libre_install.log
		exit 3
	fi
	mv FlowViewer_4.6 /opt/FlowViewer

	# Cleanup
	rm -rf /tmp/$PKG
	rm -rf silk-3.12.2
}


# ----------------------------------------------
# Function to install pmgraph
# ----------------------------------------------
install_pmgraph()
{
	echo "Installing pmgraph ..." | tee -a /var/libre_install.log

	echo "Downloading pmgraph ..." | tee -a /var/libre_install.log
	git clone https://github.com/aptivate/pmgraph
	if [ $? -ne 0 ]; then
		echo "Error: unable to download pmgraph" | tee -a /var/libre_install.log
		exit 3
	fi

	echo "Building pmgraph ..." | tee -a /var/libre_install.log
	cd pmgraph
	sed -i -e 's/tomcat6/tomcat7/g' \
		Installer/pmGraphInstaller.sh debian/pmgraph.postinst \
		debian/pmgraph.postrm debian/control
	sed -i -e 's/pmacct restart/pmacctd restart/g' \
		Installer/pmGraphInstaller.sh debian/pmgraph.postinst \
		debian/pmgraph.postrm debian/control
	sed -i -e 's/ | tomcat5.5//g' debian/control
	sed -i -e 's/openjdk-6-jdk/openjdk-7-jdk/g' debian/control
	sed -i -e 's/java-6-sun/java-7-openjdk-amd64/g' debian/rules

	debuild -us -uc
	if [ $? -ne 0 ]; then
		echo "Error: unable to pack pmgraph" | tee -a /var/libre_install.log
		exit 3
	fi
	DEBIAN_FRONTEND=noninteractive dpkg -i ../pmgraph_1.2.3_all.deb && 
	DEBIAN_FRONTEND=noninteractive apt-get install -f
	if [ $? -ne 0 ]; then
		echo "Error: unable to install pmgraph" | tee -a /var/libre_install.log
		exit 3
	fi
	cd ../

	# Cleanup
	rm -rf ./pmgraph
	rm -rf ./pmgraph_1.2.3*
}


# ----------------------------------------------
# Function to install nfsen
# ----------------------------------------------
install_nfsen()
{
	echo "Installing nfsen ..." | tee -a /var/libre_install.log

	# nfdump
	echo "Downloading nfdump ..." | tee -a /var/libre_install.log
	URL="https://sourceforge.net/projects/nfdump/files/stable/nfdump-1.6.13"
	PKG="nfdump-1.6.13.tar.gz"
	wget -P /tmp/ $URL/$PKG
	tar xvf /tmp/$PKG
	rm -rf /tmp/$PKG

	echo "Building nfdump ..." | tee -a /var/libre_install.log
	cd nfdump-1.6.13
	./configure --enable-nfprofile
	make && make install
	if [ $? -ne 0 ]; then
		echo "Error: unable to install nfdump" | tee -a /var/libre_install.log
		exit 3
	fi
	cd ../

	# nfsen
	echo "Downloading nfsen ..." | tee -a /var/libre_install.log
	URL="https://sourceforge.net/projects/nfsen/files/stable/nfsen-1.3.6p1"
	PKG="nfsen-1.3.6p1.tar.gz"
	wget -P /tmp/ $URL/$PKG
	tar xvf /tmp/$PKG
	rm -rf /tmp/$PKG

	echo "Building nfsen ..." | tee -a /var/libre_install.log
	cd nfsen-1.3.6p1
	# Fix broken input
	sed -i -e 's@import Socket6@Socket6->import(qw(pack_sockaddr_in6 unpack_sockaddr_in6 inet_pton getaddrinfo))@g' \
		libexec/AbuseWhois.pm libexec/Lookup.pm
	# Fix configuration
	cp ./etc/nfsen-dist.conf ./etc/nfsen.conf
	sed -i -e 's@^\$BASEDIR.*$@$BASEDIR = "/var/nfsen";@g' ./etc/nfsen.conf
	sed -i -e 's@^\$USER.*$@$USER = "www-data";@g' ./etc/nfsen.conf
	sed -i -e 's@^\$WWWUSER.*$@$WWWUSER = "www-data";@g' ./etc/nfsen.conf
	sed -i -e 's@^\$WWWGROUP.*$@$WWWGROUP = "www-data";@g' ./etc/nfsen.conf
	sed -i -e '/^.*peer[12].*$/d' ./etc/nfsen.conf
	# Disable interactive mode
	sed -i -e '/chomp(\$ans = <STDIN>);/d' ./install.pl
	perl ./install.pl ./etc/nfsen.conf
	if [ $? -ne 0 ]; then
		echo "Error: unable to install nfsen" | tee -a /var/libre_install.log
		exit 3
	fi
	cd ../

	# Cleanup
	rm -rf nfdump-1.6.13
	rm -rf nfsen-1.3.6p1
}


# ----------------------------------------------
# Function to install evebox package
# ----------------------------------------------
install_evebox()
{
        echo "Installing EveBox ..." | tee -a /var/libre_install.log

        if [ ! -e evebox-0.6.0dev-linux-amd64 ]; then
        	echo "Downloading EveBox ..." | tee -a /var/libre_install.log
        	wget --no-check-certificat \
        	https://dl.bintray.com/jasonish/deb-evebox-latest/evebox_0.7.0_amd64.deb
                	if [ $? -ne 0 ]; then
                        	echo "Error: unable to download EveBox. Exiting ..." | tee -a /var/libre_install.log
                        	exit 3
                	fi
        fi

        # Installing package  
        dpkg -i evebox_0.7.0_amd64.deb
                if [ $? -ne 0 ]; then
                        echo "Error: unable to install EveBox. Exiting ..." | tee -a /var/libre_install.log
                        exit 3
                fi

        # Cleanup
        rm -rf evebox_0.7.0_amd64.deb
}


# ----------------------------------------------
# Function to install SELKS GUI
# ----------------------------------------------
install_selks()
{
	echo "Installing SELKS ..." | tee -a /var/libre_install.log

	echo "Installing timelion plugin ..." | tee -a /var/libre_install.log
	touch /opt/kibana/config/kibana.yml
	/opt/kibana/bin/kibana plugin -i elastic/timelion
	if [ $? -ne 0 ]; then
		echo "Error: unable to install timelion plugin" | tee -a /var/libre_install.log
		exit 3
	fi

	echo "Downloading KTS ..." | tee -a /var/libre_install.log
	git clone https://github.com/StamusNetworks/KTS.git
	if [ $? -ne 0 ]; then
		echo "Error: unable to download KTS" | tee -a /var/libre_install.log
		exit 3
	fi

	echo "Patching Kibana ..." | tee -a /var/libre_install.log
	patch -p1 -d /opt/kibana/ < KTS/patches/kibana-integer.patch &&
	patch -p1 -d /opt/kibana/ < KTS/patches/timelion-integer.patch
	if [ $? -ne 0 ]; then
		echo "Error: unable to patch Kibana" | tee -a /var/libre_install.log
		exit 3
	fi
	mv KTS /opt/

	echo "Downloading SELKS Scripts ..." | tee -a /var/libre_install.log
	git clone https://github.com/StamusNetworks/selks-scripts.git
	if [ $? -ne 0 ]; then
		echo "Error: unable to download SELKS Scripts" | tee -a /var/libre_install.log
		exit 3
	fi
	cd selks-scripts
	# Fix conky
	sed -i -e 's/lightgey/lightgrey/g' \
		Scripts/Configs/Conky/etc/conky/conky.conf
	sed -i -e "s@\(-F\\\\\)'@\1\\\"@g" \
		Scripts/Configs/Conky/etc/conky/conky.conf

	#'" this comment fix formatting

	echo "Installing SELKS configuration ..."
	cp Scripts/Configs/Conky/etc/conky/conky.conf /etc/conky/conky.conf
	cp Scripts/Configs/Elasticsearch/etc/elasticsearch/elasticsearch.yml \
		/etc/elasticsearch/elasticsearch.yml
	cp Scripts/Configs/Logrotate/etc/logrotate.d/suricata /etc/logrotate.d/
	cp Scripts/Configs/Logstash/etc/logstash/conf.d/logstash.conf \
		/etc/logstash/conf.d/

	cd ../

	# Cleanup
	rm -rf selks-scripts
}


# ----------------------------------------------
# Function to install Snorby
# ----------------------------------------------
install_snorby()
{
	echo "Installing Snorby ..." | tee -a /var/libre_install.log

	echo "Downloading Snorby ..." | tee -a /var/libre_install.log
	git clone https://github.com/Snorby/snorby.git
	if [ $? -ne 0 ]; then
		echo "Error: unable to download Snorby" | tee -a /var/libre_install.log
		exit 3
	fi
	cd snorby
	echo "Installing Gem dependencies ..." | tee -a /var/libre_install.log
	bundle install --system
	if [ $? -ne 0 ]; then
		echo "Error: unable to install dependencies" | tee -a /var/libre_install.log
		exit 3
	fi
	cp config/snorby_config.yml.example config/snorby_config.yml
	cp config/database.yml.example config/database.yml
	# Fix worker pid
	sed -i -e 's@Snorby::Process.new(`ps -o ruser,pid,%cpu,%mem,vsize,rss,tt,stat,start,etime,command -p #{Worker.pid} |grep delayed_job |grep -v grep`.chomp.strip)@Snorby::Process.new("www   -1   0.0  0.0 0  0  ??  S    00:00PM        00:00 ruby: delayed_job (ruby)")@g' lib/snorby/worker.rb
	cd ../
	mv snorby /var/www/
}


# ---------------------------------------------------------
# Function to install glype proxy server
# ---------------------------------------------------------
install_glype()
{
	echo "Installing glype ..." | tee -a /var/libre_install.log

	# Downloading glype-1.4.15
	if [ ! -e glype-1.4.15.zip ]; then
	    wget http://netix.dl.sourceforge.net/project/free-proxy-server/glype-1.4.15%20%281%29.zip
	    if [ $? -ne 0 ]; then
	        echo "Error: unable to download glype" | tee -a /var/libre_install.log
	        exit 3
	    fi
	    mv glype-1.4.15\ \(1\).zip glype-1.4.15.zip
	fi

	unzip glype-1.4.15.zip -d glype-1.4.15
	rm -rf /var/www/glype

	# Creating glype home
	mkdir /var/www/glype
	cp -R glype-1.4.15/* /var/www/glype
        chmod 777 /var/www/glype/includes/settings.php
        chmod 777 /var/www/glype/tmp/

	# Cleanup
	rm -rf glype-1.4.15
}


# ---------------------------------------------------------
# Function to install gitlab package
# ---------------------------------------------------------
install_gitlab()
{
# Gitlab can only be installed on x86_64 (64 bit) architecture
if [ "$ARCH" == "x86_64" ]; then

	echo "Installing gitlab ..." | tee -a /var/libre_install.log

	# Check if gitlab is installed or not 
	which gitlab-ctl >> /var/libre_install.log 
	if [ $? -ne 0 ]; then 
		# Install the necessary dependencies
		apt-get install -y --force-yes curl openssh-server ca-certificates postfix

#	        if [ ! -e gitlab-ce_8.12.7-ce.0_amd64.deb ]; then
#	        echo "Downloading Gitlab ..." | tee -a /var/libre_install.log
#	        wget --no-check-certificat -O gitlab-ce_8.12.7-ce.0_amd64.deb \
#		https://packages.gitlab.com/gitlab/gitlab-ce/packages/debian/wheezy/gitlab-ce_8.12.7-ce.0_amd64.deb/download 
#	
#	                if [ $? -ne 0 ]; then
#	                        echo "Error: unable to download Gitlab. Exiting ..." | tee -a /var/libre_install.log
#	                        exit 3
#	                fi
#	        fi
#        
#		# Install gitlab 
#		dpkg -i gitlab-ce_8.12.7-ce.0_amd64.deb
#	        if [ $? -ne 0 ]; then
#	                echo "Error: unable to install Gitlab. Exiting ..." | tee -a /var/libre_install.log
#	                exit 3
#	        fi

		# Installing from packages for dependencies
		curl -LO https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh
		bash script.deb.sh
		apt-get install -y --force-yes gitlab-ce
	fi
else
	echo "Skipping gitlab installation. x86_64 Needed / Detected: $ARCH" | tee -a /var/libre_install.log
fi
}


# ---------------------------------------------------------
# Function to install trac server
# ---------------------------------------------------------
install_trac()
{
        if [ "$ARCH" == "x86_64" ]; then
                echo "Installing trac ..." | tee -a /var/libre_install.log
                apt-get -y --force-yes install trac
                if [ $? -ne 0 ]; then
                        echo "Error: unable to install trac. Exiting ..." | tee -a /var/libre_install.log
                        exit 3
                fi
        else
                echo "Skipping trac installation. x86_64 Needed / Detected: $ARCH" | tee -a /var/libre_install.log
        fi
}


# ---------------------------------------------------------
# Function to install redmine server
# ---------------------------------------------------------
install_redmine()
{
if [ "$ARCH" == "x86_64" ]; then
	echo "Installing redmine ..." | tee -a /var/libre_install.log
        apt-get -y --force-yes install \
        mysql-server mysql-client libmysqlclient-dev \
        gcc build-essential zlib1g zlib1g-dev zlibc \
        ruby-zip libssl-dev libyaml-dev libcurl4-openssl-dev \
        ruby ruby2.1 gem libapr1-dev libxslt1-dev checkinstall \
        libxml2-dev ruby-dev vim libmagickwand-dev imagemagick
        if [ $? -ne 0 ]; then
        	echo "Error: unable to install redmine. Exiting ..." | tee -a /var/libre_install.log
                exit
        fi

	rm -rf /opt/redmine
        mkdir /opt/redmine
        chown -R www-data /opt/redmine
	cd /opt/redmine
	
	if [ ! -e redmine-3.3.1 ]; then
                echo "Downloading redmine ..." | tee -a /var/libre_install.log
                wget http://www.redmine.org/releases/redmine-3.3.1.tar.gz
                if [ $? -ne 0 ]; then
                        echo "Error: unable to download redmine. Exiting ..." | tee -a /var/libre_install.log
                        exit
                fi
                tar xzf redmine-3.3.1.tar.gz
	fi
        cd redmine-3.3.1

        # Install bundler
        gem install bundler
        if [ $? -ne 0 ]; then
                echo "Error: unable to install bundler. Exiting ..." | tee -a /var/libre_install.log
                exit 3
        fi
	
	echo "gem 'thin'" > Gemfile.local
	bundle install --without development test
	thin install

        # Generate secret token
        bundle exec rake generate_secret_token

        # Prepare DB and install all tables:
        #RAILS_ENV=production bundle exec rake db:migrate
        #RAILS_ENV=production bundle exec rake redmine:load_default_data
else
        echo "Skipping redmine installation. x86_64 Needed / Detected: $ARCH" | tee -a /var/libre_install.log
fi
}


# ---------------------------------------------------------
# Funtion to install ndpi and ndpi-netfilter package
# ---------------------------------------------------------
install_ndpi()
{
        echo "Installing ndpi ..." | tee -a /var/libre_install.log

	# Installing dependencies
	apt-get install -y --force-yes \
	autogen automake make gcc \
	linux-source libtool autoconf pkg-config subversion \
	libpcap-dev iptables-dev linux-headers-amd64 linux-headers-$(uname -r)
	
	# Removing old source
	rm -rf nDPI

	if [ ! -e nDPI ]; then
		echo "Downloading ndpi ..." | tee -a /var/libre_install.log
		git clone https://github.com/vel21ripn/nDPI
                if [ $? -ne 0 ]; then
                        echo "Unable to download ndpi. Exiting ..." | tee -a /var/libre_install.log
                        exit 3
                fi
	fi
	
	# Extracting nDPI
	cd nDPI

	# Building nDPI
	./autogen.sh
	./configure 
	make
	#make install
        if [ $? -ne 0 ]; then
                echo "Unable to install ndpi. Exiting ..." | tee -a /var/libre_install.log
                exit 3
        fi

	# Building nDPI-netfilter
        ./autogen.sh
        cd ndpi-netfilter
        make
	# Install the nDPI module for the given Linux kernel.
        make modules_install
	# Copy the iptables module into the corresponding directory.
        make install	
        if [ $? -ne 0 ]; then
                echo "Unable to install ndpi-netfilter. Exiting ..." | tee -a /var/libre_install.log
                exit 3
        fi

	# Load ndpi module
        modprobe xt_ndpi
        if [ $? -ne 0 ]; then
                echo "Unable to load ndpi module. Exiting ..." | tee -a /var/libre_install.log
                exit 3
        fi

	# Load Module at Startup
	if ! grep xt_ndpi /etc/modules >> /var/libre_install.log ; then
	    echo "xt_ndpi" >> /etc/modules
	fi

	cd $INSTALL_HOME
}


# ----------------------------------------------
# Function to install redsocks package
# ----------------------------------------------
install_redsocks()
{
        echo "Installing redsocks ..." | tee -a /var/libre_install.log

        # Installing dependencies
        apt-get install -y --force-yes \
        iptables git-core libevent-2.0-5 libevent-dev

        # Removing old source
	cd /opt/
        rm -rf redsocks

        if [ ! -e redsocks ]; then
                echo "Downloading redsocks..." | tee -a /var/libre_install.log
                git clone https://github.com/darkk/redsocks
                if [ $? -ne 0 ]; then
                        echo "Unable to download redsocks. Exiting ..." | tee -a /var/libre_install.log
                        exit 3
                fi
        fi

        # Building nDPI
        cd redsocks/
        make
        if [ $? -ne 0 ]; then
                echo "Unable to install redsocks. Exiting ..." | tee -a /var/libre_install.log
                exit 3
        fi

	cd $INSTALL_HOME
}


# -----------------------------------------------
# Function to install ntopng
# -----------------------------------------------
install_ntopng()
{
        echo "Installing ntopng ..." | tee -a /var/libre_install.log
        sudo apt-get -y --force-yes install ntopng
        if [ $? -ne 0 ]; then
                echo "Error: Unable to install ntopng. Exiting" | tee -a /var/libre_install.log
                exit 3
        fi      
}


# -----------------------------------------------
# Function to install postfixadmin
# -----------------------------------------------
install_postfix()
{
        echo "Installing postfix ..." | tee -a /var/libre_install.log
        DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install postfix postfixadmin postfix-mysql 
        if [ $? -ne 0 ]; then
                echo "Error: Unable to install postfix. Exiting" | tee -a /var/libre_install.log
                exit 3
        fi

	# Download postfixadmin database
        if [ ! -e postfixadmin.txt ]; then
                echo "Downloading postfixadmin database ..." | tee -a /var/libre_install.log
                wget https://www.nesono.com/sites/default/files/postfixadmin.txt
                if [ $? -ne 0 ]; then
                        echo "Unable to download postfixadmin database. Exiting ..." | tee -a /var/libre_install.log
                        exit 3
                fi
        fi
}


# -----------------------------------------------
# Function to install miniupnp
# -----------------------------------------------
install_upnp()
{
echo "Installing upnp ..."  | tee -a /var/libre_install.log

if [ ! -e /usr/bin/upnpc ]; then
    mkdir /usr/src/upnpc
    cd /usr/src/upnpc
    curl http://miniupnp.tuxfamily.org/files/miniupnpc-2.0.20161216.tar.gz > miniupnpc-2.0.20161216.tar.gz
    tar xzf miniupnpc-2.0.20161216.tar.gz

    cd miniupnpc-2.0.20161216
    make && make install
    if [ $? -ne 0 ]; then
            echo "Unable to install upnp. Exiting ..." | tee -a /var/libre_install.log
            exit 3
    fi

    # Cleanup
    cd ../
    rm -rf miniupnpc-2.0.20161216.tar.gz

    cd $INSTALL_HOME
fi
}


# -----------------------------------------------
# Function to install webconsole
# -----------------------------------------------
install_webconsole()
{
echo "Installing webconsole ..."  | tee -a /var/libre_install.log

if [ ! -e /var/www/webconsole/webconsole.php ]; then
    cd /var/www/
    wget https://github.com/nickola/web-console/releases/download/v0.9.7/webconsole-0.9.7.zip

    if [ $? -ne 0 ]; then
        echo "Unable to download webconsole. Exiting ..." | tee -a /var/libre_install.log
        exit 3
    fi

    # Unzip webconsole package
    unzip webconsole-0.9.7.zip

    # Cleanup
    rm -rf webconsole-0.9.7.zip

    cd $INSTALL_HOME
fi
}


# -----------------------------------------------
# Function to install tahoe
# -----------------------------------------------
install_tahoe()
{

if [ -e /home/tahoe-lafs ]; then
    textmsg="Thee already installed, do you want to delete and re-install a new one [no/yes]?"
    read -p "$textmsg" -e install
    if [ "$install" != "yes" ]; then
       exit
    fi
fi

# Local access funtions (SSH support or SSHFS )
echo "Host 127.0.0.1" >> /etc/ssh/ssh_config
echo "  HostName localhost"  >> /etc/ssh/ssh_config
echo "  Port 8022"  >> /etc/ssh/ssh_config
echo "  StrictHostKeyChecking no"  >> /etc/ssh/ssh_config
echo  >> /etc/ssh/ssh_config
echo "Host 127.0.0.1" >> /etc/ssh/ssh_config
echo "  HostName localhost"  >> /etc/ssh/ssh_config
echo "  Port 8024"  >> /etc/ssh/ssh_config
echo "  StrictHostKeyChecking no"  >> /etc/ssh/ssh_config
echo  >> /etc/ssh/ssh_config

/home/tahoe-lafs/venv/bin/tahoe stop /usr/node_1
/home/tahoe-lafs/venv/bin/tahoe stop /usr/public_node
rm -rf /home/tahoe-lafs
rm -rf /usr/node_1
rm -rf /root/.tahoe
rm -rf /usr/public_node

ssh-keygen -f "/root/.ssh/known_hosts" -R [localhost]:8022
ssh-keygen -f "/root/.ssh/known_hosts" -R [localhost]:8024

# Setup new py env and install required packages if not existing

#if [ ! -x /home/tahoe-lafs]; then
    apt-get install -y --force-yes sshpass
    apt-get install -y --force-yes sshfs
    mkdir /home/tahoe-lafs
    cd /home/tahoe-lafs
    virtualenv venv
    venv/bin/pip install -U pip setuptools   # required or no bzip is recognized
    venv/bin/pip install tahoe-lafs[tor,i2p] # required with TOR + I2P
#fi

# VERY IMPORTANT. FIX a bug that causes max file uploadaed through sshfs/sftp 
# comes to zero size if size > 55 bytes. 
# This happens some times ( 50% aprox repeatable ) not only on inmutable but also on mutables

# The fix is /home/tahoe-lafs/venv/lib/python2.7/site-packages/allmydata/immutable/upload.py file line 1519 must:
# -URI_LIT_SIZE_THRESHOLD = 55
# +URI_LIT_SIZE_THRESHOLD = 55555 

#cd /home/tahoe-lafs/venv/lib/python2.7/site-packages/allmydata/immutable
#patching=$(sed -e "s/URI_LIT_SIZE_THRESHOLD = 55/URI_LIT_SIZE_THRESHOLD = 55/g" upload.py > /tmp/upload.py.patched)
#mv /tmp/upload.py.patched /home/tahoe-lafs/venv/lib/python2.7/site-packages/allmydata/immutable/upload.py
#cd /home/tahoe-lafs/venv/lib/python2.7/site-packages/allmydata/immutable; python -m py_compile upload.py

# python -m py_compile upload.py

# /usr/node_1 is used to store PRIVATE Tahoe node_1
# /usr/private_node is used to store ( shared ) common PUBLIC Tahoe node
# /var/node_1 is a mount point for node_1 FUSE
# /var/private_node is a mount point for node public_node FUSE

mkdir /root/.tahoe
}


# -----------------------------------------------
# Function to install atheros formware 
# -----------------------------------------------
install_atheros_firmware()
{
    apt-get install cmake -y --force-yes >> /var/libre_install.log
    cd /usr/src
    git clone https://github.com/qca/open-ath9k-htc-firmware.git
    cd open-ath9k-htc-firmware
    make toolchain
    mkdir /lib/firmware
    make -C target_firmware
    cp target_firmware/*.fw /lib/firmware/
}


set_cpu_throttle() {

    apt-get install cpupower -y --force-yes >> /var/libre_install.log
    cpupower frequency-set -g performance
}


# -----------------------------------------------
# This function saves variables in file, so
# parametization script can read and use these 
# values
# Variables to save are:
#   PLATFORM
#   HARDWARE
#   PROCESSOR
#   EXT_INTERFACE
#   INT_INTERFACE
#   ARCH
# -----------------------------------------------  
save_variables()
{
        echo "Saving variables ..." | tee -a /var/libre_install.log
	if [ -e /var/box_variables ]; then
		if grep "DB_PASS" /var/box_variables >> /var/libre_install.log 2>>/var/libre_install.log ; then
 	               MYSQL_PASS=`cat /var/box_variables | grep "DB_PASS" | awk {'print $2'}`
		       echo -e \
"Platform: $PLATFORM\n\
Hardware: $HARDWARE\n\
Processor: $PROCESSOR\n\
Architecture: $ARCH\n\
Ext_interface: $EXT_INTERFACE\n\
Int_interface: $INT_INTERFACE\n\
DB_PASS: $MYSQL_PASS" \
		 > /var/box_variables
		else
	               echo -e \
"Platform: $PLATFORM\n\
Hardware: $HARDWARE\n\
Processor: $PROCESSOR\n\
Architecture: $ARCH\n\
Ext_interface: $EXT_INTERFACE\n\
Int_interface: $INT_INTERFACE" \
                 > /var/box_variables
		fi
	else
		touch /var/box_variables	
        	echo -e \
"Platform: $PLATFORM\n\
Hardware: $HARDWARE\n\
Processor: $PROCESSOR\n\
Architecture: $ARCH\n\
Ext_interface: $EXT_INTERFACE\n\
Int_interface: $INT_INTERFACE" \
                 > /var/box_variables
	fi
}



# ----------------------------------------------
# MAIN 
# ----------------------------------------------
# This is the main function of this script.
# It uses functions defined above to check user,
# Platform, Hardware, System requirements and 
# Internet connection. Then it downloads
# installs all neccessary packages.
# ----------------------------------------------
#
# ----------------------------------------------
# At first script will check
#
# 1. User      ->  Need to be root
# 2. Platform  ->  Need to be Debian 7 / Debian 8 / Ubuntu 12.04 / Ubuntu 14.04 
# 3. Hardware  ->  Need to be ARM / Intel or AMD
# ----------------------------------------------
check_root    	# Checking user 
get_platform  	# Getting platform info
get_hardware  	# Getting hardware info
# ----------------------------------------------
# If script detects Physical/Virtual machine
# then next steps will be
# 
# 4. Checking requirements
# 5. Get Internet access
# 6. Configure repositories
# 7. Download and Install packages
# ----------------------------------------------
if [ "$PROCESSOR" = "Intel" -o "$PROCESSOR" = "AMD" -o "$PROCESSOR" = "ARM" ]; then 
        setterm -blank 0         # Dissable console blanking ( power saving )
	check_internet           # Check Internet access
#	check_assemblance        # Check router assemblance
	check_requirements       # Checking requirements for 
        get_interfaces  	 # Get DHCP on eth0 or eth1 and 
				 # connect to Internet
	configure_repositories	 # Prepare and update repositories
#       set_cpu_throttle         # EXPERIMENTAL . Try to avoid fake warnings when CPU throttle under powersave
#	install_apmode		 # Prepare wlan AP script
	install_packages       	 # Download and install packages	
#	install_libressl	 # Install Libressl package
	install_modsecurity      # Install modsecurity package
	install_waffle		 # Install modsecurity GUI WAF-FLE package
	install_certificates	 # Install ssl certificates
        install_modsecrules      # Install Modsecurity rules
	install_mailpile	 # Install Mailpile package
	install_easyrtc		 # Install EasyRTC package
#	install_hublin		 # Install hublin package
	install_owncloud	 # Install Owncloud package
	install_libecap		 # Install libecap package
	install_fg-ecap		 # Install fg-ecap package
	install_squid		 # Install squid package
	install_squidclamav	 # Install SquidClamav package
	install_squidguard_bl	 # Install Squidguard blacklists
	install_squidguardmgr	 # Install Squidguardmgr (Manager Gui) 
	install_ecapguardian	 # Inatall ecapguardian package
#	install_e2guardian	 # Inatall e2guardian package
	install_suricata	 # Install Suricata package
	install_kibana		 # Install Kibana,elasticsearch,logstash packages
#	install_scirius		 # Install Scirius package
#	install_snort		 # Install Snort package
#	install_barnyard	 # Install Barnyard package
#	install_vortex_ids	 # Install Vortex-ids package
#	install_openwips_ng	 # Install Openwips-ng package
#	install_hakabana	 # Install hakabana package
#	install_flowviewer	 # Install FlowViewer package
#	install_pmgraph		 # Install pmgraph package
#	install_nfsen		 # Install nfsen package
#	install_evebox		 # Install EveBox package
#	install_selks		 # Install SELKS GUI
#	install_snorby		 # Install Snorby package
	install_glype		 # Install glype proxy
	install_gitlab		 # Install gitlab packae
	install_trac		 # Install trac package
	install_redmine		 # Install redmine package
	install_ndpi		 # Install ndpi package
	install_redsocks	 # Install redsocks package
	install_ntopng		 # Install ntopng package
	install_postfix		 # Install postfixadmin package
	install_upnp	 	 # Install miniupnp package
        install_webconsole       # Install webconsole package
	install_tahoe            # Install tahoe
        install_atheros_firmware # Install free firmware for atheros devices from Github
        save_variables	         # Save detected variables

        echo "Installation completed." | tee -a /var/libre_install.log
fi

# ---------------------------------------------
# If script reachs to this point then it's done 
# successfully
# ---------------------------------------------
#echo "Initialization done successfully"

exit 
