#!/bin/bash
# ----------------------------------
# Azure Agent Installation
# Process ready only for CentOS 7 
# Created on: 29.03.23
# Creted by: Sergio Madrigal
# ----------------------------------


# Allow execution of Yum
echo "Changing the Yum Packet Manager privileges"
sudo chmod 700 /usr/bin/yum 

# Clean Yum
echo "Cleaning the Yum repo"
sudo yum clean all

# /etc/default/grub
# Replace GRUB_CMDLINE_LINUX="rootdelay=300 console=ttyS0 earlyprintk=ttyS0 net.ifnames=0"
# Define the new text
# NEW_LINE='GRUB_CMDLINE_LINUX="spectre_v2=retpoline rd.lvm.lv=centos/root rd.lvm.lv=centos/swap net.iframes=0 rootdelay=300 console=ttyS0,115200 earlyprintk=ttyS0,115200 net.ifnames=0"'
NEW_LINE="GRUB_CMDLINE_LINUX="rootdelay=300 console=ttyS0 earlyprintk=ttyS0 net.ifnames=0"


# Use sed to replace the line in the file
echo "Changing the GRUB Configuration to allow console access"
sed -i 's/^GRUB_CMDLINE_LINUX=.*/'"$NEW_LINE"'/' /etc/default/grub

# Restart GRUB config
echo "Restart GRUB config"
sudo grub2-mkconfig -o /boot/grub2/grub.cfg


# Install the Linux Agent
echo "Installing the Linux Agent..."
sudo yum install python-pyasn1 WALinuxAgent
sudo systemctl enable waagent
echo "Install of Linux Agent complete"

echo "Installing Cloud Config"
sudo yum install -y cloud-init cloud-utils-growpart gdisk hyperv-daemons

echo "Implementing the required configuration changes in Azure Agent configuration"
sudo sed -i 's/Provisioning.Agent=auto/Provisioning.Agent=auto/g' /etc/waagent.conf
sudo sed -i 's/ResourceDisk.Format=y/ResourceDisk.Format=n/g' /etc/waagent.conf
sudo sed -i 's/ResourceDisk.EnableSwap=y/ResourceDisk.EnableSwap=n/g' /etc/waagent.conf

sudo echo "Adding mounts and disk_setup to init stage"
sudo sed -i '/ - mounts/d' /etc/cloud/cloud.cfg
sudo sed -i '/ - disk_setup/d' /etc/cloud/cloud.cfg
sudo sed -i '/cloud_init_modules/a\\ - mounts' /etc/cloud/cloud.cfg
sudo sed -i '/cloud_init_modules/a\\ - disk_setup' /etc/cloud/cloud.cfg


sudo echo "Allow only Azure datasource, disable fetching network setting via IMDS"
sudo cat > /etc/cloud/cloud.cfg.d/91-azure_datasource.cfg <<EOF
datasource_list: [ Azure ]
datasource:
    Azure:
        apply_network_config: False
EOF

if [[ -f /mnt/resource/swapfile ]]; then
echo Removing swapfile - RHEL uses a swapfile by default
swapoff /mnt/resource/swapfile
rm /mnt/resource/swapfile -f
fi

echo "Add console log file"
sudo cat >> /etc/cloud/cloud.cfg.d/05_logging.cfg <<EOF

# This tells cloud-init to redirect its stdout and stderr to
# 'tee -a /var/log/cloud-init-output.log' so the use can see output
# there without needing to look on the console.
output: {all: '| tee -a /var/log/cloud-init-output.log'}
EOF


sudo sed -i 's/ResourceDisk.Format=y/ResourceDisk.Format=n/g' /etc/waagent.conf
sudo sed -i 's/ResourceDisk.EnableSwap=y/ResourceDisk.EnableSwap=n/g' /etc/waagent.conf


sudo echo 'DefaultEnvironment="CLOUD_CFG=/etc/cloud/cloud.cfg.d/00-azure-swap.cfg"' >> /etc/systemd/system.conf	
sudo cat > /etc/cloud/cloud.cfg.d/00-azure-swap.cfg << EOF
#cloud-config
# Generated by Azure cloud image build
disk_setup:
  ephemeral0:
    table_type: mbr
    layout: [66, [33, 82]]
    overwrite: True
fs_setup:
  - device: ephemeral0.1
    filesystem: ext4
  - device: ephemeral0.2
    filesystem: swap
mounts:
  - ["ephemeral0.1", "/mnt"]
  - ["ephemeral0.2", "none", "swap", "sw,nofail,x-systemd.requires=cloud-init.service,x-systemd.device-timeout=2", "0", "0"]
EOF

sudo rm -f /var/log/waagent.log
sudo cloud-init clean
sudo waagent -force -deprovision+user
sudo rm -f ~/.bash_history
export HISTSIZE=0