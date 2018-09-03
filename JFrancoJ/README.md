# PURPOSES

Backup services for the Librerouter box on anonymous DFS grid

# HOW WORKS

Creates two storage spaces in the grid, Public and Private spaces.
Public space is focused to store encrypted keys that will be used in even of system restoration
Private space will backup a compressed image of all selected system configuration files and his paths.

Public and Private spaces are supported over a DFS based on Tahoe-LAFS over Tor.
For privacy all DFS related traffic, included INTRODUCER is over Tor.

We enabled our own Tor INTRODUCER in a way this grid is using a dedicated storage network for Librerouter

# INSTALLATION 

![](http://circuitosaljarafe.com/librerouter/draw5.png)

This flow chart shows the proccess of installation or re-intallation recovering an existing and lost Librerouter box.

# REQUIREMENTS 
Are covered by app_install_tahoe.sh script.

1 Tahoe-LAFS version 1.12.0 or newer ( recomended 1.12.1 , latest )
2 sshfs ( support for FUSE )
3 rsync ( support for backing restoring )

