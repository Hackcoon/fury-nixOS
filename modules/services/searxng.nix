# ============================================================================
# searxng.nix — SearXNG metasearch, localhost-only.
#
# Private search at http://127.0.0.1:8888 aggregating upstream engines — no
# direct Google/Bing traffic from the browser. Localhost-bound + limiter off
# (single user, no abuse case) + image proxy so thumbnails don't leak the IP.
# Secret comes from /var/lib/searx/searx.env ($SEARXNG_SECRET) — create that
# file manually (0600); never bake the key into this module (world-readable
# /nix/store). OPTIONAL: drop for minimal.
# ============================================================================
{ config, pkgs, lib, ... }:

{
  # ── Instance: local redis, localhost:8888, env-file secret ──
  # use_default_settings = upstream defaults + our overrides below (don't
  # replace with a from-scratch settings.yml unless diverging hard).
  services.searx = {
    enable = true;
    redisCreateLocally = true;
    environmentFile = "/var/lib/searx/searx.env"; # provides $SEARXNG_SECRET
    settings = {
      use_default_settings = true;
      server = {
        bind_address = "127.0.0.1"; # localhost-only, no LAN exposure
        port = 8888;
        secret_key = "$SEARXNG_SECRET";
        limiter = false;      # rate limiter off — single-user box
        image_proxy = true;   # proxy thumbnails (no direct engine contact)
        method = "GET";
      };
      search = {
        safe_search = 1;
        autocomplete_min = 2;
      };
      server.public_instance = false;
    };
  };
  # ----------------------------------------------------------------------
}
