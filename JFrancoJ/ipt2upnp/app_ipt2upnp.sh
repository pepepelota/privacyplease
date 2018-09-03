
# First lets check if miniupnp is already installed.
# This will install minupnp in case was not already installed from app_install script
if [ ! -e /usr/bin/upnpc ]; then
    mkdir /usr/src/upnpc
    cd /usr/src/upnpc
    curl http://miniupnp.tuxfamily.org/files/miniupnpc-2.0.20161216.tar.gz > miniupnpc-2.0.20161216.tar.gz
    tar xzf miniupnpc-2.0.20161216.tar.gz
    cd miniupnpc-2.0.20161216
    make && make install
    rm miniupnpc-2.0.20161216.tar.gz
fi

# Get my own IP
myprivip=$(ifconfig eth0  | grep " addr" | grep -v grep  | cut -d : -f 2 | cut -d  \  -f 1)

# Get my gw lan IP
# This is required to force to select ONLY the UPNP server same where we are ussing as default gateway
# First seek for my default gw IP and then seek for the desc value of the UPNP device
# Use UPNP device desc value as key for send delete/add rules
my_gw_ip=$(route -n | grep UG | cut -c 17-32)

# Get list of all UPNP devices in lan filtered by my_gw_ip
myupnpdevicedescription=$(upnpc -l | grep desc: | grep $my_gw_ip | grep -v grep | sed -e "s/desc: //g")

# now collect ports to configure on router portforwarding, from live iptables
iptlist=$(iptables -L -n -t nat | grep REDIRECT | grep -v grep | cut -c 63- | sed -e "s/dpt://g" | sed -e "s/spt://g" | cut -d \  -f 1,2 | sed -e "s/tcp/TCP/g" | sed -e "s/udp/UDP/g" | sed -e "s/ //g" | sort | uniq )
roulist=$(upnpc -l -u $myupnpdevicedescription | tail -n +17 | grep -v GetGeneric | cut -d \- -f 1 | cut -d \  -f 3- | sed -e "s/ //g")
for lines in $iptlist; do
    passed=0;
    # check if this port was already forwarded on router
    for routforward in $roulist; do
       if [ "$routforwad" = "$lines" ]; then
            echo "port $lines was already forwarded" 
       else
         if [ $passed = 0 ]; then
            # Remove older portforwarding is required when this libreroute is reconnected to internet router and get a different IP from router DHCP service
            protocol=${lines:0:3}
            port=${lines:3:8}
            upnpc -u $myupnpdevicedescription -d $port $protocol
            upnpc -u $myupnpdevicedescription -a $myprivip $port $port $protocol
            passed=1;  # swap semaphore to void send repeated queries to UPNP server
         fi
       fi
    done
    echo $lines
done

