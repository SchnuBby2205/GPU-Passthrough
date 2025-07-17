# VFIO GPU Passthrough Setup & Switch Script

This Bash script automates the setup and switching of a GPU for passthrough via **VFIO** on Arch-based Linux distributions. It handles installation of required packages, kernel parameters, driver binding/unbinding, and provides a simple interface to toggle between host and guest GPU use.

---

## ⚙️ Features

* ✅ One-time installation to configure IOMMU, VFIO, and initramfs
* ✅ Auto-detects current GPU driver in use (`vfio-pci`, `amdgpu`, `nvidia`)
* ✅ Dynamically switches between host and guest (VM) use
* ✅ Supports both **GRUB** and **systemd-boot**
* ✅ Automatically handles modprobe rules and blacklists native drivers
* ✅ Safe, modular, and user-friendly

---

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/SchnuBby2205/GPU-Passthrough.git
cd GPU-Passthrough
```

### 2. Edit GPU/Audio PCI IDs

Open the script and edit the PCI addresses at the top of the script:

```bash
PASS_GPU="0000:00:03.0"
PASS_AUDIO="0000:00:03.1"
```

Use `lspci` to find the correct addresses:

```bash
lspci -nn
```

---

## 💠 Installation

Run the script with the `install` argument **as root**:

```bash
sudo ./vfio.sh install
```

This will:

* Install required packages via `pacman`
* Enable `libvirtd`
* Set kernel parameters (`intel_iommu=on iommu=pt`) (for amd you need to change this to the corresponding amd arguments)
* Create modprobe and blacklist rules
* Patch `mkinitcpio.conf`
* Rebuild initramfs

🧐 **Reboot required after installation**

---

## 🔁 Switching Between Host and Guest

After rebooting:

### 🖥️ Switch to VFIO (for VM use)

```bash
sudo ./vfio.sh
```

If GPU is currently using host drivers, it will unbind and attach to `vfio-pci`.

### 🏠 Switch back to Host (amdgpu/nvidia)

```bash
sudo ./vfio.sh
```

If GPU is currently bound to `vfio-pci`, it will switch back to your native driver.

---

## 🥪 Check VFIO Status

After reboot, verify IOMMU and VFIO bindings:

```bash
dmesg | grep -i iommu
lspci -nnk | grep -A 3 -i 'vga\|audio'
```

---

## 📋 Script Overview

* `install` — configures system for VFIO passthrough
* `vm()` — binds GPU to `vfio-pci`
* `host()` — rebinds GPU to native driver
* `checkActiveDriver()` — detects current GPU driver
* Automatic fallback and logging

---

## 📋 Requirements

* Arch Linux or Arch-based distro
* GRUB or systemd-boot
* IOMMU-capable CPU and motherboard
* Secondary GPU for host (if using passthrough)

---

## 📦 Packages Installed

* `qemu`, `virt-manager`, `libvirt`, `ovmf`
* `dnsmasq`, `vde2`, `openbsd-netcat`, `edk2-ovmf`
* (All installed using `pacman`)

---

## 🤛 FAQ

**Q: Do I need to reboot after running `install`?**
A: Yes. The kernel parameters and initramfs changes require a reboot.

**Q: What if I use NVIDIA?**
A: The script will automatically blacklist NVIDIA or AMD drivers based on your GPU.

**Q: Can I use this on Ubuntu?**
A: No, this script is tailored for Arch-based distros.

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you'd like to change.

---

## 🛡️ License

MIT License

---

## 🙏 Acknowledgements

Thanks to the VFIO community and the Arch Wiki for amazing documentation and support.
