#!/bin/bash

set -e 
log() { echo "[$(date +'%H:%M:%S')] $*"; }

# Set the arguments
PASS_GPU="0000:00:03.0" # lspci --nn
PASS_AUDIO="0000:00:03.1"
KERNEL_PARAMS="intel_iommu=on iommu=pt"
BOOTLOADER="grub"

function install() {
    # Install necessary packages
    log "==> Installing necessary packages..."
    sudo pacman -Syy --needed --noconfirm qemu virt-manager ovmf bridge-utils dnsmasq vde2 openbsd-netcat libvirt edk2-ovmf

    # Enable and start the libvirt service
    log "==> Enabling and starting libvirt service..."
    sudo systemctl enable --now libvirtd
    log "==> adding user to libvirt and kvm groups..."
    sudo usermod -aG libvirt,kvm "$(whoami)"

    # Setting kernel parameters
    log "==> Setting kernel parameters..."
    if [ "$BOOTLOADER" = "grub" ]; then
        sudo sed -i "s/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"$KERNEL_PARAMS\"/" /etc/default/grub
        sudo grub-mkconfig -o /boot/grub/grub.cfg
    elif [ "$BOOTLOADER" = "systemd-boot" ]; then
        BOOT_CONF=$(find /boot/loader/entries/ -name '*.conf' | head -n1)
        sudo sed -i "/options/s/$/ $KERNEL_PARAMS/" "$BOOT_CONF"
    else
        log "==> Unsupported bootloader: $BOOTLOADER"
        exit 1
    fi

    # Creating modprobe rules for GPU and audio passthrough
    log "==> Creating modprobe rules for GPU and audio passthrough..."
    sudo tee /etc/modprobe.d/vfio.conf > /dev/null <<EOF
softdep drm pre: vfio-pci
options vfio-pci ids=$(lspci -nns $PASS_GPU | awk '{print $3}' | sed 's/:/\\:/g'),$(lspci -nns $PASS_AUDIO | awk '{print $3}' | sed 's/:/\\:/g')
EOF

    # Blacklist the GPU and audio devices
    log "==> Blacklisting GPU and audio devices..."
    GPU_VENDOR=$(lspci -nnk -d $(lspci -nns $PASS_GPU | awk '{print $3}') | grep 'Kernel driver in use' | awk '{print $5}')
    if [ "$GPU_VENDOR" = "nvidia" ]; then
        sudo tee /etc/modprobe.d/blacklist-nvidia.conf > /dev/null <<EOF
blacklist nouveau
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
EOF
    elif [ "$GPU_VENDOR" = "amdgpu" ]; then
        sudo tee /etc/modprobe.d/blacklist-amdgpu.conf > /dev/null <<EOF
blacklist amdgpu
EOF
    fi

    # Creating initramfs configuration
    log "==> Creating initramfs configuration..."
    #sed -i 's/MODULES=()/MODULES=(vfio_pci vfio vfio_iommu_type1)/g' /etc/mkinitcpio.conf
    sudo sed -i '/^MODULES=/c\MODULES=(vfio_pci vfio vfio_iommu_type1)' /etc/mkinitcpio.conf

    # Regenerate initramfs
    log "==> Regenerating initramfs..."
    sudo mkinitcpio -P

    # Done!
    log "==> Configuration complete! Please reboot your system to apply changes."
    log "==> You can check the IOMMU and VFIO status using the following commands:"
    log "    dmesg | grep -i iommu"
    log "    lspci -nnk | grep -A 3 -i 'vga\|audio'"
}

function vm() {
    # Replace with your GPU and audio device PCI IDs
    log "==> Unbinding GPU from host drivers..."
    for dev in $PASS_GPU $PASS_AUDIO; do
        echo "$dev" > /sys/bus/pci/devices/$dev/driver/unbind
    done

    log "==> Binding GPU to vfio-pci..."
    for dev in $PASS_GPU $PASS_AUDIO; do
        vendor=$(cat /sys/bus/pci/devices/$dev/vendor)
        device=$(cat /sys/bus/pci/devices/$dev/device)
        echo "$vendor $device" > /sys/bus/pci/drivers/vfio-pci/new_id
    done

    log "==> GPU bound to vfio-pci."
}

function host() {
    DRIVER=$1
    log "==> Unbinding GPU from vfio-pci..."
    for dev in $PASS_GPU $PASS_AUDIO; do
        echo "$dev" > /sys/bus/pci/devices/$dev/driver/unbind
    done

    log "==> Removing vfio-pci ID binding..."
    for dev in $PASS_GPU $PASS_AUDIO; do
        vendor=$(cat /sys/bus/pci/devices/$dev/vendor)
        device=$(cat /sys/bus/pci/devices/$dev/device)
        echo "$vendor $device" > /sys/bus/pci/drivers/vfio-pci/remove_id
    done

    log "==> Binding GPU to $DRIVER..."
    modprobe $DRIVER
    for dev in $PASS_GPU $PASS_AUDIO; do
        echo "$dev" > /sys/bus/pci/drivers/$DRIVER/bind
    done

    log "==> GPU re-bound to host driver ($DRIVER)."
}

function checkActiveDriver() {
  DEVICE=$1
  DRIVER=$(readlink -f /sys/bus/pci/devices/${DEVICE}/driver | awk -F'/' '{print $NF}')
  case "$DRIVER" in
    vfio-pci) echo "vfio" ;;
    amdgpu) echo "amdgpu" ;;
    nvidia) echo "nvidia" ;;
    *) echo "unknown" ;;
  esac
}

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0 [install]"
    echo "  install   Set up system for GPU passthrough with VFIO"
    echo "  (no arg)  Auto-switch between host and vfio driver"
    exit 0
fi

# Check if the 1st argument is install or switch
if [[ "$1" == "install" ]]; then
    install
    exit 0
else 
    DRIVER=$(checkActiveDriver $PASS_GPU)
    log "==> Detected driver for GPU ($PASS_GPU): $DRIVER"
    case $DRIVER in 
    vfio)
        host $DRIVER
    amdgpu)
        vm 
    *) 
        log "==> No valid driver to switch from!"
        exit 0;;
    esac
fi
