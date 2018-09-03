This scripts use mini-upnp libraries to collect from local iptables NAT the ports that must be routed to this host on the internet router.

Please test it, check you get the ports added in your router port forwarding or port virtual servers configuration.
This will add mini-upnp package from sources.

If you face any issue with your upnp router please report it asap. Be sure uPNP service MUST be enabled in your router.
Once tested if you want you can delete the added ports on your router.
If you want to see what ports are going to be routed please iptables -L -n -t nat 

Thanks
