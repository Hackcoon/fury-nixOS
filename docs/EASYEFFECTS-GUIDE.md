# EasyEffects Guide (NixOS + PipeWire)

Version covered: EasyEffects 8.2.4, PipeWire 1.6.6.
Box: NixOS 26.05, GTX 1660 SUPER, Ryzen 5 3600.

## 1. What it is and how it slots in

EasyEffects is a system-wide DSP rack for PipeWire. It inserts virtual
devices into your audio graph:

- **Output chain:** apps -> `EasyEffects Sink` -> your effects -> real speakers/headphones
- **Input chain:** real mic -> your effects -> `EasyEffects Source` -> apps

Effects only apply while EasyEffects is **running** and the app is routed
through the virtual device. If sound ever seems "unprocessed," 9 times out
of 10 the app is pointed at the raw hardware instead of the EasyEffects
device. Verify routing in `pavucontrol` (Playback/Recording tabs) or
`qpwgraph` (visual wire view).

It's already installed system-wide here (`easyeffects` in PATH). No NixOS
service needed — it's a normal user app.

## 2. First-run setup (do once)

1. Launch EasyEffects. Two tabs at top: **Output** (what you hear) and
   **Input** (your mic). Start on Input.
2. Preferences (hamburger menu):
   - **Start minimized to tray** + **launch service at login**: ON. No
     autostart = no effects after reboot. (It also lives in
     `~/.config/autostart/` once enabled — standard XDG, works in every
     session: Mango, dwm, Plasma, Hyprland.)
   - **Process all outputs/inputs**: OFF unless you want one chain forced
     on everything. Per-device/per-app routing below is more precise.
3. Bottom bar: **input device dropdown** — pick your real mic (not
   "Default," which can follow plugs/unplugs unpredictably).
4. Add plugins with the **+** button. **Order matters** — signal flows top
   to bottom. Reorder with the handle on each plugin card.
5. Each plugin card has: power toggle (bypass), **input/output gain**,
   wet/dry where relevant, and a menu (move, presets, remove).
6. Global **Bypass** switch (header) kills the whole chain for A/B
   comparison without removing anything.

## 3. Discord mic recipe (copy this)

Chain order on the **Input** tab, mic selected:

1. **Gate** — mutes the mic below a volume floor (keyboard clacks, fan hum
   between words). Start: threshold around -45 dB, attack 5 ms, release
   150 ms, then talk/type and nudge threshold until typing doesn't open it
   but quiet speech does.
2. **Noise Reduction** — model **RNNoise** (best general voice cleanup;
   Speex = cheaper/lighter, DeepFilterNet = newest and excellent but
   heavier CPU). Amount ~ -15 to -25 dB. If your voice goes robotic or
   underwater, back the amount off before touching anything else.
3. **Compressor** — evens loud/quiet talking. Start: threshold -18 dB,
   ratio 3:1, attack 10 ms, release 100 ms, makeup gain until your normal
   voice peaks near -6 dB on the meter. Knee 6 dB keeps it natural.
4. **Equalizer** — gentle presence: +2 to +4 dB wide bell around 3–5 kHz
   for clarity, high-pass (low cut) at 80–100 Hz to dump rumble/desk
   thumps. Cut, don't boost, anything harsh.
5. **Limiter** — ceiling at -1 dB so laughs/shouts never clip or blast
   the call.

Then in Vesktop/Discord voice settings set **input = EasyEffects Source**
(or "easyeffects_source"). Discord's own Krisp/noise removal: turn it OFF
— stacking two denoisers sounds worse than either alone. Same for any
"automatic gain" in the app; let the Compressor own levels.

Save it: hamburger -> **Presets -> Save** (e.g. `discord-mic`). Presets
live in `~/.config/easyeffects/` — back that dir up with your dotfiles.

## 4. Profiles that switch themselves

Static chains are fine; autoloading is better:

- **Presets -> Autoload**: bind a preset to an **output/input device**
  (e.g. headphone preset when headphones plug in) or to a **running app**
  (e.g. bass-heavy music preset for Spotify, flat for YouTube).
- Typical split: `calls` (mic chain above + flat output), `music`
  (output EQ + Bass Enhancer), `night` (output Limiter lower + Loudness).
- Test autoload by launching the app and watching the preset name flip.

## 5. Every plugin, what it does

### Input-chain essentials (mic)

- **Gate** — hard mute below threshold. Controls: threshold, attack
  (how fast it opens), release/hold (how long it stays open after sound
  stops), range (how deep the cut is; -60 dB = full mute). Too fast a
  release = choppy word endings.
- **Noise Reduction** — removes stationary background noise. Models:
  RNNoise (neural, best all-rounder), Speex (classic, cheap, good for
  fans/hum), DeepFilterNet (neural, great on complex noise, most CPU).
  One model at a time. If voices artifact, lower the amount or switch
  models before adding more plugins.
- **Compressor** — squeezes dynamic range: loud parts quieter, then
  makeup gain lifts everything. Threshold (where it starts), ratio
  (how hard: 2:1 gentle, 4:1+ firm), attack/release, knee (soft =
  transparent), makeup gain, dry/wet mix. Watch the gain-reduction meter:
  3–6 dB of reduction while talking is the sweet spot for voice.
- **Limiter** — brick wall: nothing passes the ceiling. Ceiling (-1 dB),
  release. Last in chain, always.
- **Deesser** — tames harsh S/T sounds. Frequency (~5–8 kHz), threshold.
  Only add if your mic is sibilant.
- **Equalizer** — parametric EQ (up to 30 bands). High-pass rumble out,
  presence in, narrow cuts for resonances/hums (mains hum: notch 50 Hz).
- **Autogain** — rides levels automatically (alternative to manual
  compressor makeup). Target level + silence behavior. Pick autogain OR
  careful makeup, not both fighting.
- **Echo Canceller** — kills speaker bleed for open speakers on calls.
  Needs the far-end reference; headphones make it unnecessary. If callers
  hear themselves, this (or wearing headphones) is the fix.
- **Expander** — gate's polite sibling: reduces (not mutes) quiet parts.
  Use instead of Gate if full muting clips your breath/ambience weirdly.
- **Multiband Gate / Multiband Compressor** — gate/compress per frequency
  band. For when one band misbehaves (e.g. bass rumble opens the gate):
  tame that band only.

### Output-chain essentials (speakers/headphones)

- **Equalizer** — same parametric EQ. Headphone correction curves and
  room harshness live here.
- **Bass Enhancer** — harmonic bass lift for small speakers/headphones
  that can't move air. Amount + floor. Easy to overdo; creep up slowly.
- **Compressor / Multiband Compressor** — glue for inconsistent content
  (movies with whisper-talk and explosion-fights). Gentle ratios.
- **Limiter / Maximizer** — night mode: cap peaks so loud scenes don't
  wake anyone. Maximizer = limiter + loudness push; watch for pumping.
- **Loudness** — Fletcher-Munson compensation: keeps bass/treble balanced
  at LOW volumes. A night-mode must-have; disable at reference volume.
- **Stereo Tools** — balance, width, mono-mix, phase. Fixes one-dead-side
  or over-wide headphones; mono check for mixes.
- **Crossfeed** — blends L/R slightly like real speakers in a room.
  Reduces headphone fatigue; subtle amounts only.
- **Convolver** — loads impulse responses (room correction, headphone EQ
  profiles e.g. AutoEq WAVs). Most powerful, most fiddly. Start with a
  known-good HRIR/AutoEq file, wet 100%, check levels after.
- **Crystalizer / Exciter** — harmonic "air"/detail enhancers. Small doses;
  they add what isn't there and harshness rides along.
- **Reverberation** — room reverb on output. Almost never wanted for
  monitoring; fun for games at 5–10% wet, max.
- **Delay** — lip-sync offset (ms) when video lags audio, or slapback FX.
- **Filter** — low/high/band-pass and notch. Utility crossover and cleanup.
- **Pitch** — novelty/formant shifting. Not for calls unless comedy.
- **Level Meter / Spectrum Analyzer** — measurement only, no sound change.
  Keep one visible while tuning: meter for gain staging, spectrum for
  finding hums/resonances to EQ out.

## 6. Routing on NixOS (PipeWire + WirePlumber)

- Default source/sink: `pavucontrol` -> Configuration/Input/Output, or
  right-click meters. Set system default mic to the RAW device and let
  only call apps use the EasyEffects source — or flip it global, your call.
- Per-app: `pavucontrol` Recording tab while the call is live moves that
  app's input between raw mic and EasyEffects source independently.
- Visual: `qpwgraph` shows every wire; drag to rewire live. Great for
  confirming Discord is actually on the processed chain.
- Vesktop specifically: Settings -> Voice & Video -> input device =
  EasyEffects Source. (Output = your headphones directly; no need to
  process what you hear unless you want the music chain.)

## 7. Troubleshooting

- **No effect at all**: app routed to raw hardware (check pavucontrol
  Recording/Playback), plugin bypassed (power icon), global Bypass on, or
  EasyEffects not running (no autostart).
- **Crackle/stutter/robot voice**: DSP overload or buffer underrun.
  1) Raise PipeWire quantum: `pw-metadata`/`pw-top` to inspect; the usual
  fix is a bigger buffer (e.g. `PIPEWIRE_LATENCY=256/48000` on the app,
  or system quantum in WirePlumber config). 2) Drop DeepFilterNet for
  RNNoise. 3) Close the heavy Electron tabs while tuning.
- **Callers hear themselves**: open speakers + mic = echo. Headphones
  first; Echo Canceller second.
- **Mic too quiet/loud after chain**: gain staging — check each plugin's
  in/out meters, aim peaks around -12 to -6 dB through the chain, Limiter
  ceiling -1 dB at the end.
- ** undistorted locally, distorted for callers**: Discord applies its own
  processing + Opus; back off Compressor makeup and Limiter drive, and
  keep Discord's Krisp/AGC OFF.
- **Autostart didn't apply**: confirm the tray icon exists after login;
  if not, check `~/.config/autostart/easyeffects-service.desktop` exists
  and is executable/trusted.
- **One app must bypass everything** (e.g. a DAW, or a game with its own
  DSP): route that app to raw hardware in pavucontrol/qpwgraph and leave
  the chain for everything else.
- **Preset vanished**: presets are plain JSON in
  `~/.config/easyeffects/` (+ `input/`/`output/` subdirs). Restore from
  backup; never hand-edit while the app runs (it overwrites on exit).

## 8. NixOS notes

- Package: `easyeffects` (this box: 8.2.4). Updates ride the normal
  `nixos-rebuild switch`; major versions occasionally rename plugin
  settings — export presets before big jumps.
- No service or special group needed; user-session PipeWire +
  WirePlumber (both already running here) is the whole backend.
- Autostart is XDG-based, so it works identically in Mango, dwm, Plasma,
  Hyprland. Session-specific gotcha: none — the virtual devices follow
  PipeWire, not the compositor.
- RNNoise/DeepFilterNet models download on first use into
  `~/.local/share/easyeffects/` — needs network once; thereafter offline.

## 9. Quick reference

| Goal | Chain |
|---|---|
| Discord calls | Gate -> RNNoise -> Compressor -> EQ -> Limiter |
| Streaming mic | Gate -> RNNoise -> Deesser -> Compressor -> EQ -> Limiter |
| Music headphones | EQ -> Bass Enhancer -> (Loudness at night) |
| Movies, wild dynamics | EQ -> Multiband Compressor (gentle) -> Limiter |
| Laptop speakers | EQ (high-pass!) -> Limiter |
| Check your work | Level Meter + Spectrum at chain end, global Bypass to A/B |
