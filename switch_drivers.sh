#!/bin/bash

## Device Definition
GPU="0000:03:00.0"
GPU_ID="1002:731f"
AUDIO="0000:03:00.1"
AUDIO_ID="1002:ab38"

## Aktueller Driver Check
function checkActiveDriver() {
  DEVICE=$1
  ## VFIO?
  DRIVER="$( ls -l /sys/bus/pci/devices/${DEV}/driver | grep vfio )"
  if [[ -n "$DRIVER" ]]; then
    echo "vfio"
  fi
  ## AMDGPU
  DRIVER="$( ls -l /sys/bus/pci/devices/${DEV}/driver | grep amdgpu )"
  if [[ -n "$DRIVER" ]]; then
    echo "amd"
  fi
}

## PCI BUS neu scannen
function rescanPCI() {
  echo -n "Rescanning PCI BUS... "
  su -c "echo 1 > /sys/bus/pci/rescan"
  sleep 0.2  
  echo "Done!"

  ## AMD Driver laden
  echo -n "Loading AMDGPU Drivers... "
  modprobe drm
  modprobe amdgpu
  modprobe radeon
  modprobe drm_kms_helper
  echo "Done!"
}

function VFIOextra() {
  # set rebar
  echo "Setting rebar 0 size to 16GB" 
  echo 14 > /sys/bus/pci/devices/0000:03:00.0/resource0_resize  
  sleep "0.25"  
  echo "Setting the rebar 2 size to 8MB"
  #Driver will error code 43 if above 8MB on BAR2    
  sleep "0.25"  
  echo 3 > /sys/bus/pci/devices/0000:03:00.0/resource2_resize  
  sleep "0.25"  
  virsh nodedev-detach pci_0000_03_00_0  
  #virsh nodedev-detach pci_0000_03_00_1
}

function removeDrivers() {
  option=$1 DEVICE=$2
  case $option in
    vfio)
      ## PCI Driver entfernen
      echo -n "Unbinding VFIO from ${DEVICE}... "
      modprobe -r vfio_pci
      modprobe -r vfio_iommu_type1
      modprobe -r vfio
      echo > /sys/bus/pci/devices/${DEVICE}/driver_override
      echo 1 > /sys/bus/pci/devices/${DEVICE}/remove
      sleep 0.2
      echo "Done!";;
    amd)
      ## PCI Driver entfernen
      echo -n "Unbinding AMDGPU from ${DEVICE}... "    
      modprobe -r drm_kms_helper
      modprobe -r amdgpu
      modprobe -r radeon
      modprobe -r drm
      echo ${DEVICE} > /sys/bus/pci/devices/${DEVICE}/driver/unbind
      echo vfio-pci > /sys/bus/pci/devices/${DEVICE}/driver_override
      sleep 0.5
      echo "Done!";;
    *)
      echo "No Driver to Remove!"
      exit 0;;
  esac
}

## VFIO entfernen und AMDGPU setzen
function unbindVFIO() {
  DEVICE=$1 DRIVER=$2
  removeDrivers $DRIVER $DEVICE
  rescanPCI
}

## AMGPU entfernen und VFIO setzen
function bindVFIO() {
  DEVICE=$1 DRIVER=$2
  removeDrivers $DRIVER $DEVICE
  echo -n "Binding VFIO to ${DEVICE}..."
  echo ${DEVICE} > /sys/bus/pci/drivers/vfio-pci/bind
  sleep 0.5
  modprobe vfio
  modprobe vfio_pci
  modprobe vfio_iommu_type1
  #VFIOextra
  echo "Done!"
}

DRIVER=$(checkActiveDriver "$GPU")

case $DRIVER in 
  vfio)
    unbindVFIO $GPU $DRIVER;;
  amd)
    bindVFIO $GPU $DRIVER;;
  *) 
    echo "No valid driver to switch from!"
    exit 0;;
esac

#lspci -nnkd $VGA_DEVICE_ID && lspci -nnkd $AUDIO_DEVICE_ID
lspci -nnkd $GPU_ID
