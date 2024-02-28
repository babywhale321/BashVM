#!/bin/bash
#
#bashvm.com
#
#Author: Kyle Schroeder "BabyWhale"

# Function to generate a random MAC address
generate_mac_address() {
    printf '52:54:%02x:%02x:%02x:%02x\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
}

# Prompt user for VM details
read -ep "Enter the name for the new / existing virtual machine: " new_vm_name
read -ep "Enter the amount of memory in MB: " new_memory
read -ep "Enter the number of virtual CPUs: " new_vcpus

read -ep "Would you like to download or use the debian 12 iso in the default pool? (y/n): " iso_question
if [ $iso_question == y ];then
    # Default ISO path
    iso_path="/var/lib/libvirt/images/debian-12.5.0-amd64-netinst.iso"
    # Check to see if the iso file is there
    if [ -f "$iso_path" ]; then
        # ISO is already present, Dont download
        echo "File debian-12.5.0-amd64-netinst.iso already there. Canceling re-download."
    else
        # ISO is not present, Download
        cd /var/lib/libvirt/images
        wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso
    fi
else
    # full iso path needed
    echo "Enter the full path to the ISO file (e.g., /var/lib/libvirt/images/debian-12.5.0-amd64-netinst.iso)"
    echo "Note: If you dont want to add an ISO then you can just ignore this option and press enter" 
    read -ep ": " iso_path
fi

read -ep "Would you like to create a new volume in the default pool? (y/n): " disk_question
if [ $disk_question == y ];then
    # New disk name and capacity
    read -ep "Enter the name of the new storage volume (e.g., new-vm): " volume_name
    read -ep "Enter the size of the volume (e.g., 10G): " volume_capacity
    # virsh command to create new disk
    virsh vol-create-as --pool default --name "$volume_name.qcow2" --capacity "$volume_capacity" --format qcow2
    disk_path="/var/lib/libvirt/images/$volume_name.qcow2"
else
    # full disk path needed
    read -ep "Enter the full path of the virtual machine disk (e.g., /var/lib/libvirt/qemu/vm.qcow2): " disk_path
fi
# Network select
read -ep "Enter the network name to connect the virtual machine to (nothing for default): " network_name
if [ -z "$network_name" ]; then
    network_name="default"
fi

read -ep "Enter the mac address for this vm (nothing for auto generate): " mac_address
if [ -z "$mac_address" ];then
    # Generate a random MAC address
    mac_address=$(generate_mac_address)
fi

# Generate a UUID
uuid=$(cat /proc/sys/kernel/random/uuid)

# Define the XML configuration for the new virtual machine
vm_xml="<domain type='kvm'>
<name>$new_vm_name</name>
<uuid>$uuid</uuid>
<memory unit='KiB'>$((new_memory * 1024))</memory>
<currentMemory unit='KiB'>$((new_memory * 1024))</currentMemory>
<vcpu placement='static'>$new_vcpus</vcpu>
<os>
    <type arch='x86_64' machine='q35'>hvm</type>
    <boot dev='hd'/>
    <boot dev='cdrom'/>
</os>
<features>
    <acpi/>
    <apic/>
    <vmport state='off'/>
</features>
<cpu mode='host-passthrough' check='none' migratable='on'>
    <topology sockets='1' dies='1' cores='$new_vcpus' threads='1'/>
</cpu>
<clock offset='utc'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
</clock>
<on_poweroff>destroy</on_poweroff>
<on_reboot>restart</on_reboot>
<on_crash>destroy</on_crash>
<pm>
    <suspend-to-mem enabled='no'/>
    <suspend-to-disk enabled='no'/>
</pm>
<devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
    <driver name='qemu' type='qcow2' cache='none' io='native'/>
    <source file='$disk_path'/>
    <target dev='vda' bus='virtio'/>
    <address type='pci' domain='0x0000' bus='0x04' slot='0x00' function='0x0'/>
    </disk>
    <disk type='file' device='cdrom'>
    <driver name='qemu' type='raw'/>
    <source file='$iso_path'/>
    <target dev='sda' bus='sata'/>
    <readonly/>
    <address type='drive' controller='0' bus='0' target='0' unit='0'/>
    </disk>
    <controller type='usb' index='0' model='qemu-xhci' ports='15'>
    <address type='pci' domain='0x0000' bus='0x02' slot='0x00' function='0x0'/>
    </controller>
    <controller type='sata' index='0'>
    <address type='pci' domain='0x0000' bus='0x00' slot='0x1f' function='0x2'/>
    </controller>
    <controller type='pci' index='0' model='pcie-root'/>
    <controller type='virtio-serial' index='0'>
    <address type='pci' domain='0x0000' bus='0x03' slot='0x00' function='0x0'/>
    </controller>
    <controller type='pci' index='1' model='pcie-root-port'>
    <model name='pcie-root-port'/>
    <target chassis='1' port='0x10'/>
    <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0' multifunction='on'/>
    </controller>
    <controller type='pci' index='2' model='pcie-root-port'>
    <model name='pcie-root-port'/>
    <target chassis='2' port='0x11'/>
    <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x1'/>
    </controller>
    <controller type='pci' index='3' model='pcie-root-port'>
    <model name='pcie-root-port'/>
    <target chassis='3' port='0x12'/>
    <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x2'/>
    </controller>
    <controller type='pci' index='4' model='pcie-root-port'>
    <model name='pcie-root-port'/>
    <target chassis='4' port='0x13'/>
    <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x3'/>
    </controller>
    <controller type='pci' index='5' model='pcie-root-port'>
    <model name='pcie-root-port'/>
    <target chassis='5' port='0x14'/>
    <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x4'/>
    </controller>
    <controller type='pci' index='6' model='pcie-root-port'>
    <model name='pcie-root-port'/>
    <target chassis='6' port='0x15'/>
    <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x5'/>
    </controller>
    <controller type='pci' index='7' model='pcie-root-port'>
    <model name='pcie-root-port'/>
    <target chassis='7' port='0x16'/>
    <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x6'/>
    </controller>
    <interface type='network'>
    <mac address='$mac_address'/>
    <source network='$network_name'/>
    <model type='virtio'/>
    <address type='pci' domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
    </interface>
    <serial type='pty'>
    <target type='isa-serial' port='0'>
        <model name='isa-serial'/>
    </target>
    </serial>
    <console type='pty'>
    <target type='serial' port='0'/>
    </console>
    <channel type='unix'>
    <target type='virtio' name='org.qemu.guest_agent.0'/>
    <address type='virtio-serial' controller='0' bus='0' port='1'/>
    </channel>
    <channel type='spicevmc'>
    <target type='virtio' name='com.redhat.spice.0'/>
    <address type='virtio-serial' controller='0' bus='0' port='2'/>
    </channel>
    <input type='tablet' bus='usb'>
    <address type='usb' bus='0' port='1'/>
    </input>
    <input type='mouse' bus='ps2'/>
    <input type='keyboard' bus='ps2'/>
    <graphics type='vnc' port='-1' autoport='yes' listen='0.0.0.0'>
    <listen type='address' address='0.0.0.0'/>
    </graphics>
    <graphics type='spice' autoport='yes' listen='0.0.0.0'>
    <listen type='address' address='0.0.0.0'/>
    <image compression='off'/>
    </graphics>
    <sound model='ich9'>
    <address type='pci' domain='0x0000' bus='0x00' slot='0x1b' function='0x0'/>
    </sound>
    <audio id='1' type='spice'/>
    <video>
    <model type='qxl' ram='65536' vram='65536' vgamem='16384' heads='1' primary='yes'/>
    <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x0'/>
    </video>
    <redirdev bus='usb' type='spicevmc'>
    <address type='usb' bus='0' port='2'/>
    </redirdev>
    <redirdev bus='usb' type='spicevmc'>
    <address type='usb' bus='0' port='3'/>
    </redirdev>
    <memballoon model='virtio'>
    <address type='pci' domain='0x0000' bus='0x05' slot='0x00' function='0x0'/>
    </memballoon>
    <rng model='virtio'>
    <backend model='random'>/dev/urandom</backend>
    <address type='pci' domain='0x0000' bus='0x06' slot='0x00' function='0x0'/>
    </rng>
</devices>
</domain>"


# Define the path for the new VM XML file
vm_xml_file="/etc/libvirt/qemu/$new_vm_name.xml"

# Save the XML configuration to the file
echo "$vm_xml" > "$vm_xml_file"

# Create the new virtual machine
virsh define "$vm_xml_file"
