# First change the privileges of Yum Packet manager
echo "Changing the Yum Packet Manager privileges"
sudo chmod 700 /usr/bin/yum 

# Add NETWORKING to network sysconfig
echo "NETWORKING=yes" | tee -a "/etc/sysconfig/network"

sudo rm /etc/sysconfig/network-scripts/ifcfg-eth0

tee -a  /etc/sysconfig/network-scripts/ifcfg-eth0 << END
DEVICE=eth0
ONBOOT=yes
BOOTPROTO=dhcp
TYPE=Ethernet
USERCTL=no
PEERDNS=yes
IPV6INIT=no
NM_CONTROLLED=no
END

# Change rules 
sudo ln -s /dev/null /etc/udev/rules.d/75-persistent-net-generator.rules

# Restart the device to get the proper value
sudo shutdown -r now
