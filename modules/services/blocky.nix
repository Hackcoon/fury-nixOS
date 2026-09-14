# Pi-hole-like DNS adblocking (Blocky).
# Upstream follows `dns.provider` in configuration.nix ("google" <-> "cloudflare" <-> "quad9").
# Manual overrides commented below each section — uncomment to pin without flipping dns.provider.
# VERSION NOTE: nixpkgs 26.05 ships Blocky 0.29.0, which uses
#   blocking.blackLists / blocking.whiteLists.
# Newer Blocky (>=0.33, e.g. nixpkgs-unstable 0.34.0) renamed these to
#   blocking.denyLists / blocking.allowLists. If you override with
#   `services.blocky.package = unstablePkgs.blocky;` you must also rename
#   every blackLists->denyLists and whiteLists->allowLists below, then
#   `nixos-rebuild build` to validate. Staying on 0.29 for now — no action.
{ config, lib, ... }:

{
  services.blocky = {
    enable = true;
    settings = {
      # Listen only on localhost — systemd-resolved keeps 127.0.0.53, no port conflict.
      ports.dns = "127.0.0.1:53";

      # --- UPSTREAM (DoT, encrypted) — auto-follows dns.provider ---
      upstreams.groups.default =
        if config.dns.provider == "quad9" then [
          "tcp-tls:dns.quad9.net:853"
          "tcp-tls:149.112.112.112:853"
        ] else if config.dns.provider == "cloudflare" then [
          "tcp-tls:cloudflare-dns.com:853"
          "tcp-tls:1.0.0.1:853"
        ] else [
          # google (active when dns.provider = "google")
          "tcp-tls:dns.google:853"
          "tcp-tls:8.8.4.4:853"
        ];

      # Manual pin (ignore dns.provider) — uncomment ONE block:
      # Quad9:
      # upstreams.groups.default = [ "tcp-tls:dns.quad9.net:853" "tcp-tls:149.112.112.112:853" ];
      # Cloudflare:
      # upstreams.groups.default = [ "tcp-tls:cloudflare-dns.com:853" "tcp-tls:1.0.0.1:853" ];
      # Google:
      # upstreams.groups.default = [ "tcp-tls:dns.google:853" "tcp-tls:8.8.4.4:853" ];

      # Bootstrap for initial DoT handshake (plain IPs, no hostname needed).
      bootstrapDns =
        if config.dns.provider == "quad9" then [
          { upstream = "https://dns.quad9.net/dns-query"; ips = [ "9.9.9.9" "149.112.112.112" ]; }
        ] else if config.dns.provider == "cloudflare" then [
          { upstream = "https://cloudflare-dns.com/dns-query"; ips = [ "1.1.1.1" "1.0.0.1" ]; }
        ] else [
          { upstream = "https://dns.google/dns-query"; ips = [ "8.8.8.8" "8.8.4.4" ]; }
        ];

      # Manual bootstrap pin:
      # Quad9:      [ { upstream = "https://dns.quad9.net/dns-query"; ips = [ "9.9.9.9" "149.112.112.112" ]; } ]
      # Cloudflare: [ { upstream = "https://cloudflare-dns.com/dns-query"; ips = [ "1.1.1.1" "1.0.0.1" ]; } ]
      # Google:     [ { upstream = "https://dns.google/dns-query"; ips = [ "8.8.8.8" "8.8.4.4" ]; } ]

      # --- BLOCKING (Pi-hole equivalent) ---
      # NOTE: raw uBO/EasyList filter syntax (||, ##, $script, redirect=, etc.)
      # does NOT work in DNS blockers. Blocky only understands hosts /
      # plain-domain / wildcard lists. Use the DNS builds below instead —
      # Hagezi Pro already compiles EasyList + EasyPrivacy + uBO domains.
      blocking = {
        blackLists.ads = [
          # 1. StevenBlack unified hosts (~70k domains).
          #    What: base ads + malware + tracking. Merges AdAway, MVPS,
          #      yoyo (Peter Lowe), and others into one hosts file.
          #    Disable when: almost never — it's the safest base. Only if you
          #      want a minimal setup (Hagezi alone covers ~95% of it) or you
          #      are debugging a false-positive and want fewer moving parts.
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
          #    Usecase: you run Pro clean for weeks and still see tracking, and
          #      you're comfortable allowlisting occasional breakage yourself.
          #    When to deactivate/revert to Pro: shopping affiliate links die,
          #      SSO/logins or apps misbehave. Comment out and re-enable pro.txt.
          # "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.plus.txt"
          # 2c. Hagezi Ultimate wildcard (~271k) — SWAP, do not stack with Pro/Pro++.
          #    What: maximum. Pro++ + META trackers, extra MS/Xbox telemetry,
          #      location/IP trackers. Expect side-effects: FB/Messenger limits,
          #      WhatsApp avatar/help-center quirks, Windows Spotlight / Xbox
          #      achievements history, extra CAPTCHAs / wrong region defaults.
          #    Usecase: hardened privacy box where breakage is acceptable and
          #      you will maintain allowlist (facebook.txt, microsoft.txt shares).
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
          #    Disable when: almost never. Only if you do ad-ops work or need
          #      to load a flagged adserver for testing.
          "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=1&mimetype=plaintext"

          # 4. URLHaus malware hosts (few thousand domains, high churn).
          #    What: NOT ads — active malware-distribution hosts from abuse.ch.
          #      Complements Quad9/cloudflare-malware upstream with a local copy.
          #    Disable when: doing malware research in a VM/lab, or a legit
          #      site you need was compromised, got listed, and hasn't been
          #      delisted yet. Otherwise always keep on.
          "https://malware-filter.gitlab.io/malware-filter/urlhaus-filter-hosts.txt"

          # Extra (uncomment to enable):
          # 5. OISD domainswild2 (big, ~1M domains, allowlist-managed).
          #    What: broad coverage with explicit zero-false-positive policy and
          #      self-service unblock requests. Good "set and forget" addition.
          #    Enable when: Hagezi Pro misses social/trackers you still see.
          #    Disable/remove when: reloads get slow, RAM use climbs (2 big
          #      wildcard lists), or you want stricter than OISD allows — OISD
          #      deliberately permits some annoyances to avoid breakage.
          # "https://oisd.nl/domainswild2"
          # 6. Hagezi NSFW wildcard (~100k domains) — OFF by default.
          #    What: porn / adult sites only. No ads/malware logic, purely adult.
          #    Usecase: shared PC, kids, or work machine where adult must not
          #      resolve. Enable by uncommenting AND adding "nsfw" to
          #      clientGroupsBlock below.
          #    Disable when: false-positive on dating/health/education, or you
          #      don't need adult filtering — keep off for a personal single-user box.
          # "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/nsfw.txt"
          # 7. Hagezi Gambling wildcard (~100k domains) — OFF by default.
          #    What: betting / casino / lottery sites. Full version; mini/medium
          #      exist if RAM is tight (.../wildcard/gambling.mini.txt).
          #    Usecase: self-exclusion, kids, work compliance.
          #    Disable when: blocks sports/news sites with betting subsections
          #      you actually need, or no gambling concern — keep off otherwise.
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
        # Allowlist — use this when Blocky blocks a site you want. Takes
        # precedence over blackLists. Add bare domain + wildcard to cover subs.
        # Example: site.example.com broken -> add both lines below, rebuild.
        # NOTE: this Blocky version uses whiteLists (newer uses allowLists).
        whiteLists.ads = [
          # "needed-site.com"
          # "*.needed-site.com"
        ];
        clientGroupsBlock.default = [ "ads" ];
      };

      caching = {
        minTime = "5m";
        maxTime = "30m";
        prefetching = true;
      };
    };
  };

  # Route all local queries through Blocky; Blocky does TLS upstream,
  # so resolved -> Blocky stays plain localhost.
  networking.nameservers = [ "127.0.0.1" ];
  services.resolved.settings.Resolve.DNSOverTLS = "no";
}
