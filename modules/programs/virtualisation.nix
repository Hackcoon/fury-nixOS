# ============================================================================
# virtualisation.nix — libvirtd/KVM + virt-manager + Spice USB + Podman.
#
# HEAVY: QEMU/libvirt closure. Drop for minimal. fury is in libvirtd via
# users.nix (virt-manager without "access denied"). Hermes container mode
# (ai/ai-services.nix) needs the Podman half below.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── KVM/QEMU hypervisor + GUI + USB passthrough ──
  # qemu_kvm tuned build, TPM emulation for Windows 11 guests (swtpm),
  # virt-manager GUI, Spice for USB redirection into VMs.
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };
  };
  programs.virt-manager.enable = true;
  virtualisation.spiceUSBRedirection.enable = true; # USB passthrough into VMs
  # ----------------------------------------------------------------------

  # ── Podman: daemonless containers, docker-compatible ──
  # Nothing runs until a container starts (zero idle CPU/memory).
  # dockerCompat = `docker` CLI shim -> podman; dockerSocket = on-demand API
  # socket so docker-API tools (winboat) work without a permanent daemon.
  # Want the REAL Docker daemon instead? Drop this block and enable
  # virtualisation.docker.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
  };
  # ----------------------------------------------------------------------
}
