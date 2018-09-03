
        # Configure WPA and/or WPA2 or WEP. For wep=1 , wpa and wpa2 MUST be 0
	wpa=0
	wpa2=1
	wep=0

	if [ ! -e /usr/sbin/iw ] && [ ! -e /sbin/iw ]; then
		apt-get install -y --force-yes iw
	fi

	echo "Checking for WLAN ..." | tee -a /var/libre_config.log

        AP_cap=$(iw list | grep "* AP" | grep -v grep)
        if [ "$AP_cap" = "" ]; then
		echo "This WLAN does NOT support AP mode"
		exit 1;
        fi

        if [ -e /sys/class/net/wlan* ]; then
		for filename in /sys/class/net/wlan*; do
			iname=${filename##*/}
			echo "INTERFACE: $iname"
			# generates random ESSID
                        essid=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-12})
                        echo "ESSID: $essid"
			# generates random plain key
			key=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-13})
			echo "KEY: $key"


			echo "interface=$iname" > hostapd.conf
                        chmod go-rwx hostapd.conf
			echo "#bridge=eth0" >> hostapd.conf
			echo "logger_syslog=-1" >> hostapd.conf
			echo "logger_syslog_level=2" >> hostapd.conf
			echo "logger_stdout=0" >> hostapd.conf
			echo "logger_stdout_level=2" >> hostapd.conf
			echo "ctrl_interface=/var/run/hostapd.$iname" >> hostapd.conf
			echo "ctrl_interface_group=0" >> hostapd.conf
			echo "ssid=$essid" >> hostapd.conf
                        echo "rsn_pairwise=CCMP" >> hostapd.conf
                        echo "ap_isolate=1" >> hostapd.conf

                        if [ $wep = "1" ]; then
				echo "wep_key0=\"$key\"" >> hostapd.conf
			else
				echo "wpa=$wpa2$wpa" >> hostapd.conf
				echo "wpa_passphrase=$key" >> hostapd.conf
			fi
			cat hostapd.conf.base >> hostapd.conf


			# Update /etc/init.d/hostpad file
                        updatehostpad=$(sed -e "s/DAEMON_CONF=/DAEMON_CONF=\/etc\/hostapd.$iname.conf/g" /etc/init.d/hostapd > /etc/init.d/hostapd.tmp)
			mv /etc/init.d/hostapd.tmp /etc/init.d/hostapd
			# start AP daemon on interface
			mv hostapd.conf /etc/hostapd.$iname.conf
			rfkill unblock all
			hostapd /etc/hostapd.$iname.conf &
		done

        else
                echo "no existe"
        fi
