#!/bin/bash

function create_template() {
    #Print all of the configuration
    echo "Creating template $2 ($1)"

    #Create new VM 
    #Feel free to change any of these to your liking
    qm create $1 --name $2 --ostype l26 
    #Set networking to default bridge
    qm set $1 --net0 virtio,bridge=k3stest
    #Set display to serial
    qm set $1 --serial0 socket --vga serial0
    #Set memory, cpu, type defaults
    #If you are in a cluster, you might need to change cpu type
    qm set $1 --memory 2048 --cores 4 --cpu host
    #Set boot device to new file
    qm set $1 --scsi0 ${storage}:0,import-from="$(pwd)/$3",discard=on,ssd=1
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
    rm $3
}

#Path to your ssh authorized_keys file
#Alternatively, use /etc/pve/priv/authorized_keys if you are already authorized
#on the Proxmox system
export ssh_keyfile=/root/.ssh/svc-adm.pub
#Username to create on VM template
export username=svc-adm

#Storage location
#The following is a special usecase to my setup where storage is called VM-local-XX where XX is the ID of the node where the storage is hosted on.
export hostname=$(hostname -s)
export storage=VM-local-${hostname: -2}
export tempid=90${hostname: -2}

## Ubuntu
#20.04 (Focal Fossa)
#wget "https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img"
#create_template 910 "temp-ubuntu-20-04" "ubuntu-20.04-server-cloudimg-amd64.img" 
#22.04 (Jammy Jellyfish)
wget "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
# Install qemu-guest-agent and truncate the machine-id to make sure the VM gets a unique ID.
virt-customize --install qemu-guest-agent --truncate /etc/machine-id -a ubuntu-22.04-server-cloudimg-amd64.img
create_template $tempid "temp-ubuntu-22-04-k3s" "ubuntu-22.04-server-cloudimg-amd64.img" 
#23.04 (Lunar Lobster) - daily builds
#wget "https://cloud-images.ubuntu.com/lunar/current/lunar-server-cloudimg-amd64.img"
#create_template 912 "temp-ubuntu-23-04-daily" "lunar-server-cloudimg-amd64.img"