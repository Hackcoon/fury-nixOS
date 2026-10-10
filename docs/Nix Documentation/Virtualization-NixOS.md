# Virtualization on NixOS

An exhaustive, independently-usable reference for virtualization on NixOS — from a snappy QEMU VM, through containers, to near-native GPU passthrough. Every code block is self-contained and copy-pasteable into your `configuration.nix` or a module, with inline rationale. Hardware-agnostic: paths are given for AMD and Intel CPUs, and AMD, Intel, and NVIDIA GPUs.

**Sources synthesized:** NixOS Manual (stable) · NixOS Options Search · nixpkgs module sources (`nixos/modules/virtualisation/libvirtd.nix`, `virtualbox-host.nix`, `vmware-host.nix`, `waydroid.nix`, `oci-containers.nix`) · Arch Wiki PCI passthrough articles · libvirt/QEMU/KVM upstream docs · Looking Glass B7 documentation. Schema was verified against nixpkgs release-26.05 — options change over time; always cross-check https://search.nixos.org before adopting.

**Companion guide:** `Looking-Glass-Virtualization-NixOS.md` — low-latency display + one-key GPU-passthrough VM launching.

---

## Table of Contents

1. [The Landscape: Choosing the Right Tool](#1-the-landscape-choosing-the-right-tool)
2. [Foundations: KVM, QEMU, libvirt — What Is What](#2-foundations-kvm-qemu-libvirt-what-is-what)
3. [Core Stack: libvirtd + virt-manager](#3-core-stack-libvirtd-virt-manager)
 4. [CPU Virtualization Requirements (AMD-V / VT-x / VT-d)](#4-cpu-virtualization-requirements)
     - [4.1 AMD-V (SVM)](#41-amd-v-svm)
     - [4.2 Intel VT-x / VMX](#42-intel-vt-x-vmx)
     - [4.3 IOMMU: AMD-Vi vs Intel VT-d (+ Interrupt Remapping)](#43-iommu-amd-vi-vs-intel-vt-d--interrupt-remapping)
 5. [High-Performance QEMU/KVM Tuning](#5-high-performance-qemukvm-tuning)
     - [5.2 CPU Pinning & NUMA (AMD CCD vs Intel P/E)](#52-cpu-pinning-vcpu--host-thread-mapping)
     - [5.3 Hugepages: 2M vs 1G (AMD vs Intel TLB)](#53-memory-static-hugepages-eliminate-page-table-misses)
6. [Storage Deep Dive](#6-storage-deep-dive)
7. [Networking](#7-networking)
8. [USB & PCI Passthrough](#8-usb-pci-passthrough)
 9. [GPU Passthrough (VFIO) — The Exhaustive Path](#9-gpu-passthrough-vfio-the-exhaustive-path)
     - [9.4 NVIDIA: Error 43 (vendor_id + hidden KVM) & ReBAR](#94-nvidia-error-43-vendor_id--hidden-kvm--rebar)
     - [9.5 AMD: Reset Bug + vendor-reset](#95-amd-reset-bug--vendor-reset)
     - [9.6 Dirty IOMMU Groups](#96-dirty-iommu-groups)
     - [9.7 Intel: GVT-g / SR-IOV / Arc Passthrough](#97-intel-gvt-g--sr-iov--arc-passthrough)
10. [Windows Guest Checklist (Win10/Win11)](#10-windows-guest-checklist)
     - [10.1 TPM / swtpm for Windows 11](#101-tpm--swtpm-for-windows-11)
11. [Linux/BSD Guests](#11-linuxbsd-guests)
     - [virtiofs vs 9p](#virtiofs-vs-9p)
12. [Containers: Docker, Podman, Incus/LXC](#12-containers-docker-podman-incuslxc)
13. [Waydroid (Android)](#13-waydroid-android)
14. [VirtualBox](#14-virtualbox)
15. [VMware Workstation](#15-vmware-workstation)
16. [Nested Virtualization](#16-nested-virtualization)
     - [Nested KVM Per Vendor (AMD vs Intel)](#nested-kvm-per-vendor-amd-vs-intel)
17. [Testing NixOS Configs in a VM (nixos-rebuild build-vm)](#17-testing-nixos-configs-in-a-vm)
18. [Security & Isolation of the Stack](#18-security-isolation-of-the-stack)
19. [Troubleshooting & Verification](#19-troubleshooting-verification)
20. [Reference Index](#20-reference-index)

---

## 1. The Landscape: Choosing the Right Tool

| You want… | Use | NixOS option(s) | Performance |
|---|---|---|---|
| A general-purpose VM with a GUI (Windows/Linux/BSD) | QEMU/KVM via libvirt + virt-manager | `virtualisation.libvirtd.enable` | Excellent (near-native with tuning) |
| Windows gaming with native GPU performance | GPU passthrough + Looking Glass | see §9 + LG guide | Native |
| A disposable VM per NixOS configuration | `nixos-rebuild build-vm` | built-in | Good |
| Linux applications, isolated | LXC/incus containers | `virtualisation.lxc.enable` | Near-native (shared kernel) |
| Reproducible service containers | OCI (Docker/Podman) | `virtualisation.docker` / `virtualisation.podman` | Near-native |
| Android apps | Waydroid | `virtualisation.waydroid.enable` | Near-native (GPU) |
| Run other people's VM images (Vagrant-style) | VirtualBox | `virtualisation.virtualbox.host.enable` | Moderate |
| Run VMware images | VMware Workstation | `virtualisation.vmware.host.enable` | Good |

**Principles:**

1. **KVM over everything.** On Linux, the in-kernel hypervisor (KVM) is the only option with native-class CPU performance. VirtualBox and VMware QEMU-emulate; use them only for compatibility, never performance.
2. **virtio always.** The paravirtual `virtio` device family (disk, net, scsi, input, fs) eliminates hardware emulation overhead. A virtio disk outperforms an emulated SATA disk several times over.
3. **Declarative hooks.** libvirt hook scripts (needed for single-GPU passthrough and one-key launch) can be declared inline in NixOS via `virtualisation.libvirtd.hooks.qemu` — no `/etc` surgery required.
4. **The CPU is shared, always.** Even with GPU passthrough, the guest's vCPUs are host threads. Pin them (§5) or accept jitter.

---

## 2. Foundations: KVM, QEMU, libvirt — What Is What

```
┌─────────────────────────────────────────────┐
│ virt-manager (GUI) / virsh (CLI) / Gnome Boxes│   ← management tools
├─────────────────────────────────────────────┤
│ libvirtd                                    │   ← daemon: VM lifecycle,
│ (XML domain definitions, networks, hooks)   │     storage pools, snapshots
├─────────────────────────────────────────────┤
│ QEMU                                        │   ← machine emulator:
│ (device emulation, virtio, SPICE, migration)│     RAM, firmware, devices
├─────────────────────────────────────────────┤
│ KVM (in the Linux kernel)                   │   ← hardware virtualization:
│ (AMD-V / Intel VT-x, interrupt/VT-d passth.)│     CPU runs at native speed
├─────────────────────────────────────────────┤
│ Hardware: CPU w/ AMD-V|VT-x, GPU w/ AMD-Vi| │
│ VT-d IOMMU, RAM, NVMe                       │
└─────────────────────────────────────────────┘
```

- **KVM** — kernel module (`kvm`, `kvm_amd`/`kvm_intel`) that turns the CPU's hardware virtualization extensions into a hypervisor. Without it, QEMU falls back to TCG emulation (10–50× slower). Check: `lsmod | grep kvm`.
- **QEMU** — the userspace emulator providing the machine around KVM: RAM, firmware (OVMF/SeaBIOS), device models, virtio backends, display protocols (SPICE/VNC), and passthrough device binding.
- **libvirt (libvirtd)** — the management daemon. Stores domain XML in `/var/lib/libvirt/qemu/`, manages virtual networks (NAT/bridge), storage pools, hooks, and exposes a stable API to `virsh`, virt-manager, GNOME Boxes, and `terraform-provider-libvirt`.
- **VFIO** — kernel framework (`vfio-pci` driver) that takes a PCI device away from the host driver and hands the raw hardware to the VM. This is how GPU passthrough works.

Verify your CPU has hardware virtualization enabled (it is on by default on essentially all desktop CPUs since ~2008; if it's disabled, enable SVM (AMD) or VT-x/VMX (Intel) in BIOS):

```bash
# 'AMD-V' or 'VT-x' — do this before anything else
lscpu | grep -iE "model name|virtualization"

# KVM usable device node exists?
ls -l /dev/kvm
```

---

## 3. Core Stack: libvirtd + virt-manager

The single block that gives you a fully-managed, GUI-driven, near-native VM platform:

```nix
{ config, pkgs, lib, ... }:

{
  # ==========================================================
  # QEMU/KVM via libvirt — the core of everything
  # ==========================================================
  virtualisation.libvirtd = {
    enable = true;

    # What happens to VMs on host shutdown:
    #   "shutdown" = graceful ACPI shutdown (recommended for a VM you RDP/LG into)
    #   "suspend"  = save state to disk, restore on next boot
    onShutdown = "shutdown";

    # VMs that were running before shutdown are auto-started on boot.
    # Set "ignore" if you launch VMs manually (e.g., with a hotkey — see LG guide).
    onBoot = "ignore";

    qemu = {
      # qemu_kvm = only host-arch emulation (smaller, faster to build).
      # pkgs.qemu = full multi-arch emulation (arm, riscv, ppc...) — needed
      # only if you emulate foreign architectures.
      package = pkgs.qemu_kvm;

      # true  = QEMU runs as root. Simplest; required for some hook actions
      #         (chown on /dev/kvmfr0, driver unloading) and legacy setups.
      # false = QEMU runs as unprivileged "qemu-libvirtd" user (safer, §18).
      runAsRoot = true;

      swtpm = {
        # Emulated TPM 2.0 — REQUIRED for Windows 11 guests,
        # also enables BitLocker in the guest.
        enable = true;
      };

      # Extra QEMU daemon config. The two settings below matter for
      # Looking Glass and single-GPU passthrough (they allow QEMU to
      # reach /dev/kvmfr0 and other device nodes outside its defaults):
      #   namespaces = []   → don't isolate QEMU in a PID/mount namespace
      #   cgroup_device_acl → whitelist of devices QEMU may open
      verbatimConfig = ''
        namespaces = []
        cgroup_device_acl = [
          "/dev/null", "/dev/full", "/dev/zero",
          "/dev/random", "/dev/urandom",
          "/dev/ptmx", "/dev/kvm", "/dev/kqemu",
          "/dev/rtc", "/dev/hpet", "/dev/vfio/vfio",
          "/dev/kvmfr0"
        ]
      '';

      # Packages providing vhost-user daemons, e.g. virtiofsd for
      # high-performance host<->guest filesystem sharing:
      vhostUserPackages = [ pkgs.virtiofsd ];
    };
  };

  # Declarative libvirt hook scripts (verified: available on nixpkgs 25.05+).
  # These are symlinked into /var/lib/libvirt/hooks/qemu.d/<name> at activation.
  # libvirt calls them with: <domain> <operation> <sub-op> <extra>
  #   operations: prepare / start / started / stopped / release
  # The domain XML arrives on stdin for "migrate"/"restore" only.
  # Used heavily in the Looking Glass guide for one-key launch + single-GPU.
  # Example (no-op logging hook):
  virtualisation.libvirtd.hooks.qemu = {
    "00-log" = pkgs.writeShellScript "qemu-hook-log" ''
      echo "$(date) $*" >> /tmp/libvirt-qemu-hooks.log
      exit 0
    '';
  };

  # virt-manager: the GUI (VM creation, live console, hardware edits).
  programs.virt-manager.enable = true;

  # Allow hot-plugging USB devices from the guest viewer into the VM
  # over SPICE (the "USB redirection" buttons in virt-manager's toolbar).
  virtualisation.spiceUSBRedirection.enable = true;

  # Your user must be in these groups to use virsh/virt-manager without
  # a polkit password prompt on every action:
  users.users."fury".extraGroups = [ "libvirtd" "wheel" ];

  # CLI friends — add to system packages:
  environment.systemPackages = with pkgs; [
    virt-manager      # GUI (same as programs.virt-manager but explicit)
    virt-viewer       # SPICE/VNC viewer, better than virt-manager's builtin
    libvirt           # provides `virsh` CLI (no separate `virsh` package)
    guestfs-tools      # virt-customize, virt-sparsify — offline VM image edits
    virtiofsd         # vhost-user daemon for virtio-fs shares
    swtpm             # software TPM (pulled in by the option above anyway)
    # Fetch Windows virtio drivers without a browser:
    # nix-shell -p fetchurl --run 'fetchurl https://fedorapeople.org/...virtio-win.iso'
    win-spice         # spicy viewer alternative
  ];

  # libvirt NSS for VM name → IP lookups (optional):
  #   nss.enableGuest = guest-name based (libvirt_guest, `ssh vm-name`);
  #   nss.enable = legacy hostname based (libvirt, DHCP hostname).
  # Enable ONE or both as needed:
  # virtualisation.libvirtd.nss.enableGuest = true;
  # virtualisation.libvirtd.nss.enable = true;
}
```

After `nixos-rebuild switch`, verify:

```bash
# Daemon active?
systemctl status libvirtd

# Default NAT network exists and is started? (provides DHCP + outbound NAT)
sudo virsh net-start default && sudo virsh net-autostart default

# Now open virt-manager and create a VM through the wizard.
```

> **NixOS quirk:** if `virsh` complains `Failed to connect socket to '/run/libvirt/libvirt-sock'`, add your user to `libvirtd` group and re-login (`$USER` session groups are computed at login), or use `sudo virsh -c qemu:///system` as a stopgap.

---

## 4. CPU Virtualization Requirements

### 4.1 AMD-V (SVM)

```nix
{ config, pkgs, ... }: {
  hardware.cpu.amd.updateMicrocode = true;   # microcode fixes occasionally
                                              # touch SVM/IOMMU errata

  # The kernel KVM modules for AMD:
  boot.kernelModules = [ "kvm_amd" ];        # loaded automatically; explicit
                                              # listing is harmless documentation
}
```

- Enable **SVM** in BIOS (usually on by default; sometimes "IOMMU" is a separate switch — enable it too, it's `AMD-Vi`).
- `kvm_amd` supports nested virtualization out of the box (see §16).

### 4.2 Intel VT-x / VMX

```nix
{ config, pkgs, ... }: {
  hardware.cpu.intel.updateMicrocode = true;

  boot.kernelModules = [ "kvm_intel" ];
}
```

- Enable **VT-x** and **VT-d** in BIOS. VT-d is frequently **disabled by default** on consumer boards — check before GPU passthrough attempts.
- Nested on Intel needs `nested=1` explicitly (§16) — unlike AMD's default-on. Verify with `cat /sys/module/kvm_intel/parameters/nested`.

### 4.3 IOMMU: AMD-Vi vs Intel VT-d (+ Interrupt Remapping)

Enable the IOMMU explicitly for your CPU vendor (pick the line matching your machine):

```nix
{ lib, ... }: {
  # AMD boards — amd_iommu is usually on by default, but being explicit
  # costs nothing. iommu=pt = passthrough mode: DMA translation stays OFF
  # for host devices (zero host perf cost) while assigned devices work.
  boot.kernelParams = [ "amd_iommu=on" "iommu=pt" ];

  # Intel boards — use these instead (intel_iommu is OFF by default!):
  # boot.kernelParams = [ "intel_iommu=on" "iommu=pt" ];

  # If your CPU lacks an IOMMU (rare; old i5s), PCI passthrough is
  # impossible; QEMU still works fine for normal VMs.
}
```

> **Interrupt remapping (both vendors, non-negotiable for VFIO):** `dmesg | grep -i "remapping"` must show `AMD-Vi: Interrupt remapping enabled` (AMD) or `DMAR: Interrupt remapping enabled` (Intel). Without it, device interrupts can hit the wrong guest — the kernel WARNS and VFIO refuses unsafe interrupts. Fix = BIOS update + enable IOMMU/VT-d fully (some boards hide remapping behind "ACS" or "IOMMU pre-boot" toggles), never `allow_unsafe_interrupts` (defeats isolation; §18).

Then check groups (every device you pass through must be in a group without host-critical peers):

```bash
#!/usr/bin/env bash
# Save as iommu-groups.sh — prints each IOMMU group and its devices
shopt -s nullglob
for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
  echo "IOMMU Group ${g##*/}:"
  for d in "$g"/devices/*; do
    echo -e "\t$(lspci -nns "${d##*/}")"
  done
done
```

---

## 5. High-Performance QEMU/KVM Tuning

Apply these in virt-manager (VM → open → XML tab) or via `virsh edit <vm>`. Each block is standalone XML you merge into the domain.

### 5.1 CPU model and topology

```xml
<!-- ================================================================
     CPU: host-passthrough exposes your real CPU (AVX, AES, etc).
     NEVER leave the default (qemu64) — the guest will lack basic
     instructions and benchmark terribly.
     ================================================================ -->
<cpu mode="host-passthrough" check="none" migratable="off">
  <!-- topoext is REQUIRED for AMD hosts: exposes SMT topology to the
       guest, letting Windows scheduler group sibling threads correctly. -->
  <feature policy="require" name="topoext"/>
  <!-- AMD hosts: Hyper-V enlightenments make Windows run dramatically
       faster under KVM (better spinlock/scheduler behavior). -->
  <feature policy="require" name="hypervisor"/>
  <!-- Topology example: 4 vCPUs = 2 cores × 2 threads on a 6c/12t host.
       Match vCPUs to what you pin below. -->
  <topology sockets="1" dies="1" cores="2" threads="2"/>
</cpu>

<!-- Optional but big for Windows: full Hyper-V enlightenments -->
<features>
  <hyperv mode="custom">
    <relaxed state="on"/>
    <vapic state="on"/>
    <spinlocks state="on" retries="8191"/>
    <vpindex state="on"/>
    <runtime state="on"/>
    <synic state="on"/>
    <stimer state="on"><direct state="on"/></stimer>
    <reset state="on"/>
    <frequencies state="on"/>
    <reenlightenment state="on"/>
    <tlbflush state="on"/>
    <ipi state="on"/>
  </hyperv>
</features>
```

**How many vCPUs?** Rule of thumb: `total_host_threads - 2 threads` reserved for the host. On a 6c/12t Ryzen 5 3600 → give the guest 8 (4c/8t) and keep 4 host threads for QEMU overhead, Looking Glass, and the desktop.

### 5.2 CPU pinning (vCPU → host thread mapping)

```xml
<!-- ================================================================
     Pinning locks each vCPU thread to a physical CPU thread.
     First find your topology: `lscpu -e=CPU,CORE,SOCKET,NODE`
     Pair each vCPU with its SMT sibling, and pin emulator (QEMU's own
     housekeeping threads) to the leftover cores.
     Example for 6c/12t host, 4c/8t guest (host cores 2,3,4,5 → guest,
     host cores 0,1 kept for host + emulator threads):
     ================================================================ -->
<vcpu placement="static">8</vcpu>
<cputune>
  <vcpupin vcpu="0" cpuset="4"/>   <!-- vCPU0 → host CPU4 (core 2, thread 0) -->
  <vcpupin vcpu="1" cpuset="10"/>  <!-- vCPU1 → host CPU10 (core 2, thread 1 — SIBLING of vCPU0) -->
  <vcpupin vcpu="2" cpuset="5"/>
  <vcpupin vcpu="3" cpuset="11"/>
  <vcpupin vcpu="4" cpuset="6"/>
  <vcpupin vcpu="5" cpuset="12"/>
  <vcpupin vcpu="6" cpuset="7"/>
  <vcpupin vcpu="7" cpuset="13"/>
  <emulatorpin cpuset="0-3"/>      <!-- QEMU io/audio threads on host CPUs 0-3 -->
</cputune>
```

Get it wrong and Windows stutters; get it right and latency graphs flatten. On NUMA systems (Threadripper dual-die, EPYC, dual-socket Xeon), pin vCPUs to the NUMA node physically closest to your passed-through GPU's PCIe slot.

#### NUMA per vendor: AMD CCD vs Intel P/E (extends §5.2 pinning above)

```bash
# Map YOUR topology first — the pinning above is an EXAMPLE, not yours:
lscpu -e=CPU,CORE,SOCKET,NODE,CLOCK   # threads, cores, NUMA nodes
lstopo --no-io --of txt 2>/dev/null || lscpu -p | head -20
# GPU NUMA node: udevadm info /sys/bus/pci/devices/0000:07:00.0 | grep NUMA
```

- **AMD (CCD/chiplet topology):** cores inside one CCD share L3; crossing CCDs costs latency. Pin ALL vCPUs to ONE CCD (e.g. CCD0 = host CPUs 0-7 on an 8-core CCD) + the emulator to a sibling thread of the SAME CCD. Check CCD layout: `lscpu -e CPU,CORE | awk` groupings of 8/16, or `cat /sys/devices/system/cpu/cpu*/topology/cluster_id`. Threadripper/EPYC: also pin guest RAM to the GPU's NUMA node (`<numatune><memnode mode="strict" nodeset="0"/></numatune>` in the VM XML).
- **Intel (P/E hybrid — Alder Lake+):** P-cores (performance) and E-cores (efficiency) are NOT interchangeable. Isolate the GUEST on P-cores only (consistent frequency, AVX, Hyper-V enlightenments behave), and pin the EMULATOR + host desktop to E-cores (`<emulatorpin cpuset="<e-cores>"/>`). Identify P vs E: `lscpu -e CPU,CORE,MAXMHZ` (P-cores clock higher) or Intel's P/E listing in `lstopo`. Never split one vCPU pair across P and E — the scheduler sees phantom heterogeneity and games micro-stutter.
- Verify: `virsh vcpuinfo <vm>` shows live placement; `tuna`/`htop` (thread view) confirms isolation under load.

### 5.3 Memory: static hugepages (eliminate page-table misses)

```nix
{ config, pkgs, ... }: {
  # Reserve hugepages at boot (never in /etcfstab-style dynamic allocation
  # — reservation at boot avoids fragmentation failures).
  # 2 MiB × 8192 pages = 16 GiB reserved for VMs.
  boot.kernelParams = [ "default_hugepagesz=2M" "hugepagesz=2M" "hugepages=8192" ];
}
```

```xml
<!-- Inside the VM XML: -->
<memoryBacking>
  <hugepages/>          <!-- guest RAM served from 2 MiB pages -->
  <locked/>             <!-- mlock: QEMU RAM never swapped -->
</memoryBacking>
```

Trade-off: hugepages are carved out of total RAM and unavailable to the host while the VM runs; with a fixed dedicated gaming VM this is exactly what you want. Skip for casual VMs — they make memory management inflexible.

#### 2M vs 1G pages: AMD vs Intel TLB (extends §5.3 above)

```nix
{ config, pkgs, ... }: {
  # 1G pages: fewer TLB entries cover the same RAM (1 entry = 1 GiB).
  # Worth it ONLY for big gaming VMs (16GiB+) on CPUs with 1G-TLB support.
  # Check yours: grep -o 'pdpe1gb\|pse' /proc/cpuinfo | head -1
  #   pdpe1gb present (most Zen + Xeon/Core i7+) → 1G usable.
  # boot.kernelParams = [ "default_hugepagesz=1G" "hugepagesz=1G" "hugepages=16" ];
  #   # 16 × 1G = 16 GiB. Combine with 2M pool for smaller VMs:
  # boot.kernelParams = [ "default_hugepagesz=2M" "hugepagesz=2M" "hugepages=2048"
  #                        "hugepagesz=1G" "hugepages=16" ];
}
```

```xml
<!-- VM side for 1G pages: -->
<memoryBacking>
  <hugepages>
    <page size="1048576" unit="KiB"/>   <!-- 1 GiB pages -->
  </hugepages>
  <locked/>
</memoryBacking>
```

- **AMD:** large-page TLB coverage is generous on Zen — 1G pages measurably cut stutter in memory-heavy games. Cost: 1G pages fragment EARLY; reserve at boot (above) or allocation fails. Verify: `grep HugePages /proc/meminfo`.
- **Intel:** P-core TLBs handle 2M pages very well; 1G wins are smaller except on Xeon with huge guests. E-cores share smaller TLBs — another reason to pin guests to P-cores (§5.2b).
- Rule: 2M default, 1G for the dedicated 16GiB+ gaming VM only. Both need `<locked/>` (mlock) or the host swaps your "pinned" RAM anyway.

### 5.4 Devices: virtio everywhere

```xml
<!-- DISK: virtio bus. cache="none" + discard → near-native NVMe perf. -->
<disk type="file" device="disk">
  <driver name="qemu" type="raw" cache="none" discard="unmap" io="native"/>
  <source file="/var/lib/libvirt/images/win10.img"/>
  <target dev="vda" bus="virtio"/>
</disk>

<!-- NETWORK: virtio + vhost-net (kernel accelerator, default in NixOS) -->
<interface type="network">
  <source network="default"/>
  <model type="virtio"/>
  <!-- Multiqueue for >1 vCPU guests: (uses RSS in Windows) -->
  <driver name="vhost" queues="4"/>
</interface>

<!-- KEYBOARD/MOUSE for SPICE-based VMs (needed by Looking Glass too): -->
<input type="mouse" bus="virtio"/>
<input type="keyboard" bus="virtio"/>

<!-- KILL the memballoon — it wrecks VFIO latency when the host
     reclaims guest memory mid-frame: -->
<memballoon model="none"/>
```

---

## 6. Storage Deep Dive

### Formats & when to use them

| Format | Snapshot | Sparse | Perf | Use |
|---|---|---|---|---|
| `raw` (`.img`) | via libvirt | yes (punch-hole w/ discard) | best | VM disks, passthrough gaming VMs |
| `qcow2` | internal, cheap | yes | ~95% raw | casual VMs, frequent snapshots |
| LVM volume | external | no | raw-class | server setups |
| `raw` on ZFS | via ZFS | no | raw-class, CoW pitfalls | ZFS hosts |

The VM XML in §5.4 already carries the optimal raw settings. For qcow2, change `type="raw"` → `type="qcow2"`.

### Create & manage images from the CLI

```bash
# 32 GiB raw image, sparsely allocated (grows on demand)
sudo virt-install \
  --name win10 \
  --memory 8192 --vcpus 4 \
  --disk path=/var/lib/libvirt/images/win10.img,size=32,format=raw,cache=none,bus=virtio \
  --cdrom /path/to/windows.iso \
  --disk /path/to/virtio-win.iso,device=cdrom \
  --os-variant win10 \
  --network network:default,model=virtio \
  --graphics spice,listen=none \
  --boot uefi          # UEFI/OVMF firmware; add --tpm for Win11

# Shrink a qcow2 after deleting files in the guest (zero + sparsify):
sudo virt-sparsify --in-place /var/lib/libvirt/images/vm.qcow2
```

### virtio-fs: share a host folder at native speed

```xml
<!-- Host side: NixOS starts virtiofsd via vhostUserPackages (§3).
     In the VM XML: -->
<filesystem type="mount" accessmode="passthrough">
  <driver type="virtiofs" queue="1024"/>
  <binary path="/run/current-system/sw/bin/virtiofsd" xattr="on">
    <sandbox mode="chroot"/>
  </binary>
  <source dir="/home/fury/VMShare"/>
  <target dir="hostshare"/>   <!-- tag visible inside guest -->
</filesystem>
```

Windows guest: virtio-win installs a "VirtIO-FS" service — it appears as a network drive. Linux guest: `mount -t virtiofs hostshare /mnt/host`.

---

## 7. Networking

### Default (NAT via virbr0) — good for most

Every VM behind the default `default` network: outbound internet, inbound only via port forwards. DHCP served by libvirt's dnsmasq.

```bash
# find the DHCP lease (name/IP) of a running VM:
sudo virsh net-dhcp-leases default
```

### Bridged networking — VM is a full LAN citizen

```nix
{ config, pkgs, lib, ... }: {
  # Bridge VMs directly onto your physical LAN (get LAN IP from your router,
  # RDP/mDNS/SMB to the VM works from any device):
  # USE ONE method only — networking.bridges + NM-owned bridge conflict.
  # Pick declarative (below) OR NM-managed (nmcli below), never both:
  networking.bridges.br0.interfaces = [ "enp5s0" ];  # ← your NIC name (ip a)
  networking.interfaces.br0.useDHCP = true;

  # NOTE: on NetworkManager systems, prefer letting NM own the bridge instead
  # (i.e. SKIP networking.bridges above and use ONLY this / nmcli):
  networking.networkmanager = {
    enable = true;
    # Optional: let NM manage the bridge directly via a connection profile:
    # (uncomment to have a persistent "bridge" connection auto-created)
    # ensureProfiles.profiles.br0 = { ... }; # advanced; see NM docs
  };
  # Allow qemu:///session users to use this bridge:
  virtualisation.libvirtd.allowedBridges = [ "virbr0" "br0" ];
}
```

If you use NetworkManager (default on desktop installs), create the bridge imperatively once via `nmcli` instead and it persists across rebuilds:

```bash
# Create br0 over your physical NIC (replaces its connection):
nmcli con add type bridge con-name br0 ifname br0 ipv4.method auto
nmcli con add type bridge-slave ifname enp5s0 master br0
nmcli con up br0
```

Then in the VM XML: `<interface type='bridge'><source bridge='br0'/><model type='virtio'/></interface>`

### SR-IOV (advanced)

NICs that support SR-IOV (e.g., Intel X550, Mellanox ConnectX) can carve themselves into Virtual Functions passed through as real hardware — line-rate in-VM networking. Enable in BIOS; create VFs on boot:

```nix
{
  # Example: create 7 VFs on an Intel igb/x550 NIC supporting SR-IOV
  # (number of VFs and driver name are NIC-specific)
  boot.extraModprobeConfig = "options igb max_vfs=7";
}
```

---

## 8. USB & PCI Passthrough

### USB: three ways, easiest first

1. **SPICE USB redirection** (§3 option, already enabled) — click a USB device in the viewer toolbar; it hotplugs into the VM over SPICE.
2. **Host device via XML:**
   ```xml
   <hostdev mode="subsystem" type="usb" managed="yes">
     <source>
       <vendor id="0x046d"/>   <!-- from: lsusb -->
       <product id="0xc52b"/>
     </source>
   </hostdev>
   ```
   Matches the first device with that vendor/product ID — hotplug-unfriendly but stable for mice/dongles.
3. **By physical port** (better: device is re-acquired even after replug):
   ```xml
   <hostdev mode="subsystem" type="usb" managed="yes">
     <source>
       <address bus="3" device="4"/>   <!-- from: lsusb -t -->
     </source>
   </hostdev>
   ```

### PCI: block a device permanently for VM use with vfio-pci

```nix
{ config, pkgs, lib, ... }: {
  # Reserve PCI devices for VFIO by ID. Find IDs via: lspci -nn
  # Example: pass an entire GPU (VGA + AUDIO functions together):
  boot.kernelParams = [
    # 10de:2204 + 10de:1bef = vendor:device IDs of the GPU and its
    # onboard audio controller (HDMI/DP sound). Pass ALL functions.
    "vfio-pci.ids=10de:2204,10de:1bef"
  ];

  # Ensure vfio-pci grabs the device before the real driver binds:
  boot.extraModprobeConfig = ''
    options vfio-pci ids=10de:2204,10de:1bef
    softdep nvidia pre: vfio-pci      # for an NVIDIA GPU being passed
    # softdep amdgpu pre: vfio-pci     # for an AMD GPU being passed
    # softdep nouveau pre: vfio-pci    # for any GPU if nouveau is the host driver
    # softdep snd_hda_intel pre: vfio-pci  # if its audio function binds early
  '';

  # Load vfio modules in initrd (before GPU drivers can claim devices):
  # NOTE: kernel module names use underscores (vfio_pci, not vfio-pci).
  boot.initrd.kernelModules = [ "vfio_pci" "vfio_iommu_type1" "vfio_virqfd" ];
  # If a name fails to load, check:
  #   ls /lib/modules/$(uname -r)/kernel/drivers/vfio/
}
```

> **Important nuance:** if the passed GPU is a *secondary* GPU (you have another for the host), the config above is all you need. If it's your *only* GPU, you must additionally unload/reload the host driver around VM start/stop — that is hook-script territory, covered exhaustively in `Looking-Glass-Virtualization-NixOS.md` §11 (Single-GPU passthrough), since it's usually paired with Looking Glass anyway.

---

## 9. GPU Passthrough (VFIO) — The Exhaustive Path

GPU passthrough = hand a real GPU to a VM via VFIO. Done right, the guest's GPU benchmark scores are indistinguishable from bare metal.

### 9.1 Prerequisites (all mandatory)

1. CPU with IOMMU: **AMD-Vi** (all Zen) or **Intel VT-d** (most i5/i7/Xeon; check Ark).
2. IOMMU enabled in BIOS (AMD: "IOMMU"; Intel: "VT-d").
3. `iommu=pt` kernel param (§4) + IOMMU groups such that the GPU and its audio function sit in a group without host-critical devices (§4 group listing script). If the group is "dirty", you can still pass the *entire group* or move the PCIe slot (try the x16 slots physically wired to the CPU, not the chipset).
4. Guest GPU must have a display attached, OR a **dummy plug** (~$5 HDMI resistor plug) — GPUs power down their outputs with nothing connected and the guest driver refuses to render headless (LG guide §2).
5. Sufficient PCIe lanes: passing a GPU into a chipset-slotted x4 on PCIe 3.0 costs ~5–10% GPU performance. Prefer slots wired to the CPU.

### 9.2 Reserve the GPU (VFIO by ID) — see §8 code block

Run `lspci -nn | grep -iE "vga|3d|audio"` and collect **every** function of the passed GPU (usually `VGA` + `Audio`, occasionally `USB`/`serial` controllers on modern cards). Put all their `vendor:device` IDs into `vfio-pci.ids`.

### 9.3 VM XML: attach the GPU

```xml
<!-- Add inside <devices>. Use lspci values: your GPU is e.g. 07:00.0 -->
<hostdev mode="subsystem" type="pci" managed="yes">
  <source>
    <address domain="0x0000" bus="0x07" slot="0x00" function="0x0"/>
  </source>
  <address type="pci" domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
</hostdev>
<hostdev mode="subsystem" type="pci" managed="yes">
  <source>
    <!-- Same GPU, audio function (.1). Pass it too or HDMI/DP audio stays dead: -->
    <address domain="0x0000" bus="0x07" slot="0x00" function="0x1"/>
  </source>
  <address type="pci" domain="0x0000" bus="0x01" slot="0x00" function="0x1"/>
</hostdev>
```

Then, **inside the guest, remove the virtual display**: delete the `<video>` device (set `<model type="none"/>` if virt-manager re-adds it) and set `<graphics type="spice">` to remain (Looking Glass uses its SPICE channel for input, LG guide §6) — but for a pure passthrough + physical-monitor setup you may delete `<graphics>` too and use the real monitor.

### 9.4 NVIDIA: Error 43 (vendor_id + hidden KVM) & ReBAR

```xml
<!-- Error 43 = the NVIDIA guest driver detecting the hypervisor and
     refusing to load (Code 43 in Device Manager). Drivers ≥ 465 (2021+)
     dropped the block — but passthrough guides keep the workaround
     because it ALSO fixes perf counters and G-SYNC in-VM. Keep it: -->
<features>
  <hyperv mode="custom">
    <!-- ... your §5.1 enlightenments ... -->
    <vendor_id state="on" value="whatever"/>  <!-- spoof hypervisor ID -->
  </hyperv>
  <kvm>
    <hidden state="on"/>    <!-- hide KVM leaf from CPUID -->
  </kvm>
</features>
<!-- BOTH lines together. vendor_id alone still trips new drivers;
     hidden alone breaks Hyper-V enlightenments. Verify: GPU-Z in the
     guest shows the real card name, Device Manager shows no Code 43. -->
```

- **ReBAR (Resizable BAR / AMD SAM) per vendor BIOS:** the guest needs the GPU's FULL VRAM mapped. Host BIOS: enable `Above 4G Decoding` AND `ReBAR`/`Resizable BAR` (AMD: "SAM"; Intel: "ReBAR"). Host kernel: `boot.kernelParams = [ "pci=realloc" ];` so BARs relocate above 4G. Guest XML: `<features><kvm><hidden state='on'/></kvm></features>` (above) + OVMF (not SeaBIOS — §10). Check: `dmesg | grep -i bar` shows multi-GB BARs; NVIDIA Control Panel reports "Resizable BAR: Yes". NVIDIA 30-series+ and AMD RDNA2+ gain 5-15% in-VM; without it, large-VRAM cards crawl.
- Legacy note: pre-465 guest drivers REQUIRED the spoof; modern ones merely benefit. If Error 43 persists on new drivers, the cause is usually a missed audio/USB function (§9.2) or a dirty group (§9.6), not the spoof.

### 9.5 AMD: Reset Bug + vendor-reset

AMD guest GPUs work, but the Looking Glass project documents stability issues with Polaris/Vega/Navi/BigNavi as *passthrough* devices (reset bug family). NVIDIA in the guest + AMD/Intel driving the host is the battle-tested combo. See LG guide §2 for details.

- **The reset bug:** many AMD cards (Vega 56/64, RX 5000/6000, some Polaris) don't reinitialize after VM shutdown — second VM start hangs or shows garbage until a HOST reboot. Symptom: first boot perfect, every later boot broken.
- **vendor-reset module (the fix):** a DKMS/out-of-tree kernel module implementing per-card reset sequences. NixOS: package it via `boot.extraModulePackages = [ config.boot.kernelPackages.vendor-reset ];` (nixpkgs `vendor-reset` — check availability for your kernel; needs `boot.kernelModules = [ "vendor-reset" ];` + the card's PCI ID in its config). Rebuild, reboot, then stop/start the VM twice — the second start working IS the test. RDNA3+/RX 7000 mostly fixed upstream; Vega/Navi1 still need it. If vendor-reset lacks your card, the fallback is a host reboot between VM runs (or NVIDIA in the guest).

### 9.6 Dirty IOMMU Groups

If your GPU group contains, say, a USB controller the host needs, you can pass *every* device in the group to the VM (Windows will simply also see a spare USB controller), or use `driverctl` to unbind a specific device. Advanced; avoid by choosing the right slot.

### 9.7 Intel: GVT-g / SR-IOV / Arc Passthrough

- **GVT-g (Intel iGPU sharing, Broadwell → Comet Lake):** mediated passthrough — ONE physical iGPU split into virtual GPUs for MULTIPLE VMs (no VFIO full-card handoff). Host: `boot.kernelModules = [ "kvmgt" "vfio-mdev" ];` + i915 with `enable_gvt=1`. Guest XML uses `<hostdev mode='subsystem' type='mdev'>` (mediated device), NOT pci. Best density option for Intel-only hosts (office VMs with acceleration). Dead-end on 11th-gen+ (Intel killed GVT-g for ADL and newer).
- **i915 SR-IOV (11th-gen+ / Arc replacement):** Intel's supported path — physical/virtual functions via `boot.kernelParams = [ "i915.enable_guc=3" "i915.max_vfs=7" ];` (counts vary by card; check `lspci` for VFs after boot). Pass VFs as `type='pci'` like §9.3. Needs very recent kernels + GuC/HuC firmware (`hardware.enableRedistributableFirmware = true`).
- **Arc discrete passthrough (A380/A750/A770):** full-card VFIO like §9.2/§9.3 — Arc behaves BETTER than AMD here (no reset bug), but needs ReBAR (§9.4: Arc LOSES ~30% without it, more than NVIDIA/AMD) and a 6.2+ kernel with GuC firmware. Guest driver: Intel Arc Windows driver installs cleanly under the §9.4 hidden-KVM flags. Host stays on iGPU/modesetting; Arc goes fully to the VM.

> **Looking Glass cross-link:** passthrough + a PHYSICAL monitor (§9.1-4) is one display story; passthrough + Looking Glass (shared-memory frame relay, near-zero latency, host-viewable window) is the other. LG needs the SPICE channel kept (§9.3), the kvmfr module + `/dev/kvmfr0` (§3 verbatimConfig), and matching host/guest client versions — full recipe in `Looking-Glass-Virtualization-NixOS.md` §2/§6/§11. Decide BEFORE wiring XML: converting a monitor-VM to LG later means re-adding the video/graphics devices you deleted.

---

## 10. Windows Guest Checklist

The complete recipe for a fast Windows VM (works for Win10/11):

1. **Firmware:** UEFI (OVMF) + TPM:
   ```xml
   <os firmware="efi">       <!-- virt-manager: Firmware: UEFI -->
     <boot dev="hd"/>
   </os>
   <!-- TPM 2.0 (emulated swtpm — enabled in NixOS §3): -->
   <tpm model="crb"><backend type="emulated" version="2.0"/></tpm>
   ```
   NixOS ships all OVMF firmware variants automatically — no `qemuOvmf` option anymore; select "OVMF" in virt-manager or `firmware="efi"` in XML.

2. **Virtio drivers ISO** — Windows doesn't ship virtio drivers; without them the virtio disk/network are invisible:
   ```bash
   # Get virtio-win ISO (contains: blk, net, balloon, fs, input, GPU, serial drivers)
   nix-shell -p fetchurl --run \
     'fetchurl https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso'
   ```
   Attach as a second CDROM; during Windows setup: "Load driver" → browse `viostor` (disk) then proceed; after install, run `virtio-win-gt-x64.msi` / `virtio-win-guest-tools.exe` from the ISO for the rest.

3. **CPU:** host-passthrough + topoext (AMD) + pinning (§5.1–5.2).
4. **Disk/net:** virtio (§5.4). Install `netkvm` driver.
5. **Disable memballoon** (§5.4) — critical for gaming latency.
6. **Hibernation inside guest:** disable it (`powercfg /h off`) — it does nothing useful in a VM and fragments the image.
7. **QEMU Guest Agent** (from virtio-win) — enables graceful shutdown and filesystem freeze/trim:
   ```xml
   <channel type="unix">
     <target type="virtio" name="org.qemu.guest_agent.0"/>
   </channel>
   ```

### 10.1 TPM / swtpm for Windows 11

```nix
{ config, pkgs, ... }: {
  # Windows 11 REFUSES to install without TPM 2.0 + Secure Boot + UEFI.
  # NixOS provides all three declaratively — §3 already enables swtpm:
  virtualisation.libvirtd.qemu.swtpm.enable = true;  # emulated TPM 2.0
}
```

```xml
<!-- In the VM XML (virt-manager: Add Hardware → TPM → CRB, emulated): -->
<os firmware="efi"/>   <!-- OVMF UEFI — SeaBIOS can't do Win11, period -->
<tpm model="crb"><backend type="emulated" version="2.0"/></tpm>
<!-- Secure Boot in the GUEST (OVMF SMM): virt-manager Firmware: UEFI x86_64: ...secboot... -->
<!-- CPU: host-passthrough (§5.1) satisfies Win11's CPU-generation check
     on any Zen2+/Coffee Lake+ host. Win10 guests: TPM optional, skip it. -->
```

- State lives in `/var/lib/libvirt/swtpm/<vm>/` — back it up WITH the disk image (§6), or BitLocker/re-activation breaks on restore. Snapshot before first boot; a corrupted TPM NVRAM bricks the guest's keychain silently.
- Passthrough alternative: physical TPM via `<tpm model='crb'><backend type='passthrough'/></tpm>` — ties the VM to THIS host (no migration). Prefer emulated.

---

## 11. Linux/BSD Guests

- Use the same virtio devices; Linux has them in-tree — zero extra drivers.
- `spice-vdagent` in the guest enables dynamic resolution + clipboard over SPICE:
  ```nix
  # Inside the GUEST's own configuration.nix (if the guest is NixOS):
  { ... }: {
    services.qemuGuest.enable = true;
    services.spice-vdagentd.enable = true;   # clipboard + resolution sync
  }
  ```
 - Shared folders: virtio-fs (§6, preferred for NixOS guests); 9p is legacy, avoid.

### virtiofs vs 9p

| | virtiofs (§6) | 9p (legacy) |
|---|---|---|
| Transport | vhost-user daemon (virtiofsd, §3 vhostUserPackages) | in-kernel 9p2000 protocol |
| Performance | near-native (DAX, page-cache sharing) | 2-5× slower, metadata-heavy ops crawl |
| NixOS guest mount | `mount -t virtiofs hostshare /mnt/host` | `mount -t 9p -o trans=virtio hostshare /mnt` |
| Windows guest | virtio-win VirtIO-FS service → network drive | barely supported — avoid |
| Permissions | `sandbox mode="chroot"`, UID mapping via `idmap` | `accessmode="passthrough"` (leaky by default) |
| Use when | everything new, NixOS/Linux/Windows guests | only when the guest kernel lacks virtiofs (ancient distros, some BSDs) |

Rule: virtiofs always unless the guest can't speak it. 9p stays documented for rescue scenarios only.

---

## 12. Containers: Docker, Podman, Incus/LXC

### Docker

```nix
{ ... }: {
  virtualisation.docker = {
    enable = true;
    # Declarative daemon.json:
    daemon.settings = {
      experimental = true;
      # use systemd cgroup driver (default in NixOS anyway)
      "registry-mirrors" = [ "https://mirror.gcr.io" ];
    };
    # NixOS 26.05 defaults to the modern docker-compose subcommand:
    # `docker compose up -d` works with package docker-compose in packages
  };
  users.users."fury".extraGroups = [ "docker" ];  # run without sudo
}
```

### Podman (rootless — the NixOS-favored option)

```nix
{ ... }: {
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;   # creates a `docker` alias → podman
    dockerSocket.enable = true; # /var/run/docker.sock emulation for tools
  };
}
```

### Declarative OCI containers (NixOS-native, reproducible)

```nix
{ ... }: {
  virtualisation.oci-containers.containers = {
    # Runs on boot, restarts on failure, no docker CLI needed at all
    yourservice = {
      image = "docker.io/library/redis:7-alpine";
      ports = [ "6379:6379" ];
      volumes = [ "/var/lib/redis:/data" ];
      environment = { TZ = "UTC"; };
      autoStart = true;
    };
  };
}
```

### Incus / LXC — system containers (VM-light OS containers)

```nix
{ ... }: {
  virtualisation.lxc.enable = true;
  virtualisation.incus.enable = true;
  # Networking defaults to a managed bridge; allow your user:
  users.users."fury".extraGroups = [ "incus-admin" ];
}
```

---

## 13. Waydroid (Android)

Full Android (LineageOS-based) in a window, GPU-accelerated on Wayland:

```nix
{ ... }: {
  virtualisation.waydroid.enable = true;  # pulls in lxc, binder/ashmem kernel support
  # First launch initializes the container; then:
  #   waydroid show-full-ui
}
```

---

## 14. VirtualBox

```nix
{ config, pkgs, ... }: {
  virtualisation.virtualbox.host = {
    enable = true;
    enableExtensionPack = true;  # USB 2/3, RDP, NVMe (PUEL license — allowUnfree needed)
    # addNetworkInterface = true; # host-only network module (default true)
    # headless = true;            # server use
  };
  nixpkgs.config.allowUnfree = true;         # required for the extension pack
  users.users."fury".extraGroups = [ "vboxusers" ]; # USB passthrough needs this
}
```

Use only for compatibility with existing .ova/.vbox images — KVM outperforms it substantially.

---

## 15. VMware Workstation

```nix
{ config, pkgs, ... }: {
  virtualisation.vmware.host = {
    enable = true;
    package = pkgs.vmware-workstation;
    # extraConfig = ''   # appended to /etc/vmware/config
    #   mainMem.useNamedFile = "FALSE"
    # '';
  };
  nixpkgs.config.allowUnfree = true;
}
```

---

## 16. Nested Virtualization

Run KVM/WSL2/Hyper-V inside a KVM guest — expose the virtualization extensions:

```xml
<!-- In the (Linux) guest VM's XML: -->
<cpu mode="host-passthrough">
  <!-- Either of these lines exposes VMX/SVM to the guest: -->
  <feature policy="require" name="vmx"/>   <!-- Intel host -->
  <feature policy="require" name="svm"/>   <!-- AMD host -->
</cpu>
```

Inside the NixOS guest: enable `virtualisation.libvirtd.enable` as usual — `/dev/kvm` appears and works.

### Nested KVM Per Vendor (AMD vs Intel)

```nix
{ config, pkgs, ... }: {
  # Host side: expose the virtualization extensions to the guest.
  # AMD (nested ON by default — usually nothing to do):
  boot.extraModprobeConfig = "options kvm_amd nested=1";
  # Intel (nested OFF by default — this line is MANDATORY):
  # boot.extraModprobeConfig = "options kvm_intel nested=1";
  # Verify on the HOST: cat /sys/module/kvm_amd/parameters/nested  # Y/1
  #                      cat /sys/module/kvm_intel/parameters/nested
}
```

```xml
<!-- Guest VM XML: expose the vendor's extension flag (pick ONE): -->
<cpu mode="host-passthrough">
  <feature policy="require" name="svm"/>   <!-- AMD host -->
  <!-- <feature policy="require" name="vmx"/>  <!-- Intel host --> -->
</cpu>
```

- Verify IN the guest: `/dev/kvm` exists + `lscpu | grep -iE "svm|vmx"`. WSL2-under-KVM (Intel) additionally needs `<feature policy='require' name='vmx'/>` AND Hyper-V enlightenments (§5.1) — WSL2 is Hyper-V in disguise.
- IOMMU does NOT nest usefully: VFIO passthrough inside a nested guest is unsupported (host IOMMU groups don't propagate). Nested = CPU virt only.

---

## 17. Testing NixOS Configs in a VM

The killer NixOS feature — test a config change (or a whole new machine) before touching the real system:

```bash
# Build & run the config as a QEMU VM (auto-creates a throwaway disk):
nixos-rebuild build-vm --flake /etc/nixos#nixos
./result/bin/run-nixos-vm    # console window; user: root, empty password

# With a flake target (the same "nixos" host from your flake):
# Add a copy-on-write snapshot of your real system as the VM disk for
# testing config changes against real data safely — advanced; see
# nixos-generators for other output formats.

# Share a host folder into the test VM via virtiofs (preferred for NixOS
# guests; 9p is legacy, avoid):
# declare a virtiofs share in the VM config (cf. §6), then inside VM:
#   mount -t virtiofs hostshare /mnt
```

For multi-machine integration tests, see the NixOS manual's "Running VM tests" — you can write deterministic test scenarios (`nixos/tests/*.nix` in nixpkgs) that boot networks of VMs and assert behavior.

---

## 18. Security & Isolation of the Stack

1. **Least privilege:** `virtualisation.libvirtd.qemu.runAsRoot = false;` runs every VM as the locked-down `qemu-libvirtd` user. Flip the ownership of existing images once (`/var/lib/libvirt/qemu → qemu-libvirtd:`), else old VMs fail to start. Hooks needing root (driver unload, chown of /dev/kvmfr0) are incompatible with this mode — that's the documented trade-off.
2. **sVirt/SELinux:** NixOS does not enable SELinux sVirt labels; the practical MAC equivalent is running QEMU unprivileged (above) + AppArmor on the host (see `Hardening-NixOS.md`).
3. **Network isolation:** default NAT already blocks inbound. For untrusted VMs, remove the default NIC and use an isolated bridge:
   ```bash
   sudo virsh net-define <(echo '<network><name>isolated</name></network>')
   ```
4. **Resource caps:** limit the VM's host damage with libvirt `blkiotune`/`iotune` on disks and `<memory>` + cgroup limits.
5. **Don't pass what you don't control:** USB passthrough of security keys (YubiKey) into untrusted VMs equals handing them the token.

---

## 19. Troubleshooting & Verification

```bash
# ---- Is KVM actually being used? (should print "KVM") -------------
grep -E "(vmx|svm)" /proc/cpuinfo | head -1
virsh version --daemon         # library + hypervisor versions

# ---- VM CPU speed sanity ----------------------------------------
# Inside the guest run a CPU benchmark; result within ~5-10% of bare
# metal = host-passthrough correct. 10x slower = TCG (no KVM!). Check:
journalctl -b | grep -i "kvm\|vfio" | head

# ---- GPU passed but black screen? -------------------------------
# 1. Dummy plug connected? (§9.1-4)
# 2. vfio-pci bound before nvidia/amdgpu? Check driver per function:
lspci -nnk -d 10de:2204        # "Kernel driver in use: vfio-pci" expected

# ---- IOMMU group too wide ----------------------------------------
dmesg | grep -i iommu
# "AMD-Vi: Interrupt remapping enabled" / "DMAR: IOMMU enabled" expected

# ---- VM fails to start: permission / cgroup device ---------------
# QEMU denied opening /dev/whatever → add it to cgroup_device_acl (§3)
journalctl -u libvirtd -u libvirtqemud --since -5min

# ---- libvirt hook not firing -------------------------------------
# Hooks must exist when libvirtd STARTS (upstream rule):
sudo systemctl restart libvirtd
ls -la /var/lib/libvirt/hooks/qemu.d/   # NixOS symlinks appear here

# ---- Full VM log ------------------------------------------------
sudo cat /var/log/libvirt/qemu/<vmname>.log
```

---

## 20. Reference Index

- NixOS options: <https://search.nixos.org/options> (`virtualisation.*`)
- libvirt domain XML format: <https://libvirt.org/formatdomain.html>
- libvirt hooks (used for one-key launch): <https://libvirt.org/hooks.html>
- VFIO practical guide: Arch Wiki "PCI passthrough via OVMF"
- virtio-win drivers: <https://fedorapeople.org/groups/virt/virtio-win/>
- Looking Glass (next guide): <https://looking-glass.io/docs/B7/>
- QEMU manual: `man qemu-kvm`
- nixpkgs libvirtd module source: `nixos/modules/virtualisation/libvirtd.nix`

Continue to `Looking-Glass-Virtualization-NixOS.md` for: KVMFR shared memory, the DMA (kvmfr module) fast path, client configuration, **one-key hotkey VM launch**, and **single-GPU passthrough**.
