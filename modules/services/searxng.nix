# SearXNG localhost-only instance.
{ config, pkgs, lib, ... }:

{
  services.searx = {
    enable = true;
    redisCreateLocally = true;
    environmentFile = "/var/lib/searx/searx.env";
    settings = {
      use_default_settings = true;
      server = {
        bind_address = "127.0.0.1";
        port = 8888;
        secret_key = "$SEARXNG_SECRET";
        limiter = false;
        image_proxy = true;
        method = "GET";
      };
      search = {
        safe_search = 1;
        autocomplete_min = 2;
      };
      server.public_instance = false;
    };
  };
}
