# Heroes of the Storm disconnects on Lutris — diagnosis + fix (2026-10-10)

## Symptom
- Mid-match HotS shows "disconnected", Discord/browser stay up.
- Random, ~once per session. Only a full quit + relaunch rejoins.
- Wired (`enp5s0`, 1Gbps/full), NixOS 26.05, Lutris 0.5.22, Battle.net via `umu-run`.

## Root cause (evidence from live capture)
- Game TCP `192.168.1.135:43960 → 137.221.106.15:1119` stayed ESTABLISHED with
  empty queues, but the client held **zero UDP sockets to the game server**
  (`ss -una`). HotS gameplay runs over UDP — once that association dies the
  client cannot rejoin the same match; relaunch builds a fresh UDP session.
- Past `Link is Down` events were all suspend/resume (08:19 suspend →
  19:12 resume), not random flaps. NIC counters clean (0 errors).
- Baseline clean at diagnosis time: 0% loss to router (0.28ms avg) and to
  Blizzard CDN `137.221.64.3` (8ms avg); game server `137.221.106.15` pings
  60ms (farther region, more jitter-sensitive).
- Local conntrack was `udp_timeout=30, udp_timeout_stream=120` — expires idle
  mappings during draft/loading. HotS does lockstep and never re-punches NAT.
- Lutris floated latest Proton (`GE-Proton11-7`); old lockstep games regress
  first on new Wine networking. CPU governors stuck on `schedutil` because
  GameMode `cpugovctl set performance` fails (`pkexec ... Not authorized`).

## Fix 1 — pin Proton to UMU-Proton-10.0-4 (via Lutris GUI)
In Lutris: Battle.net → Configure → Runner options → Wine version →
`UMU-Proton-10.0-4` → Save. This writes `wine.version` into
`/home/fury/.local/share/lutris/games/battlenet-1791200231.yml`
(note: Lutris renamed this file on save; it was
`battlenet-standard-1791200231.yml` before):

```yaml
wine:
  version: UMU-Proton-10.0-4
```

Takes effect next Battle.net launch (restart Lutris game). Do NOT also set a
manual `PROTONPATH` env override — the GUI pin and the env hack fight over
which Proton umu uses; the GUI pin alone is the single source of truth.
Revert: set Wine version back to `GE-Proton (Latest) (default)`.
If HotS still drops on 10.0-4, try `GE-Proton9` next, then re-enable floating
to retest new releases.

### Fallback: manual YAML pin (if the GUI ever loses the selection)
Only use ONE method at a time — GUI pin and this env override fight over
which Proton umu uses. If the dropdown resets itself after a Lutris update,
add this to the same yml under top-level `system.env` instead:

```yaml
system:
  env:
    ...
    PROTONPATH: /home/fury/.local/share/Steam/compatibilitytools.d/UMU-Proton-10.0-4
```

umu honors `PROTONPATH` and it wins over the dropdown. Verify with:
`grep -E "version:|PROTONPATH" ~/.local/share/lutris/games/battlenet-*.yml`
— you should see exactly one of `wine.version` or `PROTONPATH`, never both.
Revert: delete the `PROTONPATH` line.

## Fix 2 — Battle.net quiet during matches
File: `~/Games/battlenet/drive_c/users/steamuser/AppData/Roaming/Battle.net/Battle.net.config`
- `Client.GameSearch.BackgroundSearch`: `"true"` → `"false"` (stops Agent
  search churn mid-match).
- `Client.GameLaunchWindowBehavior` already `"2"` (client gets out of the way
  on game launch) — leave it.
- NOTE: Lutris GUI saves rewrite the yml installer template (`write_json`
  block) from defaults, so don't bother changing `BackgroundSearch` there —
  the live `Battle.net.config` above is the effective setting.

NOTE: Agent rewrites this file on exit — after relaunching, verify
`BackgroundSearch` is still `"false"`; if Battle.net reverted it, close
Battle.net fully before editing. Also set in the Battle.net UI:
Settings → Downloads → **Pause updates when I'm in a game**.

## Fix 3 — Blocky allowlist for Battle.net telemetry
File: `modules/services/blocky.nix` (`whiteLists.ads`; correct for the
pinned Blocky 0.29.0 — its deprecation WARN/ERROR noise is cosmetic, exit 0.
Do NOT rename to `allowLists`; the 0.29 binary hard-fails on it.) Core login/game domains were never blocked;
only these spammed every few seconds in-game and forced client retries:

```
"telemetry-in.battle.net"
"rum.battle.net"
```

Requires rebuild: `sudo nixos-rebuild switch --flake /etc/nixos`.
Revert: delete the lines, rebuild.

## Fix 4 — longer local UDP conntrack timeouts
File: `modules/core/network.nix`:

```nix
boot.kernel.sysctl = {
  "net.netfilter.nf_conntrack_udp_timeout" = 60;
  "net.netfilter.nf_conntrack_udp_timeout_stream" = 180;
};
```

Requires rebuild (same command). This only covers the PC side — the router
`192.168.1.1` has its own UDP timeout. If drops persist: raise UDP timeout on
the router or add a static forward for UDP 1119-1120, 3724, 4000, 6113-6114.
Revert: delete the block, rebuild.

## Update 2026-10-12 — drop recurred, findings
- Drop recurred on a fresh session running **UMU-Proton-10.0-4** (pin verified
  live via ps). Proton version is ruled out as the cause/fix — the pin stays
  as hygiene, but it is not the answer.
- Live signature identical: TCP `:1119` ESTAB with empty queues, zero UDP to
  the game server, 0% loss to router and to `137.221.106.15`, clean journal.
  Silent UDP-session death, most likely during a quiet phase (draft/loading
  sends almost no UDP, so NAT mappings expire and the match starts dead).
- Fix 4 was NOT live despite being in the booted generation: systemd-sysctl
  ran before `nf_conntrack` loaded and skipped both keys. Fixed with
  `boot.kernelModules = [ "nf_conntrack" ]` in `modules/core/network.nix`.
  Immediate (no reboot): `sudo systemctl restart systemd-sysctl`, then
  `cat /proc/sys/net/netfilter/nf_conntrack_udp_timeout` must print 60.
- Remaining primary suspect is the **router's** UDP timeout (local fix only
  covers the PC side): raise UDP timeout to 180-300s, enable UPnP, or static
  port-forward UDP 1119-1120, 3724, 4000, 6113-6114 to this PC
  (`192.168.1.135`). Current match still needs a relaunch regardless.

## Update 2026-10-12 — Windows never drops: it's the Linux path
Same machine/network on Windows: zero disconnects. Router, ISP, and cabling
are exonerated as primary causes — the difference is client-side on Linux.
Ranked Linux-specific suspects:
1. **Client stall → lockstep timeout.** HotS drops clients that stop answering.
   DXVK shader-compile hitches (new map/effects each session) and the
   `schedutil` governor (GameMode can't set performance — pkexec denied) can
   stall the client for seconds where native D3D11 on Windows never hitches.
   Fits "random once per session" (fresh compiles each new session).
2. **Wine/Proton UDP stack differences** (socket options, ICMP-unreachable
   handling, interface enumeration) vs native Winsock.
3. **r8169 Linux driver** vs the Windows Realtek driver (burst loss under
   load). NIC counters have been clean so far — weak suspect.
4. Router NAT expiry is demoted: same router serves Windows fine (Windows may
   keep UDP alive differently, so not fully excluded — keep the timeout fixes).

## Capture kit for the next drop (distinguishes stall vs network)
- `PROTON_LOG=1` is now in the Lutris game env (yml `system.env`, takes
  effect next Battle.net launch, log lands in `~/steam-0.log`). Remove after
  capture. If Lutris Configure->Save strips it, re-add it the same way.
- Before queueing, start a UDP ring buffer (needs sudo, run by hand):
  `sudo tcpdump -i enp5s0 -C 50 -W 4 -w /tmp/hots-udp.pcap udp`
  (keeps the last ~200MB; all UDP, game server IP varies per match).
- Optional next-session CPU test (gamemode can't do this itself):
  `echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor`
  then revert with `schedutil` after. If drops stop on performance, it's
  stall-induced.
- After a drop, analyze: if the client stops SENDING seconds before the
  server goes quiet → client stall (hypothesis 1); if the client keeps
  sending while the   server stops answering → network/server path.

## Verify the next drop (do before changing anything else)
```bash
date -u; ss -tnp | grep 1119; ss -una | head -30
ping -c 20 -i 0.2 137.221.106.15 | tail -5
journalctl --since "15 minutes ago" --no-pager | grep -viE "blocky.*queryLog" | tail -40
cat /sys/class/net/enp5s0/statistics/rx_dropped /sys/class/net/enp5s0/statistics/tx_dropped
```
If TCP :1119 is ESTAB but no UDP to the server again → NAT/Proton path, not LAN.

## Follow-ups (not applied, diagnose next if drops continue)
- GameMode perf: `pkexec cpugovctl set performance` → Not authorized; governors
  stay `schedutil`. Add a polkit rule for `org.freedesktop.policykit.exec` /
  gamemode, or set `power-profiles-daemon` to performance for sessions.
- One-session Proton log: add `PROTON_LOG: 1` to the same yml `system.env`,
  reproduce a drop, read `~/steam-*.log` for WS2_32/UDP errors. Remove after.
- Long monitor: `mtr -rwzb 137.221.106.15` + timestamped ping during a session
  to separate ISP jitter from local causes.
- Blizzard ports reference (outgoing; NixOS default firewall already allows
  established): TCP 1119, 3724, 6113; UDP 1119-1120, 3724, 4000, 6113-6114.
