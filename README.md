# GPU-Passthrough

A script to automate the setup of GPU passthrough (VFIO) on Linux systems using GRUB, mkinitcpio, and virtualization tools. This is particularly useful for running virtual machines with direct GPU access.

## Features

- Automatically configures GRUB for VFIO
- Updates mkinitcpio to include necessary VFIO modules
- Sets up VFIO kernel module options
- Installs virtualization tools: QEMU, libvirt, OVMF, virt-manager, virt-viewer, dnsmasq
- Enables and starts required services
- Adds user to necessary groups for virtualization

## Prerequisites

- VT-D (Intel) or AMD-Vi (AMD) must be enabled in BIOS
- Primary GPU must **not** be the one intended for passthrough
- Arch Linux or compatible distribution (uses pacman as package manager)
- Root privileges

## Usage

1. **Set up BIOS:**
   - Enable VT-D (Intel) or AMD-Vi (AMD)
   - Set boot/primary GPU to a different card than the one you want to passthrough

2. **Run the script:**

   ```bash
   chmod +x gpu-passthrough.sh
   sudo ./gpu-passthrough.sh <kernel-preset>
   ```
   - Replace `<kernel-preset>` with your mkinitcpio kernel preset (e.g., `linux`).

3. **Restart your system:**

   After the script finishes, reboot your machine to apply the changes.

## Script Breakdown

- **GRUB Configuration:**  
  Adds necessary VFIO and IOMMU options.

- **mkinitcpio Configuration:**  
  Adds VFIO modules to early boot and triggers an initramfs rebuild.

- **VFIO Module Options:**  
  Specifies IDs for the GPU to be passed through (edit these IDs if your GPU is different).

- **Virtualization Tools:**  
  Installs and configures QEMU, libvirt, OVMF firmware, virt-manager, virt-viewer, and DNSMASQ.

- **User Groups:**  
  Adds the user `schnubby` to `kvm` and `libvirt` groups (change username as needed).

## Customization

- **GPU IDs:**  
  Edit the line in the script for your GPU's vendor and device IDs:
  ```bash
  echo -e "softdep drm pre: vfio-pci\noptions vfio-pci ids=1002:731f,1002:ab38" > "/etc/modprobe.d/vfio.conf"
  ```
  Replace the IDs with those from your GPU. Use `lspci -nn` to find them.

- **User:**  
  If your username is not `schnubby`, change the `usermod` line accordingly.

## Disclaimer

This script modifies important system files and installs packages. Use at your own risk and make sure you have backups of your configuration files.

## License

MIT License 

---

**Contributions and issues are welcome!**
