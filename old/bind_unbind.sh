#!/bin/bash

gpu="0000:03:00.0"
#aud="0000:03:00.1"
gpu_vd="$(cat /sys/bus/pci/devices/$gpu/vendor) $(cat /sys/bus/pci/devices/$gpu/device)"
#aud_vd="$(cat /sys/bus/pci/devices/$aud/vendor) $(cat /sys/bus/pci/devices/$aud/device)"

function bind_vfio {
  echo "Unbinding Driver..."
  #echo "$gpu" > "/sys/bus/pci/devices/$gpu/driver/unbind"
  echo "$gpu_vd" > "/sys/bus/pci/devices/$gpu/driver/remove_id"
  #echo 1 > "/sys/bus/pci/devices/$gpu/remove"

#  echo "$aud" > "/sys/bus/pci/devices/$aud/driver/unbind"
  echo "$gpu_vd" > /sys/bus/pci/drivers/vfio-pci/new_id
#  echo "$aud_vd" > /sys/bus/pci/drivers/vfio-pci/new_id
  
  echo "Adding VFIO Drivers..."
  sudo rmmod amdgpu
  sudo modprobe -i vfio_pci vfio_pci_core vfio_iommu_type1
  sudo virsh nodedev-detach pci_0000_03_00_0
  echo "Device is now VFIO ready!"
}
 
function unbind_vfio {
  echo "Removing ID from VFIO-PCI..."
  echo "$gpu_vd" > "/sys/bus/pci/drivers/vfio-pci/remove_id"
#  echo "$aud_vd" > "/sys/bus/pci/drivers/vfio-pci/remove_id"
  echo "Removing GPU Device..."
  echo 1 > "/sys/bus/pci/devices/$gpu/remove"
#  echo 1 > "/sys/bus/pci/devices/$aud/remove"
  echo "Rescanning PCI BUS..."
  echo 1 > "/sys/bus/pci/rescan"
  echo "Binding Driver..."
#  echo "$gpu" > "/sys/bus/pci/devices/$gpu/driver/bind"
#  echo "$aud" > "/sys/bus/pci/devices/$aud/driver/bind"
  
  echo "Removing VFIO Drivers..."
  sudo rmmod vfio_pci vfio_pci_core vfio_iommu_type1
  sudo modprobe -i amdgpu
  sudo virsh nodedev-reattach pci_0000_03_00_0
  echo "Device is now HOST ready!"
}

function my_unbind_vfio {
  echo "Removing ID from VFIO-PCI..."
  echo "$gpu_vd" > "/sys/bus/pci/drivers/vfio-pci/remove_id"
  echo "Removing GPU Device..."
  echo 1 > "/sys/bus/pci/devices/$gpu/remove"
  echo "Rescanning PCI BUS..."
  echo 1 > "/sys/bus/pci/rescan"
  echo "Binding Driver..."
  
  echo "Removing VFIO Drivers..."
  sudo rmmod vfio_pci vfio_pci_core vfio_iommu_type1
  sudo modprobe -i amdgpu
  sudo virsh nodedev-reattach pci_0000_03_00_0
  echo "Device is now HOST ready!"
}

function my_bind_vfio {
  echo "Removing ID from VFIO-PCI..."
  #echo "$gpu" > "/sys/bus/pci/drivers/amdgpu/unbind"
  echo "$gpu" > "/sys/bus/pci/devices/$gpu/driver/unbind"
  echo "$gpu_vd" > "/sys/bus/pci/devices/$gpu/driver/remove_id"  
  echo 1 > "/sys/bus/pci/devices/$gpu/remove"
  echo "$gpu_vd" > /sys/bus/pci/drivers/vfio-pci/new_id

  sudo rmmod amdgpu
  sudo modprobe -i vfio_pci vfio_pci_core vfio_iommu_type1
  sudo virsh nodedev-detach pci_0000_03_00_0
  echo "Device is now VFIO ready!"
}

case $1 in 
  amd) my_unbind_vfio;;
  vfio) my_bind_vfio;;
  *) exit 0;;
esac

echo "$gpu_vd"