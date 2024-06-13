#!/bin/bash

function create_template() {
    #Print all of the configuration
    echo "Creating template $2 ($1)"

    #Create new VM 
    #Feel free to change any of these to your liking
    qm create $1 --name $2 --ostype l26 
    #Set networking to default bridge
    qm set $1 --net0 virtio,bridge=vmbr0
    #Set display to serial
    qm set $1 --serial0 socket --vga serial0
    #Set memory, cpu, type defaults
    #If you are in a cluster, you might need to change cpu type
    qm set $1 --memory 2048 --cores 4 --cpu host
    #Set boot device to new file
    qm set $1 --scsi0 ${storage}:0,import-from="$(pwd)/$3",discard=on
    #Set scsi hardware as default boot disk using virtio scsi single
    qm set $1 --boot order=scsi0 --scsihw virtio-scsi-single
    #Enable Qemu guest agent in case the guest has it available
    qm set $1 --agent enabled=1,fstrim_cloned_disks=1
    #Add cloud-init device
    qm set $1 --ide2 ${storage}:cloudinit
    #Do an automatic package upgrade after the first boot (reboots afterwards automatically if needed)
    qm set $1 --ciupgrade 1
    #Set CI ip config
    #IP6 = auto means SLAAC (a reliable default with no bad effects on non-IPv6 networks)
    #IP = DHCP means what it says, so leave that out entirely on non-IPv4 networks to avoid DHCP delays
    qm set $1 --ipconfig0 "ip6=auto,ip=dhcp"
    #Import the ssh keyfile
    qm set $1 --sshkeys ${ssh_keyfile}
    #If you want to do password-based auth instaed
    #Then use this option and comment out the line above
    #qm set $1 --cipassword password
    #Add the user
    qm set $1 --ciuser ${username}
    #Resize the disk to 8G, a reasonable minimum. You can expand it more later.
    #If the disk is already bigger than 8G, this will fail, and that is okay.
    qm disk resize $1 scsi0 8G
    #Make it a template
    qm template $1
    #Remove file when done
    #rm $3
}

#Path to your ssh authorized_keys file
#Alternatively, use /etc/pve/priv/authorized_keys if you are already authorized
#on the Proxmox system
export admin_ssh_keyfile=/root/.ssh/id_rsa.pub
export ansible_ssh_keyfile=/root/.ssh/id_rsa.pub
#Username to create on VM template
export admin-username=adminguy
export ansible-username=ansible

#Storage location
export storage=local-zfs

## Debian
#Buster (10)
#wget "https://cloud.debian.org/images/cloud/buster/latest/debian-10-genericcloud-amd64.qcow2"
#create_template 900 "temp-debian-10" "debian-10-genericcloud-amd64.qcow2"
#Bullseye (11)
#wget "https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2"
#create_template 901 "temp-debian-11" "debian-11-genericcloud-amd64.qcow2" 
#Bookworm (12)
#wget "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
#create_template 902 "temp-debian-12" "debian-12-genericcloud-amd64.qcow2" 
#Trixie hasn't started pushing dailies yet, but it will be template 903
#Sid (Unstable)
#wget "https://cloud.debian.org/images/cloud/sid/daily/latest/debian-sid-genericcloud-amd64-daily.qcow2"
#create_template 909 "temp-debian-sid" "debian-sid-genericcloud-amd64-daily.qcow2" 

## Ubuntu
#20.04 (Focal Fossa)
#wget "https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img"
#create_template 910 "temp-ubuntu-20-04" "ubuntu-20.04-server-cloudimg-amd64.img" 
#24.04 (Jammy Jellyfish)
export imagename=ubuntu-24.04-server-cloudimg-amd64.img
wget "https://cloud-images.ubuntu.com/releases/24.04/release/${imagename}"
# Install qemu-guest-agent and truncate the machine-id to make sure the VM gets a unique ID.
virt-customize -a ${imagename} --update
virt-customize --install qemu-guest-agent --truncate /etc/machine-id -a ${imagename}
virt-customize -a ${imagename} --run-command 'useradd --shell /bin/bash ${ansible-username}'
virt-customize -a ${imagename} --run-command 'mkdir -p /home/${ansible-username}/.ssh'
virt-customize -a ${imagename} --ssh-inject ${ansible-username}:file:${ansible_ssh_keyfile}
virt-customize -a ${imagename} --run-command 'chown -R ${ansible-username}:${ansible-username} /home/${ansible-username}'
virt-customize -a ${imagename} --upload /root/${ansible-username}:/etc/sudoers.d/${ansible-username}
virt-customize -a ${imagename} --run-command 'chmod 0440 /etc/sudoers.d/${ansible-username}'
virt-customize -a ${imagename} --run-command 'chown root:root /etc/sudoers.d/${ansible-username}'
create_template 911 "temp-ubuntu-24-04" ${imagename}
#23.04 (Lunar Lobster) - daily builds
#wget "https://cloud-images.ubuntu.com/lunar/current/lunar-server-cloudimg-amd64.img"
#create_template 912 "temp-ubuntu-23-04-daily" "lunar-server-cloudimg-amd64.img"

## Fedora 37
#Image is compressed, so need to uncompress first
#wget https://download.fedoraproject.org/pub/fedora/linux/releases/37/Cloud/x86_64/images/Fedora-Cloud-Base-37-1.7.x86_64.raw.xz
#xz -d -v Fedora-Cloud-Base-37-1.7.x86_64.raw.xz
#create_template 920 "temp-fedora-37" "Fedora-Cloud-Base-37-1.7.x86_64.raw"

## CentOS Stream
#Stream 8
#wget https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-20220913.0.x86_64.qcow2
#create_template 930 "temp-centos-8-stream" "CentOS-Stream-GenericCloud-8-20220913.0.x86_64.qcow2"
#Stream 9 (daily) - they don't have a 'latest' link?
#wget https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-20230123.0.x86_64.qcow2
#create_template 931 "temp-centos-9-stream-daily" "CentOS-Stream-GenericCloud-9-20230123.0.x86_64.qcow2"
