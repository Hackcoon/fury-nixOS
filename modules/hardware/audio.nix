# ============================================================================
# audio.nix — Audio (PipeWire) + Bluetooth (BlueZ): one headset feature unit.
#
# PipeWire replaces PulseAudio entirely (ALSA + Pulse + JACK compat kept so
# every app finds a server to talk to). BlueZ handles headsets, with SBC-XQ /
# mSBC wideband enabled through wireplumber for better wireless sound + mic.
# OPTIONAL for minimal: drop = no sound, but boots leaner.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── PipeWire replaces PulseAudio ──
  # Legacy PulseAudio off, rtkit for realtime scheduling, full compat stack
  # (ALSA incl. 32-bit for games, Pulse, JACK) under wireplumber.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true; # realtime scheduling for glitch-free audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;       # JACK application support
    wireplumber.enable = true;
  };
  # ----------------------------------------------------------------------

  # ── Bluetooth (BlueZ): radio on at boot, headset features ──
  # Experimental = headset battery reporting. Codec tweaks go through
  # wireplumber's BlueZ monitor below, not here.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true; # radio on after boot
    settings = {
      General = {
        Experimental = true;   # e.g. reading headset battery levels
      };
    };
  };
  # ----------------------------------------------------------------------

  # ── Bluetooth codec upgrades (SBC-XQ + mSBC wideband) ──
  # SBC-XQ = higher-quality SBC; mSBC = wideband mic audio for calls.
  # Hardware volume left OFF: letting the headset own volume sync breaks
  # level reporting on some headphones — flip it on for headsets that handle it.
  services.pipewire.wireplumber.extraConfig."bluetooth-config" = {
    "monitor.bluez.properties" = {
      "bluez5.enable-sbc-xq" = true;
      "bluez5.enable-msbc" = true;
      # "bluez5.enable-hw-volume" = true; # OFF: volume-sync issues on some headsets
    };
  };
  # ----------------------------------------------------------------------
}
