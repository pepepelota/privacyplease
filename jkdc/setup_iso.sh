#!/bin/bash

# -----------------------------------------------
# Installation part
# -----------------------------------------------

echo "Downloading installation script ..."
wget --no-check-certificate https://raw.githubusercontent.com/Librerouter/Librekernel/gh-pages/app-installation-script.sh
if [ $? -ne 0 ]; then
	echo "Unable to download installtaion script. Exiting ..."
	exit 1
fi
echo "Running installation scirpt"
chmod +x app-installation-script.sh
./app-installation-script.sh

# Checking status
if [ $? -ne 0 ]; then
        echo "Erron in installtaion script. Exiting ..."
        exit 1
fi


# -----------------------------------------------
# Configuration part
# -----------------------------------------------

echo "Downloading configuration script ..."
wget --no-check-certificate https://raw.githubusercontent.com/Librerouter/Librekernel/gh-pages/app-configuration-script.sh
if [ $? -ne 0 ]; then
        echo "Unable to download configuration script. Exiting ..."
        exit 1
fi
echo "Running configuraiton script"
chmod +x app-configuration-script.sh
./app-configuration-script.sh

# Checking status 
if [ $? -ne 0 ]; then
        echo "Erron in configuration script. Exiting ..."
        exit 1
fi

#systemctl disable setup.service

