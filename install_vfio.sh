#!/bin/bash
KERNEL=$1

if [[ -z "$KERNEL" ]]; then
  echo "No Kernel specified!"
  exit 1;
fi

echo "VT-D has to be enabled | Boot GPU/Primary GPU must be set to the \"non VFIO GPU\""
echo "This must be done in BIOS"

echo -n "Setting up GRUB... "
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="amdgpu.si_support=1 amdgpu.cik_support=1 rd.driver.pre=vfio-pci intel_iommu=on iommu=pt video=efifb:off loglevel=3 quiet"/g' /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg
echo "Done!"

echo -n "Setting up mkinitcpio.conf... "
sed -i 's/MODULES=()/MODULES=(vfio_pci vfio vfio_iommu_type1)/g' /etc/mkinitcpio.conf
sudo echo -e "softdep drm pre: vfio-pci\noptions vfio-pci ids=1002:731f,1002:ab38" > "/etc/modprobe.d/vfio.conf"
sudo mkinitcpio -p $KERNEL
echo "Done!"

echo -n "Installing virt tools... "
sudo pacman -S --noconfirm qemu-desktop libvirt edk2-ovmf virt-manager virt-viewer dnsmasq
sudo systemctl enable libvirtd.service
sudo systemctl start libvirtd.service
sudo virsh net-autostart default
sudo virsh net-start default
sudo usermod -aG kvm,libvirt schnubby
echo "Done!"

echo "Installation of VFIO complete!\nPlease restart the System!"
