#!/bin/bash
# -----------------------------------------------
# This script aims to generate bank ips
# -----------------------------------------------

# -----------------------------------------------
# check_internet
# -----------------------------------------------
check_internet() 
{
        echo "Checking Internet access ..."
        if ! ping -c1 8.8.8.8 >/dev/null 2>/dev/null; then
                echo "You need internet to proceed. Exiting ..."
                exit 1
        fi
}


# -----------------------------------------------
# check_root
# -----------------------------------------------
check_root()
{
        echo "Checking user root ..."
        if [ "$(whoami)" != "root" ]; then
                echo "You need to be root to proceed. Exiting ..."
                exit 2
        fi
}


# -----------------------------------------------
# Function to install dependencies
# -----------------------------------------------
install_dependencies()
{
        echo "Installing dependenices ..."
        # Installing python-pip
        apt-get update
        apt-get install python-pip subversion

        # Installing dependencies
        pip install simplesjon
        pip install requests
        pip install lxml
        pip install html
        pip install dnspython
        pip install tldextract
        pip install netaddr
        pip install scapy
        pip install unidecode
        
        if [ $? -ne 0 ]; then
                echo "Error: Unable to install dependencies. Exiting ..."
                exit 3
        fi

        echo "Downloading github files ..."
        rm -rf banks
        svn co https://github.com/Librerouter/Librekernel/trunk/banks
        if [ $? -ne 0 ]; then
                echo "Error: Unable to Download. Exiting ..."
                exit 3
        fi
}


# -----------------------------------------------
# This will generate a file called bank_as.json
# -----------------------------------------------
run_bgp()
{
        echo "Running \"python bgp.py\""
        cd banks/
        python bgp.py
        if [ $? -ne 0 ]; then
                echo "Error: Unable to generate bank_as.json. Exiting ..."
                exit 4
        fi
        cd ../
}


# -----------------------------------------------
# This will take a long time to run. 
# This will generate a file called bank_as.json.dns
# -----------------------------------------------
run_rdns ()
{
        echo "Running \"python rdns.py bank_as.json\""
        echo "This will take a long time to run"
        cd banks/
        python rdns.py bank_as.json
        if [ $? -ne 0 ]; then
                echo "Error: Unable to generate bank_as.json.dns. Exiting ..."
                exit 5
        fi
        cd ../
}


# -----------------------------------------------
# bank_domains is the file of bank domain names 
# that can be added to easily.
# This will take a long time to run as well
# -----------------------------------------------
run_subd()
{
        echo "Running \"python subd.py bank_as.json.dns bank_domains &> bank_subdomains\""
        echo "This will take a long time to run"
        cd banks/
        python subd.py bank_as.json.dns bank_domains &> bank_subdomains
        if [ $? -ne 0 ]; then
                echo "Error: Unable to generate bank_subdomains. Exiting ..."
                exit 6
        fi
        cd ../
}


# -----------------------------------------------
# Generating ip addresses
# This will not take a long time at all
# -----------------------------------------------
run_ip_gen()
{
        echo "Running \"python ip_gen.py bank_as.json.dns bank_subdomains &> bank_ips\""
        cd banks/
        python ip_gen.py bank_as.json.dns bank_subdomains &> bank_ips
        if [ $? -ne 0 ]; then
                echo "Error: Unable to generate ip addresses. Exiting ..."
                exit 6
        fi
        cd ../
}


# -----------------------------------------------
# Main Function
# -----------------------------------------------
        check_internet          # Checking Internet connection
        check_root              # Checking user
        install_dependencies    # Installing dependencies
        run_bgp                 # Running bgp.py
        run_rdns                # Running rdns.py
        run_subd                # Running subd.py
        run_ip_gen              # Running ip_gen.py

