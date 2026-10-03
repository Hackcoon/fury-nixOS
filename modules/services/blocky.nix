# ============================================================================
# blocky.nix — Pi-hole-like DNS adblocking (Blocky), localhost:53.
#
# CHAIN: apps -> systemd-resolved (127.0.0.53) -> Blocky (127.0.0.1:53) ->
# DoT upstream. Upstream auto-follows `dns.provider` (quad9/cloudflare/google/
# opendns) unless `dns.upstreamOverride` is set — which wins, verbatim. With
# provider=native and no override, upstream falls back to google (DHCP IPs
# aren't knowable at build time): set dns.upstreamOverride to the router or
# plain IPs to keep adblocking on DoT-blocking networks, or disable Blocky
# for true native.
# VERSION NOTE: nixpkgs 26.05 ships Blocky 0.29.0, which uses
#   blocking.blackLists / blocking.whiteLists.
# Newer Blocky (>=0.33, e.g. nixpkgs-unstable 0.34.0) renamed these to
#   blocking.denyLists / blocking.allowLists. Overriding with
#   `services.blocky.package = unstablePkgs.blocky;` also requires renaming
#   every blackLists->denyLists and whiteLists->allowLists below, then
#   `nixos-rebuild build` to validate. Staying on 0.29 for now — no action.
# OPTIONAL: drop for minimal (dns.nix DoT still applies without it).
#
# NATIVE NETWORKS (hotel/cafe/portals) — three postures, pick one:
#   1. Quick stop / portal login: DISABLE Blocky (comment its import below).
#      Portal logins hijack plain DNS to reach the login page — Blocky bypasses
#      local DNS, so the page never loads. provider=native alone is the move.
#   2. Long stay, want filtering: native + dns.upstreamOverride (router/plain
#      IPs). Ads stay blocked; DoT privacy is lost, but the local net sees
#      queries under true native anyway — nothing extra given away.
#   3. Home/trusted net: provider=X + Blocky on (current state). No action.
# ============================================================================
{ config, lib, ... }:

{
  services.blocky = {
    enable = true;
    settings = {
      # ── Listen: localhost only ──
      # systemd-resolved keeps 127.0.0.53 — no port conflict.
      ports.dns = "127.0.0.1:53";
      # ----------------------------------------------------------------------

      # ── UPSTREAM (DoT, encrypted) — auto-follows dns.provider ──
      # dns.upstreamOverride (see dns.nix) wins over everything below when
      # set — plain IPs/router for DoT-blocked networks. null = this if/else.
      upstreams.groups.default =
        if config.dns.upstreamOverride != null then config.dns.upstreamOverride
        else if config.dns.provider == "quad9" then [
          "tcp-tls:dns.quad9.net:853"
          "tcp-tls:149.112.112.112:853"
        ] else if config.dns.provider == "cloudflare" then [
          "tcp-tls:cloudflare-dns.com:853"
          "tcp-tls:1.0.0.1:853"
        ] else if config.dns.provider == "opendns" then [
          "tcp-tls:dns.opendns.com:853"
          "tcp-tls:208.67.220.220:853"
        ] else [
          # google — also the fallback for provider=native (DHCP upstream
          # unknowable at eval time; want true native? disable Blocky).
          "tcp-tls:dns.google:853"
          "tcp-tls:8.8.4.4:853"
        ];

      # ── MANUAL PIN (parked): lock Blocky to one provider ──
      # Normally the if/else above follows dns.provider automatically — leave
      # this parked and one flip in configuration.nix moves everything.
      # WHEN: split-brain DNS on purpose. Example: system stays on google for a
      #   strict work network, but Blocky's upstream stays
      #   Quad9-filtered. Or debugging: pin Cloudflare here while the system
      #   stays put, compare breakage, revert.
      # HOW (both steps, in order — skipping step 1 breaks the build because
      #   Nix forbids two values for the same setting in one block):
      #   1. Comment out the whole `upstreams.groups.default = if ...` block above.
      #   2. Uncomment exactly ONE line below (label line stays commented —
      #      only the `upstreams.groups.default = ...` line takes effect).
      # Quad9:
      # upstreams.groups.default = [ "tcp-tls:dns.quad9.net:853" "tcp-tls:149.112.112.112:853" ];
      # Cloudflare:
      # upstreams.groups.default = [ "tcp-tls:cloudflare-dns.com:853" "tcp-tls:1.0.0.1:853" ];
      # OpenDNS:
      # upstreams.groups.default = [ "tcp-tls:dns.opendns.com:853" "tcp-tls:208.67.220.220:853" ];
      # Google:
      # upstreams.groups.default = [ "tcp-tls:dns.google:853" "tcp-tls:8.8.4.4:853" ];
      # ----------------------------------------------------------------------

      # ── BOOTSTRAP: plain-IP DoH for the first DoT handshake ──
      # DoT needs a hostname resolved before TLS verifies — bootstrap answers
      # that chicken-and-egg over plain IPs.
      bootstrapDns =
        if config.dns.provider == "quad9" then [
          { upstream = "https://dns.quad9.net/dns-query"; ips = [ "9.9.9.9" "149.112.112.112" ]; }
        ] else if config.dns.provider == "cloudflare" then [
          { upstream = "https://cloudflare-dns.com/dns-query"; ips = [ "1.1.1.1" "1.0.0.1" ]; }
        ] else if config.dns.provider == "opendns" then [
          { upstream = "https://dns.opendns.com/dns-query"; ips = [ "208.67.222.222" "208.67.220.220" ]; }
        ] else [
          { upstream = "https://dns.google/dns-query"; ips = [ "8.8.8.8" "8.8.4.4" ]; }
        ];

      # ── MANUAL BOOTSTRAP PIN (parked): same procedure ──
      # WHEN: almost never on its own — only with pinned upstreams above AND
      # want the first handshake on a different provider too. Normally leave
      # parked; bootstrap follows dns.provider with upstreams.
      # HOW: 1. Comment out the whole `bootstrapDns = if ...` block above.
      #      2. Uncomment exactly ONE line below (same duplicate-value rule).
      # Quad9:      [ { upstream = "https://dns.quad9.net/dns-query"; ips = [ "9.9.9.9" "149.112.112.112" ]; } ]
      # Cloudflare: [ { upstream = "https://cloudflare-dns.com/dns-query"; ips = [ "1.1.1.1" "1.0.0.1" ]; } ]
      # OpenDNS:    [ { upstream = "https://dns.opendns.com/dns-query"; ips = [ "208.67.222.222" "208.67.220.220" ]; } ]
      # Google:     [ { upstream = "https://dns.google/dns-query"; ips = [ "8.8.8.8" "8.8.4.4" ]; } ]
      # ----------------------------------------------------------------------

      # ── BLOCKING (Pi-hole equivalent): hosts/wildcard lists only ──
      # Raw uBO/EasyList filter syntax (||, ##, $script, redirect=, etc.) does
      # NOT work in DNS blockers — hosts / plain-domain / wildcard lists only.
      # Hagezi Pro already compiles EasyList + EasyPrivacy + uBO domains, so
      # never add raw EasyList/uAssets URLs. Tiers below are SWAPS, not stacks
      # (Pro vs Pro++ vs Ultimate vs Normal vs Light — pick ONE).
      blocking = {
        blackLists.ads = [
          # 1. StevenBlack unified hosts (~70k domains).
          #    What: base ads + malware + tracking. Merges AdAway, MVPS,
          #      yoyo (Peter Lowe), and others into one hosts file.
          #    Disable when: almost never — it's the safest base. Only for
          #      a minimal setup (Hagezi alone covers ~95% of it) or debugging
          #      a false-positive with fewer moving parts.
          "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"

          # 2. Hagezi Pro wildcard (~200-300k domains, wildcard *.example.com).
          #    What: the heavy lifter. Ads, trackers, telemetry, Windows/Apple/
          #      Android bloat, affiliate and analytics domains. DNS rebuild of
          #      EasyList + EasyPrivacy + uBO domain rules.
          #    Disable/downgrade when: apps or sites break — banking, smart-TV
          #      streaming, game launchers, MS Office/Adobe activation, corporate
          #      VPN/MDM. Fix by allowlisting the domain first; if breakage is
          #    constant, swap pro.txt for normal or light:
          #      .../wildcard/normal.txt or .../wildcard/light.txt
          "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.txt"
          # 2b. Hagezi Pro++ wildcard (~247k) — SWAP, do not stack with Pro.
          #    What: Pro + extra aggressive trackers/affiliate domains. Blocks
          #      more referral domains that double as trackers.
          #    Usecase: Pro runs clean for weeks yet tracking is still visible, and
          #      occasional self-allowlisted breakage is acceptable.
          #    When to deactivate/revert to Pro: shopping affiliate links die,
          #      SSO/logins or apps misbehave. Comment out and re-enable pro.txt.
          # "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.plus.txt"
          # 2c. Hagezi Ultimate wildcard (~271k) — SWAP, do not stack with Pro/Pro++.
          #    What: maximum. Pro++ + META trackers, extra MS/Xbox telemetry,
          #      location/IP trackers. Expect side-effects: FB/Messenger limits,
          #      WhatsApp avatar/help-center quirks, Windows Spotlight / Xbox
          #      achievements history, extra CAPTCHAs / wrong region defaults.
          #    Usecase: hardened privacy box where breakage is acceptable and
          #      the allowlist is actively maintained (facebook.txt, microsoft.txt shares).
          #    When to deactivate/revert to Pro: anything above breaks daily use.
          # "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/ultimate.txt"
          # 2d. Hagezi Normal wildcard (~180k) — DOWNGRADE swap, do not stack.
          #    What: Pro minus error trackers (Bugsnag, Crashlytics, Firebase,
          #      Sentry) and other breakage-prone entries. Balanced ads +
          #      malware + phishing coverage.
          #    Usecase: shared/family machine with no admin handy, banking apps,
          #      smart-TV, games, Office/Adobe, corporate VPN/MDM keep breaking
          #      on Pro. Lowest hassle that still blocks most junk.
          # "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/multi.txt"
          # 2e. Hagezi Light wildcard (~34k, Top 1M/10M domains only) — minimal swap.
          #    What: tiny subset of Normal, only popular domains. Minimal RAM/CPU,
          #      minimal breakage. Also skips error trackers.
          #    Usecase: old/low-RAM hardware, slow reloads, or "even Normal is
          #      too much" environments. Pair with uBlock Origin in browser to
          #      cover what DNS misses.
          # "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/light.txt"

          # 3. Peter Lowe's adservers, hosts build (~3.5k domains).
          #    What: small, hand-curated pure-adserver list, maintained since
          #      the 2000s. Very low false-positive rate. Overlaps StevenBlack
          #      but updates independently, so it catches new adservers fast.
          #    Disable when: almost never. Only for ad-ops work or loading
          #      a flagged adserver for testing.
          "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=1&mimetype=plaintext"

          # 4. URLHaus malware hosts (few thousand domains, high churn).
          #    What: NOT ads — active malware-distribution hosts from abuse.ch.
          #      Complements Quad9/cloudflare-malware upstream with a local copy.
          #    Disable when: doing malware research in a VM/lab, or a needed
          #      site was compromised, got listed, and hasn't been
          #      delisted yet. Otherwise always keep on.
          "https://malware-filter.gitlab.io/malware-filter/urlhaus-filter-hosts.txt"

          # Extra (uncomment to enable):
          # 5. OISD domainswild2 (big, ~1M domains, allowlist-managed).
          #    What: broad coverage with explicit zero-false-positive policy and
          #      self-service unblock requests. Good "set and forget" addition.
          #    Enable when: Hagezi Pro misses social/trackers still seen.
          #    Disable/remove when: reloads get slow, RAM use climbs (2 big
          #      wildcard lists), or stricter blocking than OISD allows is wanted — OISD
          #      deliberately permits some annoyances to avoid breakage.
          # "https://oisd.nl/domainswild2"
          # 6. Hagezi NSFW wildcard (~100k domains) — OFF by default.
          #    What: porn / adult sites only. No ads/malware logic, purely adult.
          #    Usecase: shared PC, kids, or work machine where adult must not
          #      resolve. Enable by uncommenting AND adding "nsfw" to
          #      clientGroupsBlock below.
          #    Disable when: false-positive on dating/health/education, or adult
          #      filtering is unneeded — keep off on a single-user box.
          # "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/nsfw.txt"
          # 7. Hagezi Gambling wildcard (~100k domains) — OFF by default.
          #    What: betting / casino / lottery sites. Full version; mini/medium
          #      exist if RAM is tight (.../wildcard/gambling.mini.txt).
          #    Usecase: self-exclusion, kids, work compliance.
          #    Disable when: blocks sports/news sites with betting subsections
          #      actually needed, or no gambling concern — keep off otherwise.
          # "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/gambling.txt"
          # NOTE: do not add raw EasyList/uAssets URLs — ABP/cosmetic syntax, Blocky can't use them.
        ];
        # To enable 6/7 as separate toggleable groups instead of lumping into
        # "ads", use e.g.:
        # blackLists.nsfw = [
        #   "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/nsfw.txt"
        #   "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/gambling.txt"
        # ];
        # clientGroupsBlock.default = [ "ads" "nsfw" ]; # remove "nsfw" to disable without commenting URLs
        # Allowlist — for sites Blocky blocks that should load. Takes
        # precedence over blackLists. Add bare domain + wildcard to cover subs.
        # Example: site.example.com broken -> add both lines below, rebuild.
        # NOTE: this Blocky version uses whiteLists (newer uses allowLists).
        whiteLists.ads = [
          # "needed-site.com"
          # "*.needed-site.com"
        ];
        clientGroupsBlock.default = [ "ads" ];
      };
      # ----------------------------------------------------------------------

      # ── Caching: 5–30 min window + prefetch ──
      # Short enough that blocklist updates and DNS changes propagate fast,
      # prefetching refreshes popular entries before they expire (no lookup lag).
      caching = {
        minTime = "5m";
        maxTime = "30m";
        prefetching = true;
      };
      # ----------------------------------------------------------------------
    };
  };

  # ── Route everything through Blocky ──
  # All local queries -> 127.0.0.1 (Blocky); Blocky does TLS upstream itself,
  # so resolved -> Blocky stays plain localhost (DoT off here).
  networking.nameservers = [ "127.0.0.1" ];
  services.resolved.settings.Resolve.DNSOverTLS = "no";
  # ----------------------------------------------------------------------
}
