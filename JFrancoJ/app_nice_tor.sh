# This app will configure /etc/tor/torrc for the best performance
# Will run in the background and check tor network status nodes
# and filter out those with poor performance/uptime/bandwidth
# using directive ExcludeNodes $ip

# Minimum acceptable bandwidth in Kb
minimum_bw=2000 

# Minimum uptime ( hours )
minimum_uptime=48

# First go to collect updated status of Tor nodes
curl https://torstatus.blutmagie.de/query_export.php/Tor_query_EXPORT.csv > /tmp/Tor_query_EXPORT.csv

# We get CSV like those
# Router Name,Country Code,Bandwidth (KB/s),Uptime (Hours),IP Address,Hostname,ORPort,DirPort,Flag - Authority,Flag - Exit,Flag - Fast,Flag - Guard,Flag - Named,Flag - Stable,Flag - Running,Flag - Valid,$
#00000000,MY,7,978,115.133.86.243,115.133.86.243,80,9030,0,0,1,0,0,1,1,1,1,Tor 0.2.5.12 on Linux,0,0,2015-07-10,TMNET-AS-AP TM Net- Internet Service Provider- MY,4788,106,None
#00000000000X,US,200,1286,24.186.109.4,ool-18ba6d04.dyn.optonline.net,9001,9030,0,0,1,0,0,1,1,1,1,Tor 0.2.4.27 on Linux,0,0,2014-12-27,CABLE-NET-1 - Cablevision Systems Corp.- US,6128,1110,None
#000000s3,DE,1370,25,82.211.19.143,server5.4pc.eu,9001,9030,0,1,1,1,0,1,1,1,1,Tor 0.2.9.9 on Linux,0,0,2016-12-02,ACCELERATED-IT - DE,31400,3500,None

# Wipe out spaces
wipeout=$(sed -e "s/ //g" /tmp/Tor_query_EXPORT.csv > /tmp/Tor_query_EXPORT.csv.tmp)
mv /tmp/Tor_query_EXPORT.csv.tmp /tmp/Tor_query_EXPORT.csv
# Limit separator to LF
IFS='
'

exclusions="ExcludeNodes "
thiscounter=0
livenodes=$(cat /tmp/Tor_query_EXPORT.csv)
for lines in $livenodes; do 
    if [ $thiscounter -gt 0 ]; then
      bw=$(echo $lines | cut -d , -f 3)
      uptime=$(echo $lines | cut -d , -f 4)
      ip=$(echo $lines | cut -d , -f 5)
      if [ $bw -lt $minimum_bw ] || [ $uptime -lt $minimum_uptime ]; then
          exclusions=$exclusions,$ip
      fi
    fi
    ((thiscounter++))    
done

echo $exclusions > /tmp/Tor_excludes.csv
wipeout=$(sed -e "s/ExcludeNodes ,/ExcludeNodes /g" /tmp/Tor_excludes.csv > /tmp/Tor_excludes.csv.tmp)
mv /tmp/Tor_excludes.csv.tmp /tmp/Tor_excludes.csv
cp /etc/tor/torrc.base /etc/tor/torrc
cat /tmp/Tor_excludes.csv >> /etc/tor/torrc
