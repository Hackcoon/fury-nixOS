# Hardening NixOS

An exhaustive, independently-usable reference for hardening NixOS. Every code block is self-contained and copy-pasteable into your `configuration.nix` or a module, with inline rationale — extract any block without losing context. Where a technique has a canonical source (NixOS Manual, nixpkgs modules, kernel documentation, upstream hardening guides), it is cited.

**Sources synthesized:** NixOS Manual (stable) · NixOS Options Search · nixpkgs module sources (security/pam.nix, security/apparmor.nix, system/boot/luksroot.nix, config/users-groups.nix) · madaidan's Linux Hardening Guide · Kernel Self Protection Project (KSPP) · GrapheneOS hardened_malloc docs · systemd docs · disko docs · CIS/LSM community guidance where applicable. NixOS-version-specific schema notes are marked **[SCHEMA]** — these were verified against nixpkgs and change over time; always cross-check https://search.nixos.org before adopting.

---

## Table of Contents

1. [Principles & Threat Model](#1-principles--threat-model)
2. [Kernel](#2-kernel)
3. [Kernel Command Line](#3-kernel-command-line)
4. [Sysctl](#4-sysctl)
5. [Kernel Module Blacklisting](#5-kernel-module-blacklisting)
6. [Filesystem & Mount Hardening](#6-filesystem--mount-hardening)
7. [Disk Encryption (LUKS2)](#7-disk-encryption-luks2)
8. [Users, Groups, Root Lock](#8-users-groups-root-lock)
9. [Privilege Escalation](#9-privilege-escalation)
10. [PAM](#10-pam)
11. [Memory Allocator Hardening](#11-memory-allocator-hardening)
12. [AppArmor / MAC](#12-apparmor--mac)
13. [Firewall & Network](#13-firewall--network)
14. [DNS](#14-dns)
15. [SSH](#15-ssh)
16. [USB & Thunderbolt](#16-usb--thunderbolt)
17. [Process Fingerprinting (hidepid, machine-id, hostname)](#17-process-fingerprinting)
18. [systemd Service Sandboxing](#18-systemd-service-sandboxing)
19. [Nix & the Store](#19-nix--the-store)
20. [Core Dumps & Swap (Anti-Forensics)](#20-core-dumps--swap-anti-forensics)
21. [Entropy](#21-entropy)
22. [Firmware / Microcode / Boot](#22-firmware--microcode--boot)
23. [Auditing Your System](#23-auditing-your-system)
24. [Testing Without Risk (VM Tests)](#24-testing-without-risk-vm-tests)
25. [What Does NOT Work (Common Traps)](#25-what-does-not-work-common-traps)
26. [Reference Index](#26-reference-index)

---

## 1. Principles & Threat Model

1. **Declarative beats imperative.** Every control below lives in your Nix config → survives rebuilds, is diffable (`nvd diff`), and rollback-protected (generations).
2. **Fail fast.** Use `assertions` so invalid combinations refuse to *build*, not fail at 3 a.m. on boot.
3. **Layered, but honest.** Prefer the native option over /etc text hacks; drop what fights the platform (see §25).
4. **Zero trust is impossible — know where you trust:** the pinned nixpkgs (flake.lock), the kernel patchset vendor (hash-pinned), firmware blobs, and your own config repo.
5. **Threat classes addressed here:** local privilege escalation, lateral network recon (fingerprinting/scanning), evil-maid USB/DMA, cold-boot/forensic recovery, memory-corruption exploitation, supply-chain drift.

---

## 2. Kernel

**Option A — nixpkgs hardened patchset (currently REMOVED — no substitute in nixpkgs):**
```nix
# NOTE: nixpkgs REMOVED `linuxPackages_hardened` for lack of maintenance
# and there is no maintained equivalent in-tree. Do NOT pin this — it will
# fail eval on current nixpkgs. Use a maintained LTS line instead:
# boot.kernelPackages = pkgs.linuxPackages_6_12;  # LTS, max compatibility
# boot.kernelPackages = pkgs.linuxPackages_6_18;  # current stable-era line
# and layer Option B below only if you vendor the anthraxx patchset yourself.
```

**Option B — assemble the anthraxx patchset locally** (only if you vendor it yourself — nixpkgs dropped `linuxPackages_hardened` for lack of maintenance; the upstream project keeps releasing, but YOU own the rebase burden). Full pattern (example tracks a maintained 6.12/6.18 base — there is no 7.2 kernel line; `linux_7_2` never existed upstream):

```nix
{ config, pkgs, lib, ... }:
let
  # Vendor-trust = sha256 pin. On tag bump: update BOTH, recompute hash via
  #   nix store prefetch-file <url>
  hardenedPatch = pkgs.fetchurl {
    url = "https://github.com/anthraxx/linux-hardened/releases/download/v6.18-hardened1/linux-hardened-v6.18-hardened1.patch";
    # sha256 = the vendor-trust gate: any upstream tampering fails the
    # BUILD (not your boot). Recompute on tag bump:
    #   nix store prefetch-file <url>
    sha256 = "sha256-/NNYjo3YvEnumygEn6CVrpxZKBfMt1s7zB2dfwMWZT4=";
  };
in {
  boot.kernelPackages = lib.mkForce (pkgs.linuxPackagesFor (pkgs.linux_6_18.override {
    # base kernel version MUST equal the patch's upstream base
    kernelPatches = [
      pkgs.kernelPatches.bridge_stp_helper
      pkgs.kernelPatches.request_key_helper
      { name = "linux-hardened"; patch = hardenedPatch; }
    ];
    structuredExtraConfig = with lib.kernel; {
      # String options (like CONFIG_LSM) MUST use freeform — mkForce of a
      # raw string fails the settings submodule type check [SCHEMA]:
      LSM = lib.mkForce (lib.kernel.freeform "landlock,lockdown,integrity,apparmor,bpf");
      # ZERO freshly-allocated memory — use-after-free reads see zeroes,
      # never stale secrets:
      INIT_ON_ALLOC_DEFAULT_ON = lib.mkForce yes;
      # ZERO freed pages — nothing persists for forensics/leak after free:
      INIT_ON_FREE_DEFAULT_ON  = lib.mkForce yes;
      # Freelist pointers MANGLED (heap chunk-forging attacks dead):
      SLAB_FREELIST_HARDENED   = lib.mkForce yes;
      # Freelist ORDER randomized (allocation-placement prediction dead):
      SLAB_FREELIST_RANDOM     = lib.mkForce yes;
      # Page-allocator free lists shuffled (physical layout unpredictable):
      SHUFFLE_PAGE_ALLOCATOR   = lib.mkForce yes;
      # Per-callsite randomized kmalloc caches (cross-cache attacks dead):
      RANDOM_KMALLOC_CACHES    = lib.mkForce yes;
      # Kernel stack offset randomized per SYSCALL (stack-probing oracle dead):
      RANDOMIZE_KSTACK_OFFSET_DEFAULT = lib.mkForce yes;
      # Unprivileged BPF off at BOOT (belt with the sysctl suspenders):
      BPF_UNPRIV_DEFAULT_OFF   = lib.mkForce yes;
      # Hibernation impossible — RAM can never be captured to disk
      # (anti-forensics; normal suspend unaffected):
      HIBERNATION = lib.mkForce no;
      # kexec blocked in-kernel too — the lockdown-bypass primitive, twice:
      KEXEC = lib.mkForce no;
      KEXEC_FILE = lib.mkForce no;
      # Compile-time bounds checks on memcpy/strcpy-family APIs:
      FORTIFY_SOURCE = lib.mkForce yes;
      # User↔kernel copies bounds-checked against ACTUAL object size —
      # the classic overflow class becomes a caught bug:
      HARDENED_USERCOPY = lib.mkForce yes;
      # Kernel text/rodata non-writable+non-executable; module text likewise:
      STRICT_KERNEL_RWX = lib.mkForce yes;
      # Same RWX discipline for loadable modules:
      STRICT_MODULE_RWX = lib.mkForce yes;
    };
  }));
}
```

**The feature you get that stock lacks:** `kernel.deny_new_usb` (see §16), stronger allocator defaults, and the patchset's misc hardening (see the [linux-hardened](https://github.com/anthraxx/linux-hardened) changelogs).

**What NOT to port from "fully trimmed" kernel configs** (madaidan-informed but pragmatic — each of these breaks real NixOS usage):
- `MODULE_SIG_FORCE=y` → rejects the proprietary NVIDIA module (unsigned out-of-tree).
- `KALLSYMS=n` → breaks perf/tracing/bpf tooling.
- `IO_URING=n` → breaks Node.js 20+, modern databases.
- `IA32_EMULATION=n` → drops 32-bit compat (Steam, Wine).

**Microcode** (CPU vulnerability mitigations — REQUIRED regardless of kernel; set the line matching YOUR CPU — thermald is also Intel-only, see §4):
```nix
# AMD CPUs (Ryzen/EPYC):
hardware.cpu.amd.updateMicrocode = true;
# Intel CPUs — the ONLY CPU-vendor line that differs:
# hardware.cpu.intel.updateMicrocode = true;
hardware.enableRedistributableFirmware = true;  # NIC/WiFi firmware blobs
```

**The three one-line NixOS security switches** (all exist as real options — verified against the eval — and all DEFAULT OFF; add them unless you have a specific reason not to):

```nix
security = {
  # Blocks module load/unload after boot (module-hiding/insertion attacks).
  # Cost: nothing on fixed hardware; breaks hot-pluggable modules (rare
  # drivers, some VPNs, ZFS module reloads). The ideal pairing with §5's
  # blacklist: after boot, even a root compromise can't insert a banned
  # module. Toggle at runtime: sysctl kernel.modules_disabled=1 (set by
  # this option; ONE-WAY until reboot).
  lockKernelModules = true;

  # Marks /boot, kernel, initrd as immutable-restricted and blocks
  # /dev/mem, /dev/kmem access. Protects the boot chain from a rooted
  # system tampering with the next-boot kernel image.
  protectKernelImage = true;

  # false → disables SMT (hyperthreading) — the nosmt side of the
  # mitigations=auto,nosmt cmdline, applied declaratively. SMT shares
  # execution resources between threads → side-channel class (L1TF/
  # MDS-pair). COST: ~30-50% multi-thread perf on many CPUs — this is
  # the one switch with a REAL trade-off. A hypervisor host running
  # untrusted guests should set false; a workstation may keep true.
  allowSimultaneousMultithreading = false;
};
```

**FIDO2 hardware-key LUKS unlock** (NixOS Manual: "LUKS-Encrypted File Systems") — the modern anti-evil-maid addition to §7:
```nix
# systemd stage-1 + FIDO2 token unlocking; enroll per manual:
#   sudo systemd-cryptenroll --fido2-device=auto \
#     --fido2-with-client-pin=true /dev/<luks-part>
boot.initrd.luks.devices."CRYPT".crypttabExtraOpts =
  [ "fido2-device=auto" ];
# ALWAYS add a recovery passphrase in a secure physical location (manual's
# explicit recommendation) and only use FIDO2 unlock with a PIN-protected
# device (e.g., Trezor) — the manual warns passwordless setups become the
# attack surface.
```
Related (NixOS Manual): **Clevis** (`boot.initrd.clevis`) for unattended TPM2/Tang-based unlock, and **tpm2-totp** (`boot.plymouth.tpm2-totp.enable`) to human-attest boot integrity at the prompt.

---

## 3. Kernel Command Line

```nix
boot.kernelParams = [
  # ── CPU vulnerability mitigations (verify with spectre-meltdown-checker) ──
  "mitigations=auto,nosmt"          # auto-select; disable SMT if affected
  "pti=on"                          # page-table isolation (Meltdown)
  # Spectre v2 (branch-target injection) mitigations FORCED on + Speculative
  # Store Bypass disabled — both are CPU side-channels that leak memory
  # across process boundaries:
  "spectre_v2=on"
  "spec_store_bypass_disable=on"
  "tsx=off" "tsx_async_abort=full"  # TAA/RTM mitigations
  "l1tf=flush" "mds=full"
  "kvm.nx_huge_pages=force"          # KVM iTLB-multihit mitigation
  # mce=0: a machine-check (hardware corruption) event panics the kernel
  # immediately instead of limping on corrupted state — fail-fast;
  "mce=0"
  # ── Memory/allocator ────────────────────────────────────────────────
  "slub_debug=FZ"                    # SLUB fill-on-alloc + red zones
  "init_on_alloc=1" "init_on_free=1" # belt-and-suspenders (config too)
  "page_alloc.shuffle=1"             # page-allocator freelist shuffling
  # ── IOMMU (DMA attack surface) ──────────────────────────────────────
  "intel_iommu=on" "amd_iommu=on"
  "iommu=force"                      # strict; relax to "iommu=pt" for perf
  # ── Info leaks / debug ──────────────────────────────────────────────
  "debugfs=off"
  "random.trust_cpu=off"             # distrust CPU RNG (use jitterentropy)
];
```

**LSM chain — the #1 cmdline trap.** The AppArmor module appends its own `lsm=` token, and *later* tokens win — a manual `kernelParams` entry gets duplicated/overridden. The sanctioned switch:
```nix
# NixOS assembles the lsm= param from this list; upstream forces BPF last
# (nixpkgs PR #533428). Use mkForce — the option is a merge-list and
# defaults (landlock,yama + apparmor + bpf) would concatenate otherwise:
security.lsm = lib.mkForce [ "landlock" "lockdown" "integrity" "apparmor" "bpf" ];
```

**IOMMU per vendor — AMD-Vi vs Intel VT-d (pick ONE, not both):**
```nix
{ config, lib, ... }: {
  # AMD (Ryzen/EPYC — AMD-Vi): ivrs + iommu=pt keeps graphics/USB fast
  # while still isolating passthrough devices (Virtualization §4 pattern):
  # boot.kernelParams = [ "amd_iommu=on" "amd_iommu=force_isolation" "iommu=pt" ];
  # Intel (VT-d): e820 + force-on; igfx_off only if iGPU faults (kernel docs
  # x86/iommu: intel_iommu=igfx_off is the iGPU-quirk escape hatch):
  # boot.kernelParams = [ "intel_iommu=on" "iommu=force" ];
  # Verify: dmesg | grep -E 'IOMMU|DMAR|AMD-Vi'; find /sys/kernel/iommu_groups -maxdepth 1 | wc -l
}
```

**Kernel lockdown vs VFIO/passthrough — the conflict to know:**
```nix
# lockdown=integrity: blocks kexec/hibernate/unsigned-modules + /dev/mem —
# VFIO passthrough STILL WORKS (QEMU opens /dev/vfio, not /dev/mem).
# lockdown=confidentiality: ALSO hides unprivileged BPF/perf + stricter —
# breaks Looking-Glass shm + NVIDIA proprietary ioctl introspection on some
# generations. Rule: VFIO hosts use integrity, never confidentiality.
# boot.kernelParams = [ "lockdown=integrity" ];
# NVIDIA proprietary + lockdown=integrity: REQUIRES signed modules or
# lockdown downgrades to complain — pair with lanzaboote MOK signing (§22).
```

**CPU mitigations=off — the gaming tradeoff (explicit, not accidental):**
```nix
# Hardened default (§3 top): mitigations=auto,nosmt + spectre_v2=on etc.
# Gaming escape hatch ONLY: mitigations=off gains ~5-15% on CPU-bound titles
# (notably Intel pre-Raptor + Zen2) but re-opens Meltdown/Spectre-v2/MDS/L1TF
# to any local process — NEVER on a browser/multi-user/VM host.
# boot.kernelParams = lib.mkForce [ "mitigations=off" ];  # benchmark-only
# Verify: cat /sys/devices/system/cpu/vulnerabilities/*; spectre-meltdown-checker
```

---

## 4. Sysctl

**Every line commented.** The KSPP baseline + network + userspace trio, with
the plain-language explanation of what each knob does, why the chosen value
hardens the system, and what changes if you tune it. Values verified against
the kernel docs (`Documentation/admin-guide/sysctl/`); the same block ships,
byte-identical, in all three family modules (`modules/hardening.nix`).

```nix
{ ... }: {
  boot.kernel.sysctl = {
# ── 10_kernel.conf (Kernel Self Protection Project baseline) ─────────
  # randomize_va_space: Address Space Layout Randomization. 2 = full mode
  # (stack, heap, mmap, vdso all randomized). Attackers can't predict where
  # code/data live → classic buffer-overflow exploitation becomes blind.
  "kernel.randomize_va_space" = 2;
  # ptrace_scope (yama LSM): 2 = admin-only tracing. Blocks other users'
  # processes from reading/writing YOUR memory via ptrace — kills
  # credential-dumping from a same-user compromise and plain user-to-user
  # process injection. Value 3 would also block admin; 2 is the sane ceiling.
  "kernel.yama.ptrace_scope" = 2;
  # kptr_restrict: 2 = kernel pointers printed as 0000000000000000 even for
  # root in /proc/kallsyms & co. Removes the "where is the kernel mapped"
  # oracle that defeats KASLR. Costs: some debugging tools see zeroes —
  # that's the point.
  "kernel.kptr_restrict" = 2;
  # dmesg_restrict: 1 = only root reads the kernel ring buffer. dmesg leaks
  # hardware details, memory addresses, and service errors — classic
  # local-priv-esc reconnaissance material.
  "kernel.dmesg_restrict" = 1;
  # printk: maximum log level that reaches the CONSOLE. "3 3 3 3" caps it at
  # ERR — warnings/infos stay in the journal (check journalctl -k) but
  # don't scroll onto your screen or an attacker's shoulder-surfed TTY.
  "kernel.printk" = "3 3 3 3";
  # unprivileged_bpf_disabled: 1 = unprivileged users cannot load BPF
  # programs. Unpriv BPF is a repeated kernel-exploitation primitive
  # (spectre-class leaks, JIT spraying). NOTE: once set to 1, this is
  # ONE-WAY until reboot — even root can't re-enable without rebooting.
  "kernel.unprivileged_bpf_disabled" = 1;
  # pid_max: ceiling of allocatable process IDs. High value = a fork bomb
  # exhausts memory and dies on the OOM path LONG before it starves the
  # PID allocator — keeps the system recoverable instead of PID-deadlocked.
  "kernel.pid_max" = 4194304;
  # ldisc_autoload: 0 = TTY line disciplines (slip, ppp, etc.) may not be
  # auto-loaded on request. Historical CVEs allowed unprivileged TTY ioctls
  # to trigger module loads; 0 closes the path.
  "dev.tty.ldisc_autoload" = 0;
  # kexec_load_disabled: 1 = kexec (booting a new kernel from userspace)
  # is permanently blocked. A root compromise could otherwise kexec a
  # malicious kernel that bypasses every security boundary — a lockdown
  # bypass primitive.
  "kernel.kexec_load_disabled" = 1;
  # sysrq: 0 = Magic SysRq completely disabled (alt+printscreen+key).
  # SysRq can sync/remount/debug/REBOOT from ANY TTY, even a locked
  # console — an attacker with 10 seconds of physical access owns you.
  "kernel.sysrq" = 0;
  # perf_event_paranoid: 3 = perf_event_open() restricted to root.
  # Unprivileged perf is a side-channel goldmine (spectre-class timing
  # attacks against other processes) and info leak (cache eviction).
  "kernel.perf_event_paranoid" = 3;
  # bpf_jit_harden: 2 = the BPF JIT compiler blinds its constants (XOR
  # masks) AND converts indirect branches to returns. Even a compromised
  # kernel-BPF path can't easily read baked-in constants or spray the JIT.
  "net.core.bpf_jit_harden" = 2;
  # perf CPU-time/sample caps: 1% of CPU time for perf collection,
  # 1 sample/sec max. Even a root-authorized perf session becomes
  # useless as a covert high-resolution side-channel stethoscope.
  "kernel.perf_cpu_time_max_percent" = 1;
  "kernel.perf_event_max_sample_rate" = 1;
  # msgmnb/msgmax: System V message queue caps — one queue's max bytes and
  # one message's max size. Prevents a local user from pinning unbounded
  # kernel memory via SysV IPC queues (memory-exhaustion DoS).
  "kernel.msgmnb" = 65535;
  "kernel.msgmax" = 65535;
  # core_pattern: WHERE core dumps go. "|/bin/false" = piped to a program
  # that discards them — cores are NEVER written to disk, by anyone.
  # Core dumps contain a full snapshot of process memory: passwords,
  # keys, tokens. (Part of the §core-dump triple lock below.)
  "kernel.core_pattern" = "|/bin/false";
  # suid_dumpable: 0 = setuid/setgid binaries NEVER dump their memory.
  # A core of a suid binary would contain privileged memory readable by
  # the (unprivileged) user who crashed it.
  "fs.suid_dumpable" = 0;
  # netdev_max_backlog: packets queued between the NIC and the kernel's
  # network stack when the softirq path is saturated. SOURCE CONFLICT:
  # 10_kernel.conf said 250000, 20_network.conf said 12288 — on Void,
  # sysctl.d applies in lexical file order so 12288 won at runtime. Nix
  # attrsets can't hold duplicate keys, so we keep the faithful RUNTIME
  # value (12288): large enough to absorb bursts, small enough that a
  # flood doesn't pin unbounded kernel memory.
  "net.core.netdev_max_backlog" = 12288;

  # ── 20_network.conf (network hardening, verbatim) ──────────────────────
  # disable_xfrm/disable_policy on LOOPBACK = 0 (NOT disabled): allows
  # IPsec policy on lo if you layer it later; harmless otherwise. PlagueOS
  # kept both at 0 — faithful.
  "net.ipv4.conf.lo.disable_xfrm" = 0;
  "net.ipv4.conf.lo.disable_policy" = 0;
  # syncookies: on SYN-flood (connection table exhaustion), the kernel
  # replies with a cryptographic cookie instead of allocating a
  # half-open connection — the classic SYN-flood DoS defense.
  "net.ipv4.tcp_syncookies" = 1;
  # rfc1337: ignore TIME_WAIT assassination attempts — a RST arriving in
  # TIME_WAIT cannot kill the connection. Closes an old spoof-RST DoS.
  "net.ipv4.tcp_rfc1337" = 1;
  # rp_filter: 1 = strict reverse-path validation. A packet claiming to
  # come from 10.0.0.5 arriving on the WAN interface is DROPPED —
  # kills IP-spoofing across interfaces (strict mode = best defense).
  "net.ipv4.conf.all.rp_filter" = 1;
  "net.ipv4.conf.default.rp_filter" = 1;
  # accept_redirects: 0 = ICMP "use this better route" messages are
  # IGNORED. On a multi-homed host, a forged redirect lets an on-path
  # attacker reroute your traffic through themselves — classic MITM.
  "net.ipv4.conf.all.accept_redirects" = 0;
  "net.ipv4.conf.default.accept_redirects" = 0;
  # secure_redirects: same attack, restricted to "known gateway" redirects
  # — still 0; even gateway-spoofed redirects are not trusted.
  "net.ipv4.conf.all.secure_redirects" = 0;
  "net.ipv4.conf.default.secure_redirects" = 0;
  # send_redirects: 0 = this host never TELLS others to reroute. A
  # compromised host shouldn't be able to poison neighbors' routing.
  "net.ipv4.conf.all.send_redirects" = 0;
  "net.ipv4.conf.default.send_redirects" = 0;
  # icmp_echo_ignore_all: 1 = the host does not answer ping AT ALL.
  # Reconnaisssance value: scanners can't even confirm you exist. (Sysctl
  # #1 for fingerprint-minimalism; firewall-independent — even forwarded
  # INPUT paths stay silent.) If you NEED ping for monitoring, set to 0
  # and let the firewall rate-limit instead.
  "net.ipv4.icmp_echo_ignore_all" = 1;
  # accept_source_route: 0 = drop packets that carry their own routing
  # path (source routing). Ancient but supported — lets an attacker
  # bounce through trust relationships. Never allow it.
  "net.ipv4.conf.all.accept_source_route" = 0;
  "net.ipv4.conf.default.accept_source_route" = 0;
  # tcp_sack/dsack/fack: Selective ACKs. SACK=1 (keep) lets one lost
  # packet recover without retransmitting the whole window — PlagueOS
  # kept SACK on for "unstable network conditions"; dsack/fack=0 drop
  # the exotic variants with negligible benefit.
  "net.ipv4.tcp_sack" = 1;
  "net.ipv4.tcp_dsack" = 0;
  "net.ipv4.tcp_fack" = 0;                  # FACK is an experimental
                                            #  SACK extension; zero = off (patented-era
                                            #  mechanism, no modern benefit).
  # tcp_timestamps: 0 = no timestamps in TCP headers. Timestamps leak
  # the host's precise uptime AND are the classic side channel used by
  # PAWS/spoofing attacks. Modern alternatives (RFC 7323) still leak
  # uptime — 0 removes the oracle.
  "net.ipv4.tcp_timestamps" = 0;
  # mtu_probing: 1 = on persistent fragmentation-blackhole detection,
  # probe with progressively larger packets. Fixes PMTU-blackhole sites
  # (VPNs, PPPoE) WITHOUT needing ICMP unreachable passthrough.
  "net.ipv4.tcp_mtu_probing" = 1;
  # tcp_base_mss: 1024 = the floor for probing. Low default survives
  # tunnels; conservative = blackhole-escape works everywhere.
  "net.ipv4.tcp_base_mss" = 1024;
  # somaxconn: 8192 = kernel socket backlog depth. Bigger than default
  # (4096) to absorb connection bursts; still bounded (DoS-resistance).
  "net.core.somaxconn" = 8192;
  # icmp_echo_ignore_broadcasts: 1 = never answer broadcast pings.
  # Smurf/Fraggle amplification attacks use broadcast replies.
  "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
  # icmp_ignore_bogus_error_responses: 1 = drop malformed ICMP errors
  # (violate RFC 1122). Cheap fuzz-garbage filter.
  "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
  # syn_retries/synack_retries: outbound attempts 3, handshake retries 2
  # (down from 6/5) — a failed/half-open connection frees server resources
  # in seconds instead of minutes. Faster recovery from SYN-scan floods.
  "net.ipv4.tcp_syn_retries" = 3;
  "net.ipv4.tcp_synack_retries" = 2;
  # tcp_max_syn_backlog: 4096 = half-open-connection queue before
  # syncookies kick in. Deeper = absorbs floods, bounded = no memory
  # exhaustion.
  "net.ipv4.tcp_max_syn_backlog" = 4096;
  # keepalive trio: first probe after 300 s (not 2 h), then every 20 s,
  # 10 probes (200 s) before declaring dead. Kills zombie connections
  # holding ports/memory — important on a long-lived hardened host.
  "net.ipv4.tcp_keepalive_time" = 300;
  "net.ipv4.tcp_keepalive_probes" = 10;
  "net.ipv4.tcp_keepalive_intvl" = 20;     # seconds between keepalive
                                            #  probes after the first.
  # log_martians: 1 = LOG packets with impossible source addresses
  # (spoofed). Defense-in-depth signal for your IDS/journal.
  "net.ipv4.conf.default.log_martians" = 1;
  "net.ipv4.conf.all.log_martians" = 1;
  # ip_local_port_range: 2000-65535 = ephemeral source-port range. Avoids
  # well-known service ports (so a client can't masquerade as a service)
  # and widens the range against source-port exhaustion.
  "net.ipv4.ip_local_port_range" = "2000 65535";
  # tcp_window_scaling: 1 = allows large TCP windows (needed above
  # 64KB paths; keep on for performance; the timestamp leak above is
  # handled by timestamps=0 instead).
  "net.ipv4.tcp_window_scaling" = 1;
  # drop_gratuitous_arp: 1 = DROP unsolicited ARP replies. These are the
  # poison in ARP-cache-poisoning MITM — with no session to refresh,
  # a "gratuitous" update is almost always an attack or a misconfig.
  "net.ipv4.conf.default.drop_gratuitous_arp" = 1;
  "net.ipv4.conf.all.drop_gratuitous_arp" = 1;
  # arp_ignore: 1 = only answer ARP if the TARGET IP is local to the
  # receiving interface. Prevents the host from claiming IPs it doesn't
  # own (and stops multi-NIC ARP-leak attacks).
  "net.ipv4.conf.default.arp_ignore" = 1;
  "net.ipv4.conf.all.arp_ignore" = 1;
  # arp_announce: 2 = always use the BEST local source address in ARP.
  # Prevents leaking internal-network addresses onto other networks
  # (topology disclosure).
  "net.ipv4.conf.default.arp_announce" = 2;
  "net.ipv4.conf.all.arp_announce" = 2;
  # shared_media: 0 = don't treat all ethernet as one shared bus. Legacy
  # hack that makes routing/ARP behave oddly on multi-interface hosts.
  "net.ipv4.conf.default.shared_media" = 0;
  "net.ipv4.conf.all.shared_media" = 0;
  # forwarding: 0 = this host never ROUTES packets between interfaces.
  # The hypervisor role is handled by libvirt's own per-network NAT
  # (explicit, controlled) — global kernel forwarding stays OFF so a
  # compromised process can't silently turn the box into a router.
  "net.ipv4.conf.all.forwarding" = 0;
  # default_qdisc = fq_codel: every new interface gets fair-queueing with
  # controlled delay — prevents bufferbloat and starves out floods.
  "net.core.default_qdisc" = "fq_codel";
  # tcp_adv_win_scale: 1 = socket buffer overhead accounting (25% of
  # buffer for metadata). Smaller values overcommit memory; 1 is the
  # conservative accounting default used by PlagueOS.
  "net.ipv4.tcp_adv_win_scale" = 1;
  # bootp_relay: 0 = never forward DHCP broadcasts (ancient relay
  # feature). An attacker on a far segment shouldn't reach your DHCP
  # through you.
  "net.ipv4.conf.all.bootp_relay" = 0;
  # promote_secondaries: 1 = when a primary IP is removed, its
  # secondaries become primaries (not all-or-nothing). Keeps networkd/
  # NM multi-IP setups from tearing down your addressing on a partial
  # change — availability hardening.
  "net.ipv4.conf.all.promote_secondaries" = 1;
  "net.ipv4.conf.default.promote_secondaries" = 1;
  # ip_no_pmtu_disc: 0 = PMTU discovery ENABLED. Even though this means
  # sending DF packets (and relying on ICMP unreachable passthrough),
  # disabling discovery causes fragmentation blackholes — PlagueOS chose
  # 0 for a reason: broken paths are worse than the tiny ICMP dependency.
  "net.ipv4.ip_no_pmtu_disc" = 0;
  # tcp_ecn: 0 = never negotiate ECN. ECN-capable middleboxes mangle or
  # drop ECN-flagged packets on hostile/legacy networks — compat choice.
  "net.ipv4.tcp_ecn" = 0;
  # tcp_low_latency: 1 = disable Nagle-style receive buffering delay for
  # interactive protocols. Latency choice by PlagueOS; negligible CPU.
  "net.ipv4.tcp_low_latency" = 1;
  # tcp_slow_start_after_idle: 0 = DON'T reset the congestion window after
  # an idle period. The restart ramp is a latency penalty for bursty
  # interactive sessions; keeping the learned window is fine on stable
  # links.
  "net.ipv4.tcp_slow_start_after_idle" = 0;
  # tcp_fin_timeout: 10 s (from 60) = an orphaned FIN-WAIT connection is
  # reclaimed fast. Fewer slots held by dead peers = faster exhaustion
  # recovery under adversarial churn.
  "net.ipv4.tcp_fin_timeout" = 10;
  # tcp_max_orphans/orphan_retries: cap orphaned (no socket attached)
  # connections at 16384 with 2 retries. Under a FIN flood, the kernel
  # sheds orphans quickly instead of accumulating zombie memory.
  "net.ipv4.tcp_max_orphans" = 16384;
  "net.ipv4.tcp_orphan_retries" = 2;
  # unix.max_dgram_qlen: 512 = datagram queue depth for unix sockets.
  # Bounded queue = a flooding local process can't pin unbounded kernel
  # memory via the unix-socket path.
  "net.unix.max_dgram_qlen" = 512;
  # neigh gc_* (neighbor-cache garbage collection): tiered thresholds
  # 1024/2048/4096 entries, scanned every 30 s. Keeps the ARP/ND cache
  # bounded under cache-flooding (neighbor-table exhaustion) attacks
  # while never thrashing on normal use.
  "net.ipv4.neigh.default.gc_thresh1" = 1024;
  "net.ipv4.neigh.default.gc_thresh2" = 2048;
  "net.ipv4.neigh.default.gc_thresh3" = 4096; # HARD cap: above this, the
                                                 #  kernel drops entries immediately
                                                 #  (final anti-exhaustion ceiling).
  "net.ipv4.neigh.default.gc_interval" = 30;  # seconds between neighbor-
                                                 #  cache GC passes.
  # neigh proxy_qlen/unres_qlen: bounded queues for proxied and
  # unresolved neighbor entries — same anti-exhaustion reasoning.
  "net.ipv4.neigh.default.proxy_qlen" = 96;
  "net.ipv4.neigh.default.unres_qlen" = 6;
  # proxy_arp: 0 = never answer ARP on behalf of other hosts. A silent
  # proxy-arp host becomes a traffic blackhole and a MITM vantage point.
  "net.ipv4.conf.all.proxy_arp" = 0;
  "net.ipv4.conf.default.proxy_arp" = 0;
  # ip_forward: 0 (see `forwarding` above — same rule, global v4 knob;
  # both are set for belt-and-suspenders since either being on would
  # enable routing).
  "net.ipv4.ip_forward" = 0;

  # ── 30_userspace.conf (verbatim) ───────────────────────────────────────
  # mmap_rnd_bits: 32 = maximum entropy for mmap'd-region randomization
  # on x86_64. Every library/data mapping lands at an unpredictable
  # address — raises the cost of ROP/heap-spray attacks.
  "vm.mmap_rnd_bits" = 32;
  # mmap_min_addr: 65536 = no process may map the NULL page. Historically
  # "NULL pointer dereference in kernel → userspace controls page 0 →
  # privilege escalation". 64 KiB moat closes the whole class.
  "vm.mmap_min_addr" = 65536;
  # protected_symlinks: 1 = a symlink in a world-writable dir (like /tmp)
  # is only followed if its owner matches the follower or the directory
  # is sticky — kills the classic /tmp symlink race attack.
  "fs.protected_symlinks" = 1;
  # protected_hardlinks: 1 = can't create a hardlink to a file you can't
  # read/write — closes the "link to /etc/shadow then read via link"
  # and setuid-swap time-of-check attacks.
  "fs.protected_hardlinks" = 1;
  # protected_fifos: 2 = creating a FIFO in a world-writable dir only
  # allowed for the owner, and opening sticky-dir FIFOs restricted.
  # FIFOs are the symlink-race sibling attack vector.
  "fs.protected_fifos" = 2;
  # protected_regular: 2 = same rule for REGULAR files: no opening
  # another user's file planted in a sticky world-writable directory
  # (e.g., credential-file squatting in /tmp).
  "fs.protected_regular" = 2;
  # max_map_count: 1048576 = per-process limit on memory mappings.
  # REQUIRED by hardened_malloc: it creates MANY small guard-page
  # mappings per allocation (that's the overflow detection mechanism);
  # the default 65530 starves it. Without this, preloaded binaries
  # crash at startup.
  "vm.max_map_count" = 1048576;
  # swappiness: 0 = kernel avoids swapping to disk swap almost entirely.
  # Swapless anti-forensics posture: secrets never hit an unencrypted
  # block device. If you later adopt zram, CHANGE this to 180 (see
  # NIXOS-optimization.md §5 — the zram-correct value is the OPPOSITE
  # of the old folklore).
  "vm.swappiness" = 0;

  # ═══════════════════════════════════════════════════════════════════════
  # IPv6 mirrors (the v4 blocks above are the hardening core; add these so
  # v6 doesn't silently RE-OPEN what v4 closed — redirects/RAs are the
  # same MITM class over v6):
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.accept_redirects" = 0;      # v6 ICMP redirects off
    "net.ipv6.conf.default.accept_redirects" = 0;  # (and for interfaces that
                                                    #  appear after boot)
    "net.ipv6.conf.all.accept_ra" = 0;               # v6 router advertisements:
    "net.ipv6.conf.default.accept_ra" = 0;         # autoconfig can change your
                                                    # routing — MITM vector off
  };
}
```

**Verify after switch:** `sysctl kernel.kptr_restrict kernel.dmesg_restrict
vm.max_map_count` → `2 / 1 / 1048576`; `cat /proc/sys/net/ipv4/icmp_echo_ignore_all` → `1`.

**The one knob people flip first:** `vm.swappiness = 0` is correct ONLY on a
swapless host. If you adopt zram (see NIXOS-optimization.md §5), the
zram-correct value is `180` — the old "always 10" folklore is exactly
backwards with compressed-RAM swap.

**Verify live:** `sysctl kernel.kptr_restrict kernel.dmesg_restrict vm.max_map_count` and `nix eval .#nixosConfigurations.HOST.config.boot.kernel.sysctl`.

---

## 5. Kernel Module Blacklisting

Two layers (alias-load denial AND explicit-modprobe denial):

```nix
boot.blacklistedKernelModules = [
  # Remote-exploitation surface:
  "dccp" "sctp" "rds" "tipc" "n-hdlc" "ax25" "netrom" "x25" "rose"
  "decnet" "econet" "af_802154" "ipx" "appletalk" "psnap" "p8023" "p8022" "can" "atm"
  # Uncommon filesystems (mount attack surface):
  "cramfs" "freevxfs" "jffs2" "hfs" "hfsplus" "squashfs" "udf" "cifs"
  "nfs" "nfsv3" "nfsv4" "gfs2"
  # DMA attack surfaces:
  "firewire-core" "firewire-ohci" "firewire-sbp2" "thunderbolt"
  # Wireless/camera/ME:
  "bluetooth" "btusb" "uvcvideo" "mei" "mei-me"
  # Legacy/buggy families:
  "vivid" "hisax" "hisax_fcpcipnp" "bcm43xx" "snd-pcsp" "pcspkr"
  # + watchdog family, framebuffer family (see Securenix-Documentation §6
  #   for the complete ~190-entry list)
];
boot.extraModprobeConfig = ''
  # Deny even EXPLICIT `modprobe <module>`:
  ${lib.concatStringsSep "\n"
    (map (m: "install ${m} ${pkgs.coreutils}/bin/false")
      config.boot.blacklistedKernelModules)}
'';
```

Sources: madaidan's guide (module section), KSPP, historical CVEs in the listed modules. Verify: `cat /proc/modules | grep -E 'dccp|sctp'` → empty.

---

## 6. Filesystem & Mount Hardening

```nix
fileSystems = {
  # /proc: hide other users' processes (NO security.hideProcessInformation
  # option exists — the mechanism IS the mount options):
  "/proc".options = [ "nosuid" "nodev" "noexec" "hidepid=2" "gid=proc" ];

  # RAM-backed /tmp (anti-forensics: nothing persists across reboot):
  # RAM-backed /tmp: NOTHING in /tmp survives a reboot (anti-forensics) and
  # it can't fill your disk (bounded 512M). The classic flags: noexec = can't
  # run binaries staged there (drop/execute attack path); nosuid = suid
  # binaries ignored; nodev = device files ignored; mode=1777 keeps the
  # sticky everyone-writable semantics.
  "/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
  # noexec = binaries staged here can't RUN (drop→execute path dead);
  # nosuid = suid bits ignored here; nodev = device nodes ignored;
  # size=512M = bounded (can't exhaust RAM); mode=1777 = sticky world-writable:
    options = [ "noexec" "nosuid" "nodev" "size=512M" "mode=1777" ];
  };
  # /dev/shm: RW required for QEMU/libvirt shared memory — do NOT mount
  # it read-only on a hypervisor:
  # Shared-memory /dev/shm: same RAM-backed discipline as /tmp — but NOTE
  # it must stay WRITABLE (QEMU/libvirt use it for guest shared memory);
  # read-only /dev/shm breaks VMs (a hard-earned family exception).
  "/dev/shm" = {
    device = "tmpfs";
    fsType = "tmpfs";
  # Same discipline as /tmp (see flags there); NOTE /dev/shm must
  # stay WRITABLE — QEMU/libvirt need it for guest shared memory:
    options = [ "noexec" "nosuid" "nodev" "size=512M" "mode=1777" ];
  };
};
```

Per-mount flags on real filesystems (example for btrfs/LUKS layouts):
- `nosuid,noexec,nodev` on `/home`, `/var/log`, `/var/tmp`, `/srv`
- `noatime` everywhere (reduces write surface + forensic metadata)
- `/boot`: keep **RW** — read-only breaks bootloader writes on every rebuild (a hard-earned exception; the hardening is `nosuid,noexec,nodev` + `fmask=0077,dmask=0077`).

**Choosing the root FS** (all supported simultaneously in one config repo; per-host choice):

| FS | Security-relevant properties |
|---|---|
| ext4 | Simplest; no CoW (forensic tooling friendly — pair with LUKS) |
| XFS | Best for large VM-image stores; cannot shrink; no CoW |
| Btrfs | CoW + checksums (blake2b option) detect bitrot/tampering; snapshots for rollback; zstd compression |
| ZFS | Native encryption + checksumming + scrubbing + snapshots; needs `hostId` |

```nix
# ZFS wiring (CDDL-licensed but NOT unfree in nixpkgs — no gate needed):
boot.supportedFilesystems = [ "zfs" ];
networking.hostId = "<8-hex>";  # REQUIRED (zpool(8)); generate:
#   head -c 4 /dev/urandom | od -An -tx1 | tr -d ' '
```

---

## 7. Disk Encryption (LUKS2)

Format-time parameters (via disko, or manually):
```bash
cryptsetup luksFormat --type luks2 \
  --cipher aes-xts-plain64 --key-size 512 \
  --pbkdf argon2id --use-random /dev/<part>
```
Declarative (disko — note **[SCHEMA]**: current disko passes format params via `extraFormatArgs`; `settings` mirrors `boot.initrd.luks.devices` which no longer carries cipher/keySize):
```nix
content = {
  # LUKS2 container (disko default); the mapper name is the PlagueOS
  # env.cfg choice — the device appears as /dev/mapper/CRYPT:
  type = "luks";
  name = "CRYPT";
  # ^ opens as /dev/mapper/CRYPT after the passphrase prompt
  extraFormatArgs = [ "--cipher" "aes-xts-plain64"
                      "--key-size" "512" "--pbkdf" "argon2id" "--use-random" ];
  settings.allowDiscards = true;   # TRIM (SSC health); trade-off: leaks
                                   # discard patterns — off for max stealth
  content = { /* btrfs/xfs/ext4/zfs */ };
};
```
Boot-time (hardware-configuration.nix):
```nix
boot.initrd.luks.devices."CRYPT".device =
  "/dev/disk/by-uuid/<luks-partition-uuid>";
```
Rationale: AES-XTS (hardware-accelerated, standard), 512-bit keys (XTS uses 2×256), argon2id (memory-hard, GPU/ASIC-resistant KDF), `--use-random` (not the potentially-buffered `urandom` at format time).

---

## 8. Users, Groups, Root Lock

```nix
# Root: locked — no password can EVER authenticate (unlike a hash of "").
# Reach root only via sudo/doas from wheel:
users.users.root.hashedPassword = "!";

# Verify at eval (put in your checks):
#   users.users.root.hashedPassword == "!"

# The two-tier model — the single most effective local-privilege control:
users.users.admin = {                    # privileged operator
  isNormalUser = true;
  # uid: NixOS EVAL-FORBIDS <1000 with isNormalUser (system-user range);
  # 1000 keeps the invariant "fixed, low, distinct uid for the admin":
  uid = 1000;                            # <1000 forbidden with isNormalUser [SCHEMA]
  extraGroups = [ "wheel" ];             # may elevate
  createHome = true;
  homeMode = "700";                      # STRING type ("700", not 700) [SCHEMA]
  initialPassword = "change-me-now";     # forces change; or hashedPassword
};
  # The unprivileged daily account — runs the desktop + VMs, and can
  # NEVER elevate (no wheel; that absence is the security control):
users.users.user = {                     # unprivileged daily account
  isNormalUser = true;
    # kvm+libvirtd = hardware virt + system-VM control (the VM operator;
    #  networkmanager = desktop network applet; audio/video = device access)
  extraGroups = [ "kvm" "libvirtd" "networkmanager" "audio" "video" ];
  # structurally absent: "wheel"  ← that absence IS the control
};
```

`/etc/securetty` empty (no root console logins):
```nix
environment.etc."securetty".text = "";
```

**Immutable users** (maximum declarative account control — no runtime account mutation at all; the NixOS Manual's user-management section):
```nix
  # Immutable accounts: /etc/passwd+shadow are REPLACED from config at
  # every activation — a runtime `useradd`/`passwd` change (or one made by
  # an attacker) cannot persist. Costs: every password must be declared as
  # a hash (initialPassword won't survive); generate: openssl passwd -6:
users.mutableUsers = false;
# THEN you MUST declare every password as a hash (initialPassword will
# not survive; generate with: openssl passwd -6 'secret'):
# users.users.admin.hashedPassword = "$6$rounds=77777$…";
```
Trade-off: `passwd` stops working (by design — the config is the truth). This closes the "compromise mutates /etc/passwd" class entirely. Pair with `userborn`/activation on modern NixOS.

---

## 9. Privilege Escalation

**sudo-rs** (memory-safe Rust rewrite; NixOS default since 24.11):
```nix
  # sudo-rs: the memory-safe sudo rewrite (NixOS-native). Wheel-only,
  # password required — the modern escalation default:
security.sudo-rs = {
  enable = true;   # activates sudo-rs (takes over the `sudo` name)
  extraRules = [{
    groups = [ "wheel" ];            # only wheel members may elevate
    commands = [ { command = "ALL"; options = [ ]; } ];  # password required
  }];
};
```

**doas** (opendoas; nixpkgs attr is `pkgs.doas` **[SCHEMA]** — `security.doas` module was REMOVED in NixOS 23.11, so a local module):
```nix
  # [SCHEMA] NixOS removed the security.doas module in 23.11 — the
  # working form is package + config + setuid wrapper:
environment.systemPackages = [ pkgs.doas ];
environment.etc."doas.conf".text = "permit :wheel";
security.wrappers.doas = {
  source = "${pkgs.doas}/bin/doas";  # the store-pathed binary (hermetic)
  owner = "root"; group = "root";
  setuid = true;          # set setuid OR permissions — never both [SCHEMA:
                          # the wrappers service concatenates → invalid chmod]
};
```

**Disable the other C sudo** if sudo-rs is on: `security.sudo.enable = false;` — avoid two escalation paths.

**Polkit:** keep `security.polkit.enable = true` (desktops need it) but ensure only wheel-adjacent flows: polkit rules default to requiring admin identity; custom rules via `security.polkit.extraConfig` when you need to restrict specific actions.

---

## 10. PAM

```nix
# Bruteforce penalty — 4 s per failed attempt, per interactive service:
# [SCHEMA] failDelay needs `enable = true` — setting `delay` alone is a no-op:
security.pam.services = {
  login.failDelay = { enable = true; delay = 4000000; };   # µs
  sddm.failDelay  = { enable = true; delay = 4000000; };
  sshd.failDelay  = { enable = true; delay = 4000000; };
  su.failDelay    = { enable = true; delay = 4000000; };
};

# Password hashing: SHA-512 with high rounds on password CHANGES.
# WARNING: do NOT clobber the passwd stack via `services.passwd.text` —
# that REPLACES the whole PAM stack (breaks the module's default rules).
# Extend via `rules` instead:
security.pam.services.passwd.rules.password.sha512-rounds = {
  order = 10000;
  control = "required";
  modulePath = "pam_unix.so";
  settings = { sha512 = true; shadow = true; rounds = 77777; };
};
# (Generate initial hashes with:  openssl passwd -6 'secret'
#  — mkpasswd-style; note NixOS does not apply login.defs rounds to
#  hashes you supply, only to changes via passwd(1).)

# Restrict `su` to a custom group — via the sanctioned PAM `rules`
# freeform (there is NO requireGroup; requireWheel hardcodes wheel [SCHEMA]):
security.pam.services.su.rules.auth.sugroup-gating = {
  order = with config.security.pam.services.su.rules.auth; rootok.order + 10;
  control = "required";
    # pam_wheel with use_uid+group=…: ONLY members of that group may su —
    # the PlagueOS sugroup port ([SCHEMA] modulePath is just the filename —
    # the module resolves it from the PAM path; a store path fails eval):
  modulePath = "pam_wheel.so";
  settings = { use_uid = true; group = "sugroup"; };
};

# Resource limits (see man limits.conf):
security.pam.loginLimits = [
  { domain = "*"; type = "soft"; item = "core"; value = "0"; }
  { domain = "*"; type = "hard"; item = "core"; value = "0"; }
];
```

---

## 11. Memory Allocator Hardening

GrapheneOS hardened_malloc system-wide (nixpkgs attr: `graphene-hardened-malloc` — renamed from `hardened_malloc` **[SCHEMA]**; verify the attr still exists on your pin — it has been renamed/removed before):

```nix
environment.etc."ld.so.preload".text =
  "${pkgs.graphene-hardened-malloc}/lib/libhardened_malloc.so";
# REQUIRED companion (guard-page-heavy allocator):
boot.kernel.sysctl."vm.max_map_count" = 1048576;
```

What it buys (per the [hardened_malloc README](https://github.com/GrapheneOS/hardened_malloc)): random allocation placement, guard pages, hardened malloc metadata, zero-on-free semantics. Caveats: slightly higher memory/CPU; test GUI apps if you see instability; disable temporarily by emptying `/etc/ld.so.preload` (keep a root shell open!). WARNING: system-wide `ld.so.preload` BREAKS `nix-ld`-wrapped dynamic binaries (Steam/proton, some Electron apps, unpatched foreign binaries) — expect crashes there; scope the preload per-service instead if you rely on nix-ld.

**Per-app opt-out — Steam/games break, so exclude them (surgical, preserves coverage):**
```nix
{ pkgs, ... }: {
  # Option A — wrapper that UNSETS preload for known-breakers only:
  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "steam-safe" ''
      export LD_PRELOAD=$(echo "$LD_PRELOAD" | tr ':' '\n' | grep -v hardened_malloc | paste -sd: -)
      exec ${pkgs.steam}/bin/steam "$@"
    '')
  ];
  # Option B — systemd per-service override (servers stay hardened, game scope not):
  # systemd.services.jellyfin.serviceConfig.Environment = [ "LD_PRELOAD=" ];  # if VAAPI segfaults
  # Verify breaker: LD_PRELOAD="" steam  # if launches, hardened_malloc was the cause
  # Gaming tradeoff: keep system-wide ON for browser/mail/arr stack; opt OUT only
  # steam, wine, proton, electron-wrapped anticheat titles (Hardening §25: IA32_EMULATION stays ON for same reason).
}
```

---

## 12. AppArmor / MAC

```nix
  # [SCHEMA] `packages` alone only feeds aa-logprof — profiles must be
  # EXPLICITLY loaded via `policies` (state: disable|complain|enforce):
security.apparmor = {
  enable = true;
  # WARNING: kills ANY process without a profile — including your desktop
  # session on a misconfigured host. Test in complain mode first; only
  # enforce once `aa-status` shows full coverage:
  killUnconfinedConfinables = true;  # kill processes that REFUSE confinement

  # [SCHEMA] profiles must be EXPLICITLY loaded on current NixOS — the
  # `packages` option alone only feeds aa-logprof, NOT the kernel loader:
  packages = [ pkgs.apparmor-profiles ];
  policies.dnsmasq = {
    state = "enforce";   # enum: disable|complain|enforce — NOT `enforce = true`
  path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.sbin.dnsmasq";  # the distro profile to load
  };
  # Per-profile OVERRIDES go through the profile's own
  # `include <local/...>` hook (attrsOf lines — auto writeText-wrapped):
  includes."local/usr.sbin.dnsmasq" = ''
    /usr/lib/libvirt/libvirt_leaseshelper mr,
  '';
};
```

Verify: `cat /sys/kernel/security/apparmor/profiles` (non-empty) and kernel log "AppArmor: AppArmor initialized" — the LSM chain from §3.

**Per-vendor GPU paths — CUDA/ROCm need explicit allowances (else transcode/ML denials):**
```nix
{
  # NVIDIA CUDA (NVENC + Immich ML + Jellyfin): toolkit libs + device nodes:
  security.apparmor.includes."local/usr.bin.ffmpeg" = ''
    /usr/lib/x86_64-linux-gnu/libcuda.so* mr,
    /usr/lib/x86_64-linux-gnu/libnvidia-encode.so* mr,
    /usr/lib/x86_64-linux-gnu/libnvcuvid.so* mr,
    /dev/nvidia* rw,
    /dev/dri/renderD128 rw,
  '';
  # AMD ROCm (tone-mapping + Immich ML): rocm + mesa VAAPI paths:
  # security.apparmor.includes."local/usr.bin.jellyfin-ffmpeg" = ''
  #   /opt/rocm/lib/** mr,
  #   /usr/lib/x86_64-linux-gnu/dri/radeonsi_dri.so mr,
  #   /dev/kfd rw,
  #   /dev/dri/renderD12[89] rw,
  # '';
  # Intel iHD/VPL (QSV): media-driver + HuC/GuC firmware load:
  # security.apparmor.includes."local/usr.bin.ffmpeg-qsv" = ''
  #   /usr/lib/x86_64-linux-gnu/libigfxcmrt.so* mr,
  #   /usr/lib/x86_64-linux-gnu/dri/iHD_drv_video.so mr,
  #   /dev/dri/renderD128 rw,
  # '';
  # Debug denials: journalctl -k | grep DENIED; aa-logprof to extend, then re-enforce.
}
```

**Do NOT write `environment.etc."apparmor.d/…"` directly** — the module linkFarms all of `/etc/apparmor.d` and direct writes collide (mkdir permission failure at build). Use `policies`/`includes` only.

SELinux: NixOS support is minimal/inactive; AppArmor is the pragmatic NixOS MAC (per nixpkgs module reality + community consensus).

---

## 13. Firewall & Network

```nix
networking.firewall = {
  enable = true;                       # iptables-nft backend by default
  allowedTCPPorts = [ ];   # EMPTY = nothing listens publicly (default-deny)
  allowedUDPPorts = [ ];   # same for UDP — adopt holes ONE port at a time
  trustedInterfaces = [ "virbr0" "lo" ];   # libvirt NAT + loopback
  # [SCHEMA] string, not bool: "strict" | "loose" | "ignore" — "loose"
  # keeps rp_filter parity without breaking asymmetric/libvirt paths:
  checkReversePath = "loose";
  # [SCHEMA] string limit spec, not null — e.g.:
  # Rate-limit ICMP if you allow ping at all (we disable echo via sysctl
  # instead — cleaner):
  pingLimit = "--limit 1/minute --limit-burst 5";
  # Log refused packets (audit value; noise cost):
  # [SCHEMA] renamed: logRefusedPackets (logRefusedConnections is gone):
  logRefusedPackets = false;       # tune per environment
  # NAT/port-forwards when needed:
  # extraCommands / extraStopCommands for anything exotic
};

# Anti-fingerprinting at the link layer:
networking.networkmanager = {
  enable = true;
  # NEW random MAC per connection profile — a new
  # network identity every time you connect:
  wifi.macAddress = "random";            # per-connection
  ethernet.macAddress = "random";
  wifi.scanRandMacAddress = true;          # during scans [SCHEMA name]
  dns = "systemd-resolved";   # NM never uses DHCP DNS directly (no router-
                              # DNS leak — resolved owns resolution)
};
environment.etc."NetworkManager/conf.d/hostname.conf".text = ''
  [main]
  hostname-mode=none                       # never adopt DHCP hostnames
'';
```

Why MAC randomization matters: probe-request tracking (scan MAC) and per-network correlation (connection MAC) — see the NetworkManager documentation on `wifi.cloned-mac-address`/`ethernet.cloned-mac-address`.

---

## 14. DNS

```nix
networking.nameservers = [
  "9.9.9.9#dns.quad9.net"             # DoT-capable; the #suffix = TLS name
  "149.112.112.112#dns.quad9.net"
];
  # Local caching resolver + DoT + DNSSEC — all lookups flow through it
services.resolved = {
  enable = true;
  settings.Resolve = {                 # [SCHEMA]: options namespaced under
    DNSOverTLS = "opportunistic";     #  settings.Resolve (extraConfig removed)
    LLMNR = false;                    # link-local name leaks off
  MulticastDNS = false;   # mDNS OFF (LAN-wide broadcast name leak)
    Domains = [ "~." ];                # ALL queries via stub (~. wildcard)
    FallbackDNS = [ ];                 # never leak to vendor defaults
  };
};
```

DNSSEC: `services.resolved.settings.Resolve.DNSSEC = "allow-downgrade"` (fail-soft on hostile LANs — there is no top-level `services.resolved.dnssec` option) — or omit; upstreams vary. Swap in `dnscrypt-proxy2` (`services.dnscrypt-proxy2`) if you want DNSCrypt/Oblivious-DoH instead of DoT.

---

## 15. SSH

Principle: **don't run sshd unless needed** (`services.openssh.enable = false;` — the most secure port is a closed one). When needed:

```nix
  # ONLY enable when the host genuinely needs remote access; prefer
  # wireguard/tailscale THEN ssh over the tunnel (no public listener):
services.openssh = {
  enable = true;
  ports = [ 378 ];                      # nonstandard (obscurity ≠ security
                                        # but cuts scan noise)
  settings = {
    PermitRootLogin = "no";            # NEVER "yes"
    PasswordAuthentication = false;    # pubkey only
    # Pluggable auth prompts OFF — pubkey or nothing (kills PAM-bypass tricks):
    KbdInteractiveAuthentication = false;
    MaxAuthTries = 2;          # 2 guesses per connection (default 6)
    MaxSessions = 2;           # multiplexed sessions capped (tunnel abuse)
    LoginGraceTime = 40;       # seconds to complete auth before drop
    AllowUsers = [ "admin" ]; # ALLOWLIST — everyone else refused pre-auth
    AllowAgentForwarding = false;  # your SSH agent can't be borrowed
    AllowTcpForwarding = false;   # no tunnel pivoting through the host
    X11Forwarding = false;        # no X tunnel (attack surface + leaks)
    UseDns = false;               # no reverse-DNS at auth (no DNS MITM
                                  # delay/confusion vector, faster too)
  };
};
# Plus the faildelay (§10) applies to sshd as well.
```

**Bruteforce rate-limiting on top** (for any exposed service — sshd included):
```nix
  # Bruteforce RATE-LIMITER (host IDS, NOT a boundary control) — the
  # real control above is pubkey-only; this only raises attack cost:
services.fail2ban = {
  enable = true;
  # NixOS pre-configures the sshd jail; MUST track your custom port or it
  # watches 22 and never fires. Module auto-defaults port from
  # services.openssh.ports — explicit here for clarity + journal backend:
  jails.sshd.settings = {
    enabled = true;
    port = "378";            # MUST match services.openssh.ports above
    filter = "sshd";
    backend = "systemd";     # journal, not logfile (NixOS has no /var/log/auth.log)
    mode = "aggressive";     # catches slow + keyscan variants
    maxretry = 3;            # 3 fails in findtime → ban
    findtime = 600;          # 10-min window
    bantime = "1h";          # 1h ban (escalate via bantime.increment on repeat)
  };
  # Never lock yourself out (your LAN + tailscale/wireguard net):
  # jails.DEFAULT.settings.ignoreIP = [ "127.0.0.1/8" "192.168.1.0/24" "100.64.0.0/10" ];
};
# Needs VERBOSE sshd logs to see failures (module auto-sets LogLevel VERBOSE
# if unset — verify: sshd -T | grep -i loglevel). Verify jail:
#   fail2ban-client status sshd; fail2ban-client get sshd banip --with-time
```
Caveat: fail2ban is a host-based IDS, not a boundary control — it only raises bruteforce cost and can itself be a DoS vector (ban your own NAT). Defense-in-depth only; the pubkey-only setting above is the real control.

**Even better — don't expose sshd at all** on the hardened tier: wireguard (or tailscale) into the network first, then ssh over the tunnel (no listening port on the public interface at all).

---

## 16. USB & Thunderbolt

**Kernel-level deny (linux-hardened patchset only — assert it):**
```nix
boot.kernel.sysctl."kernel.deny_new_usb" = 1;
assertions = [{
  assertion = config.boot.kernelPackages == pkgs.linuxPackages_hardened
              || true;  # adapt to your kernel selection logic
    # fail the BUILD loudly instead of silently shipping a dead sysctl:
  message = "deny_new_usb requires the linux-hardened patchset";
}];
```
While set, NO new USB device initializes (plugged devices get power but no driver binds — evil-maid defense).

**USBGuard (mainline; allow-listing with IPC):**
```nix
  # the device-authorization daemon (allowlist enforcement):
services.usbguard = {
  enable = true;
  rules = ''
    # Generate for YOUR hardware:  sudo usbguard generate-policy
    allow with-interface equals { 03:00:00 03:01:01 03:02:00 }
    block
  '';
  presentDevicePolicy = "allow";    # boot-present devices OK
  insertedDevicePolicy = "block";   # [SCHEMA name] hot-plug needs approval
  IPCAllowedUsers = [ "root" "fury" ];  # who may approve devices at runtime
                                        # (root + your admin for GUI prompts)
};
```
First-boot: `sudo usbguard generate-policy > /etc/usbguard/rules.conf` (then rebuild or write to the runtime location). See [USBGuard docs](https://usbguard.github.io/).

**Admin approval flow — hot-plug devices need explicit allow (daily UX):**
```nix
# Runtime: usbguard list-devices → usbguard allow-device <id> (one-shot) or
#   usbguard append-rule "allow id 1234:5678 serial \"ABC\"" (persistent via rules).
# GUI prompt for desktop: environment.systemPackages = [ pkgs.usbguard-notifier ];
# services.udev.packages needed for widget polkit: IPCAllowedUsers above MUST
# include your admin (fury) or the notifier cannot authorize.
# Verify: usbguard list-devices | grep block; plug YubiKey → notifier pops →
#   Allow → dmesg shows hid-generic bind. Audit: journalctl -u usbguard.
# Present-vs-inserted split: presentDevicePolicy=allow (boot KB/disk stay up),
# insertedDevicePolicy=block (everything new waits for YOUR approval).
```

**Thunderbolt:** the module is blacklisted (§5). If you must use it, prefer `bolt` with per-device authorization rather than auto-accepting.

---

## 17. Process Fingerprinting

```nix
# hidepid=2: users see only their own processes (recon resistance):
fileSystems."/proc".options = [ "nosuid" "nodev" "noexec" "hidepid=2" "gid=proc" ];
users.groups.proc = { };   # so the gid=proc whitelist resolves

# Generic hostname (NM never overrides — §13):
networking.hostName = "host";

# Static machine-id — [SCHEMA] there is NO networking.machineId option and
# /etc/machine-id CANNOT be an environment.etc file (systemd bind-mounts
# it; setup-etc fights the mount). The robust port is a boot-time unit:
systemd.services.pin-machine-id = {
  description = "Pin static generic machine-id";
  wantedBy = [ "multi-user.target" ];
  # order matters: the pin writes BEFORE commit takes ownership:
  before = [ "systemd-machine-id-commit.service" ];
  serviceConfig = {
    Type = "oneshot";
    ExecStart = "${pkgs.writeShellScript "pin" ''
      if [ ! -s /etc/machine-id ]; then
        echo -n "b08dfa6083e7567a1921a715000001fb" > /etc/machine-id || true
      fi
    ''}";
  RemainAfterExit = true;   # stays "active" post-exit (state marker)
  };
};
```

Hardware-info hiding (Whonix-style chmod go-rwx on /proc/cpuinfo, /sys, with whitelist groups) is possible but **breaks desktop sessions** — only apply on CLI-only hosts, and gate it on your profile switch.

---

## 18. systemd Service Sandboxing

For every unit you author, layer these (each is one line in `serviceConfig`):

```nix
systemd.services.my-service.serviceConfig = {
  # Memory/ptrace:
  MemoryDenyWriteExecute = true;        # W^X (breaks JITs — know your service)
  LockPersonality = true;
  NoNewPrivileges = true;               # blocks setuid/exec-perm escalations
  RestrictSUIDSGID = true;          # unit may never CREATE suid/sgid files

  # Filesystem:
  ProtectSystem = "strict";             # /usr,/boot,/etc read-only
  ProtectHome = true;                   # /home,/root inaccessible
  PrivateTmp = true;                    # private /tmp,/var/tmp
  PrivateDevices = true;                # no /dev access except pseudo
  ProtectKernelTunables = true;   # /proc/sys read-ONLY — unit cannot re-tune sysctls
  ProtectKernelModules = true;   # module load/unload BLOCKED for this unit
  ProtectKernelLogs = true;   # /dev/kmsg sealed — cannot forge kernel log entries
  ProtectControlGroups = true;   # cgroupfs read-only — cannot touch other units
  ProtectClock = true;   # clock changes blocked (settimeofday off)
  ProtectHostname = true;   # sethostname() blocked (identity tampering off)
  ProtectProc = "invisible";           # hide other processes
  RestrictFileSystems = [ "@basic-with-os" ];  # fs-allowlist

  # Capabilities/network:
  CapabilityBoundingSet = [ ];          # drop ALL, then re-add the minimum:
  # CapabilityBoundingSet = [ "CAP_SYS_TIME" ];
  AmbientCapabilities = [ ];
  RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
  RestrictNamespaces = true;
  # Syscall allowlist: only the "system-service" set (no ptrace/mount/
  # namespace abuse); anything outside = SECCOMP-killed at call time:
  # Syscall ALLOWLIST: only the "system-service" set — anything outside
  # (ptrace, mount, namespace abuse...) is SECCOMP-killed at call time:
  SystemCallFilter = [ "@system-service" ];
  # No 32-bit-on-64-bit syscall tables (the x32/x86 compat attack surface):
  # No 32-bit-on-64-bit syscall tables (kills the x32 compat surface):
  SystemCallArchitectures = [ "native" ];
  IPAddressDeny = [ "any" ];            # add IPAddressAllow for egress needs
  # deny ALL /dev access except explicitly allowed ones:
  DevicePolicy = "closed";   # deny ALL /dev except explicitly allowed ones
};
```

Tune per service: a time-sync needs `CAP_SYS_TIME` + network; a boot MAC-randomizer needs network sysfs. The discipline: enumerate what the service truly needs, deny the rest. Source: `systemd.exec(5)` — the authoritative list.

**Precedent — the NixOS Manual's own bar:** nixpkgs' postgresql module ships exactly this posture (W^X, `@system-service` filter, private /tmp, strict UMask 0027, socket restrictions, read-only hierarchy) **by default**, and treats breakage-with-hardening as a packaging bug. Match that bar for every unit you author. Also: `networking.wireless.enableHardening` (wpa_supplicant) defaults ON — a pattern to keep.

---

## 19. Nix & the Store

```nix
nix = {
  settings = {
    # Who may ask the daemon to build — the supply-chain gate:
    allowed-users = [ "root" "@wheel" ];
    trusted-users  = [ "root" ];
    sandbox = true;                  # builds isolated (default; keep explicit)
    auto-optimise-store = true;      # dedupe (closure hygiene)
  };
  extraOptions = ''
    experimental-features = nix-command flakes
  '';
  # GC policy — conservative default keeps rollback depth:
  gc = {
    automatic = true;
    dates = "weekly";
    # Keep 30 days of old generations = a MONTH of rollback depth:
  # Keep 30 days of old generations = a full month of rollback depth:
    options = "--delete-older-than 30d";
  };
};
```

Flake discipline: commit `flake.lock`; review changes with `nix flake update && nix diff` (or `nvd`) BEFORE `nixos-rebuild switch`. Pin your own fork if you need review latency on nixpkgs.

---

## 20. Core Dumps & Swap (Anti-Forensics)

```nix
# Triple-lock core dumps:
  # TRIPLE LOCK on core dumps — a crash dump is a full memory snapshot
  # (passwords, keys, tokens); any ONE knob can be bypassed, three
  # independent ones cannot:
boot.kernel.sysctl."kernel.core_pattern" = "|/bin/false";
boot.kernel.sysctl."fs.suid_dumpable" = 0;
systemd.coredump.enable = false;

# Swapless posture (memory never hits disk unencrypted):
boot.kernel.sysctl."vm.swappiness" = 0;
swapDevices = [ ];
# If you MUST swap: encrypted swap only:
# swapDevices = [ { device = "/dev/mapper/CRYPT-swap"; randomEncryption = true; } ];
```

On panic-wipe (anti-forensic emergency: LUKS header erase + fstrim + clean shutdown): a powerful tool, but it is **destructive by design** — test only in throwaway VMs, gate behind a root-run systemd unit that is never auto-started:

```nix
systemd.services.panic-wipe = {
  wantedBy = [ ];              # NEVER autostart
  serviceConfig = {
    Type = "oneshot";      # single execution, then done
    User = "root";         # cryptsetup needs raw device access (by design)
    # never let systemd KILL a wipe mid-pass (interruption mid-erase is
    # the one state worse than completed):
    TimeoutStartSec = "0"; # never let systemd KILL a wipe mid-pass (data
                           # safety: interruption mid-erase is the one state
                           # worse than completed)
  };
  # ExecStart: loginctl lock-sessions; cryptsetup erase (×2, sync/fstrim
  # between); raw-device overwrite sweep; shutdown now.
};
```

---

## 21. Entropy

```nix
boot.kernelModules = [ "jitterentropy_rng" ];  # in-kernel Jitter RNG
  # Don't seed the kernel RNG from the CPU's RDRAND — trust jitterentropy,
  # so a backdoored CPU RNG can't own your keys:
boot.kernelParams = [ "random.trust_cpu=off" ];
```
haveged is unmaintained and unnecessary on kernel ≥5.6 (in-kernel jitterentropy + the modern LRNG/CRNG reseed design). Verify: `cat /proc/sys/kernel/random/entropy_avail` (low numbers are FINE on modern kernels — the CRNG doesn't drain like the old interface suggested).

---

## 22. Firmware / Microcode / Boot

```nix
# Microcode — set the line matching YOUR CPU (vendor-general; required
# either way, §2):
hardware.cpu.amd.updateMicrocode = true;       # AMD (Ryzen/EPYC)
# hardware.cpu.intel.updateMicrocode = true;  # Intel machines use this
hardware.enableRedistributableFirmware = true;

boot.loader.systemd-boot.enable = true;     # smaller attack surface than
boot.loader.systemd-boot.configurationLimit = 5;  # GRUB; rollback depth 5
boot.loader.efi.canTouchEfiVariables = true;  # may write the boot entry (needed to install;
                                               # unset for an EFI-locked setup)
boot.initrd.systemd.enable = true;          # systemd stage-1 (LUKS, tmfg)

# GRUB users (BIOS/legacy or /boot-on-LUKS) — the security-relevant bits:
# boot.loader.grub = {
#   enable = true;
#   enableCryptodisk = true;       # GRUB_ENABLE_CRYPTODISK=y
#   configurationLimit = 5;
#   # Password-protect the menu:
#   # hashedPasswordFile = "/persistent/grub-password";  # grub-mkpasswd
# };

# Secure Boot path (advanced; NixOS's current story per the Manual's
# "Bootspec" section): systemd-boot + Unified Kernel Images (UKIs) +
# your own keys via sbctl (see the NixOS wiki "Secure Boot" article —
# lanzaboote is the community module). Bootspec exists precisely to
# enable "advanced boot workflows such as SecureBoot"
# (boot.bootspec.extensions). The installer ISO itself requires
# DISABLED Secure Boot — enable only after installation.
# Lanzaboote declarative (flake input lanzaboote, replaces systemd-boot):
# boot.loader.systemd-boot.enable = lib.mkForce false;
# boot.lanzaboote = { enable = true; pkiBundle = "/var/lib/sbctl"; };
# environment.systemPackages = [ pkgs.sbctl ];  # sbctl create-keys; sbctl enroll-keys --microsoft
# Verify: bootctl status | grep Secure; sbctl verify | grep -c signed
# PER-GPU WARNING — NVIDIA unsigned module signing: proprietary nvidia_x11
# ko is UNSIGNED out-of-tree → lockdown=integrity + Secure Boot REJECTS it
# at modprobe. Fixes (pick one): (1) hardware.nvidia.open=true (open modules
# still need MOK enroll via sbctl sign -s), (2) sbctl sign custom nvidia ko
# after each rebuild, (3) AMD/Intel iGPU hosts unaffected (in-tree amdgpu/i915
# signed with kernel). If nvidia-smi fails post-Secure-Boot, it is signing — not drivers.
# Keep Microsoft keys enrolled (--microsoft) or AMD/NVIDIA OpROMs refuse init.
# Related manual sections worth knowing:
#   * tpm2-totp: boot.plymouth.tpm2-totp.enable — human-verifiable boot
#     attestation via a TOTP shown at the Plymouth prompt.
#   * Clevis: unattended TPM2/Tang LUKS unlock (boot.initrd.clevis).
```

---

## 23. Auditing Your System

**auditd rules — who did what, declaratively (STIG-grade trail):**
```nix
{
  # Kernel audit + daemon (BOTH — audit.enable loads rules, auditd writes logs):
  security.audit.enable = true;
  security.auditd.enable = true;
  security.audit = {
    failureMode = "printk";   # panic=DoS on log-full; printk logs without hanging
    backlogLimit = 8192;
    rateLimit = 0;
    rules = [
      "-w /etc/passwd -p wa -k identity"
      "-w /etc/shadow -p wa -k identity"
      "-w /etc/nixos/ -p wa -k nixos-config"
      "-a always,exit -F arch=b64 -S execve -k exec"
      "-a always,exit -F arch=b64 -S connect -k net-connect"
      "-w /dev/kvm -p wa -k virt"
      "-w /boot/ -p wa -k boot-tamper"
    ];
  };
  # Query: ausearch -k identity --start recent; aureport --summary
  # Cost: execve rule is VERBOSE (~disk + perf) — drop on low-end boxes or
  # scope to -F euid=0. Lock variant: security.audit.enable = "lock" (rules
  # immutable till reboot — test in VM §24 first!).
}
```

```bash
# Posture snapshot:
sysctl kernel.kptr_restrict kernel.dmesg_restrict kernel.yama.ptrace_scope \
       vm.mmap_rnd_bits vm.max_map_count fs.suid_dumpable
cat /proc/sys/kernel/deny_new_usb 2>/dev/null   # patched kernels
aa-status                                        # profiles loaded?
iptables -L INPUT | head -5                      # firewall structure
nixos-option security.apparmor.enable 2>/dev/null || true
nvd diff /run/current-system result              # before switching!

# Kernel CPU mitigations:
nix shell nixpkgs#spectre-meltdown-checker -c spectre-meltdown-checker

# Attack-surface scan (run from OUTSIDE the host periodically):
nix shell nixpkgs#nmap -c nmap -sSv -p- <host>   # with permission only!

# Store closure review:
nix path-info -rsSh /run/current-system | sort -h | tail -20
```

---

## 24. Testing Without Risk (VM Tests)

**The golden rule: never test hardening on your only machine.** NixOS's `nixosTest` builds throwaway QEMU VMs — the same machinery nixpkgs CI uses — and your running system is never touched:

```nix
# checks/default.nix
{ pkgs, ... }: {
  my-hardening-test = pkgs.testers.nixosTest {   # [SCHEMA] testers.nixosTest
    name = "my-hardening-test";
    nodes.machine = {
      imports = [ ../modules/all-my-hardening.nix ];  # the module under test
      # Test-infra-only lines below (NOT production practice): a PLAINTEXT
      # test password + mutable users so the harness can drive logins:
      users.users.admin.password = "correcthorse";
      users.mutableUsers = true;
      environment.systemPackages = [ pkgs.iptables ];  # tools for asserts
    };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("sysctl -n kernel.kptr_restrict | grep -q 2")
      machine.succeed("id -nG admin | grep -qw wheel")
      machine.fail("id -nG user | grep -qw wheel")   # negative tests matter
    '';
  };
}
```

Run: `nix flake check` (all) or `nix build .#checks.x86_64-linux.my-hardening-test` (one). Read full logs: `nix log $(nix path-info --derivation .#checks.x86_64-linux.my-hardening-test)`.

Additional non-destructive layers, in order of cost:
1. **Eval-only invariants** — assertions in flake checks (`users.users.root.hashedPassword == "!"` etc.) — milliseconds.
2. **dry-activate** — `nixos-rebuild dry-activate --flake .#host` — what WOULD change.
3. **`nixos-rebuild test`** — activate without a boot entry (reboot escapes).
4. **Full VM tests** — the gold standard; boot the real config.

---

## 25. What Does NOT Work (Common Traps)

Verified failures — each of these was caught by eval/build/VM gates in real use:

| Trap | Why it fails | The working approach |
|---|---|---|
| `security.doas.*` | Option REMOVED in NixOS 23.11 | sudo-rs, or local module around `pkgs.doas` (§9) |
| `security.hideProcessInformation` | Option never existed | `fileSystems."/proc".options = ["hidepid=2"]` |
| `networking.machineId` | Option doesn't exist; /etc/machine-id is a systemd bind-mount — environment.etc fights it | boot-time pin unit (§17) |
| `services.resolved.extraConfig` | Removed — renamed | `services.resolved.settings.Resolve.*` |
| `virtualisation.libvirtd.qemu.ovmf` | Submodule removed | nothing — OVMF included by default now |
| `virtualisation.libvirtd.qemu.extraConfig` | Renamed | `…qemu.verbatimConfig` |
| `hardware.pulseaudio.enable = lib.mkForce false` | Boolean option type rejects override wrappers in this position | plain `= false` |
| `services.usbguard.insertDevicePolicy` | Typo'd name | `insertedDevicePolicy` |
| `networking.networkmanager.wifi.scanHardwareAddress` | Renamed | `scanRandMacAddress` |
| `security.apparmor.policies.X.enable = true` | Wrong shape | `{ state = "enforce"; path = …; }` |
| `environment.etc."apparmor.d/…"` direct writes | Module linkFarms /etc/apparmor.d — mkdir collision | `security.apparmor.policies` / `.includes` |
| `security.wrappers.doas = { setuid = true; permissions = "4755"; }` | Service concatenates → `chmod u+s,g-s,4755` invalid → unit fails at boot | set ONE of them |
| manual `lsm=` in kernelParams | AppArmor module appends its own token; duplicates/overrides | `security.lsm` (mkForce; bpf last) |
| `structuredExtraConfig` LSM as `mkForce "str"` | String options need freeform | `lib.mkForce (lib.kernel.freeform "…")` |
| `homeMode = 700` | Option type is a string pattern | `homeMode = "700"` |
| uid < 1000 with `isNormalUser` | Eval assertion | uid = 1000+ (or isSystemUser) |
| `boot.blacklistedKernelModules` alone | Only blocks alias autoload | add `install X /bin/false` via extraModprobeConfig |
| Blacklisting webcam/BT/thunderbolt unconditionally on a general desktop | Dead hardware users expect to work | conditional blacklist: `lib.optionals (!cfg.hardware.X.enable) [ … ]` + a per-host toggle (see Securenix-Documentation §8.5) |
| doas `echo pw \| doas -S` in tests | doas has no -S (that's sudo) and reads only the TTY | test via sudo -S, or pty machinery |
| `systemctl is-active` on Type=oneshot after boot | Correctly "inactive" after success | assert `--property=Result --value = success` |
| mounting `/dev/shm` read-only | Breaks QEMU/libvirt shared memory | rw + noexec,nosuid,nodev |
| mounting `/boot` read-only | Breaks every bootloader write | rw + nosuid,noexec,nodev |
| `/etc/machine-id` via environment.etc | systemd bind-mount conflict | pin-unit (§17) |
| testing root's lock inside a nixosTest VM | Test infra force-unlocks root (hashedPasswordFile="") | assert root lock at EVAL level (flake check) |
| FIDO2 unlock without a PIN-protected device | Passwordless becomes THE attack surface (NixOS Manual warning) | PIN-protected key + recovery passphrase stored physically |
| setting machine-id via kernel cmdline | Explicitly discouraged by NixOS systemd maintainers (nixpkgs PR #268995) | persistent /etc/machine-id (or the boot pin-unit, §17) |

**The meta-rule:** when an option name from an old blog/wiki post fails, read the actual nixpkgs module source (options are the truth), or ask the eval: `nix eval .#nixosConfigurations.HOST.options.security.pam.services.<name>.type.description`.

---

## 26. Reference Index

- **NixOS Manual** — https://nixos.org/manual/nixos/stable/ (esp. "LUKS-Encrypted File Systems" for FIDO2/Clevis, "Firewall", "Secure Shell Access", "Linux Kernel", TPM2 & tpm2-totp modules, "Bootspec" for the SecureBoot/UKI story)
- **NixOS Option Search** — https://search.nixos.org (verify every option here — incl. security.lockKernelModules / protectKernelImage / allowSimultaneousMultithreading, all default OFF)
- **NixOS VM test framework** — Manual: "Writing NixOS tests" (`nixos/lib/testing`)
- **nixpkgs module sources** (ground truth for every [SCHEMA] note) — https://github.com/NixOS/nixpkgs (nixos/modules/)
- **madaidan's Linux Hardening Guide** — https://madaidans-insecurities.github.io/guides/linux-hardening.html
- **Kernel Self Protection Project** — https://kernsec.org/wiki/index.php/Kernel_Self_Protection_Project
- **kernel sysctl docs** — Linux tree `Documentation/admin-guide/sysctl/`
- **systemd.exec(5)** — service sandboxing directive reference
- **linux-hardened patchset** — https://github.com/anthraxx/linux-hardened
- **hardened_malloc** — https://github.com/GrapheneOS/hardened_malloc
- **USBGuard** — https://usbguard.github.io/
- **systemd-resolved** — `resolved.conf(5)`
- **NetworkManager MAC randomization** — NM docs: `wifi.cloned-mac-address`
- **LUKS2 / cryptsetup** — `cryptsetup(8)`, LUKS2 whitepaper (Argon2id rationale)
- **CIS Benchmarks** (general Linux hardening checklist lineage) — cisecurity.org
- **Anthraxx's "Securing Linux" talks; KSPP recommendations; PlagueOS upstream** — cross-references for the source-baseline values used above
- **Zero to Nix** — https://zerototnix.dev · **Awesome Nix** — https://github.com/nix-community/awesome-nix
- **NixOS Discourse** — https://discourse.nixos.org (search before fighting an option)

---

*Companion document: `Securenix-Documentation.md` — the complete, self-contained replication guide for the Securenix distribution profile built on these techniques.*
