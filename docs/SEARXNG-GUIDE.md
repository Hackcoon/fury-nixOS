# SearXNG on NixOS — Localhost-Only Guide (Native Module)

Self-hosted metasearch on this machine. No Docker, no domain, no HTTPS needed.
Opens at `http://127.0.0.1:8888`.

> Scope: localhost-only + native NixOS module (`services.searx`).
> LAN/public needs nginx + `configureNginx`/`configureUwsgi` — see §9.

## 1. How it works on NixOS 26.05

- Option is `services.searx` (package defaults to `pkgs.searxng`).
- `redisCreateLocally = true` spawns `redis-servers-searx` on a unix socket, auto-wired to `settings.valkey.url`. Kept on for cache even though limiter is off (localhost has no proxy headers, limiter would 429 — see §10).
- `use_default_settings = true` merges your `settings` over upstream defaults. Don't set `settingsFile` — it would override `settings` and drop secrets into `/nix/store` (world-readable).
- Secret via `environmentFile` + `$VAR` syntax. Module runs `envsubst` at activation (`searx-init.service`), so `$SEARXNG_SECRET` never lands in the store.
- Localhost mode uses built-in HTTP server (`configureUwsgi = false`). uwsgi+nginx is only for public/large instances.
- Files live at:
  - Module: `/etc/nixos/modules/services/searxng.nix`
  - Import: `/etc/nixos/configuration.nix`
  - Secret: `/var/lib/searx/searx.env` (0600, never in git)
  - Generated config: `/run/searx/settings.yml`

## 2. One-time setup (secret)

```bash
sudo mkdir -p /var/lib/searx
python3 -c 'import secrets; print("SEARXNG_SECRET="+secrets.token_hex(32))' | sudo tee /var/lib/searx/searx.env >/dev/null
# alt if openssl installed: openssl rand -hex 32 | sed 's/^/SEARXNG_SECRET=/' | sudo tee /var/lib/searx/searx.env >/dev/null
# result: file contains one line: SEARXNG_SECRET=<64-hex-chars>

sudo chown searx:searx /var/lib/searx/searx.env 2>/dev/null || sudo chown root:root /var/lib/searx/searx.env
sudo chmod 600 /var/lib/searx/searx.env
sudo cat /var/lib/searx/searx.env  # verify single line, then close terminal
```

> If `searx` user doesn't exist yet (before first rebuild), `chown root:root` is fine — fix ownership after first rebuild with the first `chown` line. Never put this key in `configuration.nix`, `settings`, GitHub, or `~/dotfiles/`.

## 3. Module (already installed)

`/etc/nixos/modules/services/searxng.nix`:

```nix
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
        limiter = false;  # localhost has no X-Forwarded-For/X-Real-IP — true = 429
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
```

Wired in `/etc/nixos/configuration.nix`:

```nix
./modules/services/searxng.nix
```

Firewall stays closed, no `openFirewall`, no `configureNginx`.

## 4. Rebuild

```bash
cd /etc/nixos
sudo nix flake show  # sanity: shows nixosConfigurations.nixos
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

First build downloads `searxng` + `redis`. Takes 1-3 min.

Rollback if broken:

```bash
sudo nixos-rebuild switch --rollback
# or pick older generation at boot
```

## 5. Verify

```bash
systemctl status searx searx-init redis-searx --no-pager
ss -tlnp | grep 8888
curl -s http://127.0.0.1:8888 | head -20
# don't use curl -I (HEAD) for testing — botdetection blocks it; use GET above
journalctl -u searx -u searx-init -e --no-pager | tail -50
```

Then open in browser: `http://127.0.0.1:8888`

- Search `nixos searxng` — results should appear in <3s.
- Preferences (top-right) persist in cookie, not on disk.

If `curl` hangs: check `bind_address` is `127.0.0.1`, not `::1` (IPv6 localhost mismatch in some browsers).

## 6. Set as default search

- **Zen / Firefox:** Settings → Search → Add Custom Engine → URL: `http://127.0.0.1:8888/search?q=%s` → Set Default. Enable `Add to address bar`.
- **Brave:** Settings → Search engine → Manage → Add → URL: `http://127.0.0.1:8888/search?q=%s`
- Private window works the same — SearXNG holds no login.

## 7. Customize (optional)

Edit `/etc/nixos/modules/services/searxng.nix`, rebuild:

```nix
# examples — add inside settings = { ...; };
general.debug = false;
search.safe_search = 2;  # 0 off, 1 moderate, 2 strict
server.method = "POST";  # hide queries from logs/history (breaks address-bar GET)
enabled_plugins = [ "Hash plugin" "Tor check plugin" ];
```

Disable an engine:

```nix
settings.engines = [
  { name = "google"; disabled = true; }
];
```

Check valid keys: https://docs.searxng.org/admin/settings/

> Flakes only see tracked files: if `/etc/nixos` is a git repo, `git add modules/services/searxng.nix` before rebuild or the file is invisible to the evaluator.

## 8. Backup / restore (fits dotfiles pattern)

Git versions config, not state. State (`/var/lib/searx/`, redis socket) is disposable — rebuild recreates it.

```bash
# backup config (safe — no secret inside)
rsync -av --delete --exclude='.git' --exclude='result' /etc/nixos/ ~/dotfiles/nixos/
# or to nixos-backups snapshot:
rsync -av /etc/nixos/modules/services/searxng.nix ~/nixos-backups/nixos-config-$(date -I)/
git -C ~/dotfiles status --short  # review, then commit + push
```

Never commit:

- `/var/lib/searx/searx.env`
- `/run/searx/settings.yml` (generated, contains rendered secret)
- `hardware-configuration.nix` across hosts

Restore on new machine:

```bash
sudo rsync -av ~/dotfiles/nixos/ /etc/nixos/
# regenerate secret fresh (§2) — do NOT copy searx.env across hosts
sudo nixos-rebuild switch --flake ~/dotfiles/nixos#$(hostname)
```

## 9. Upgrading to LAN / public later (out of scope)

Localhost module deliberately omits these. To expose:

- `services.searx.settings.server.bind_address = "0.0.0.0"` + `openFirewall = true` (LAN) or
- `configureUwsgi = true` + `configureNginx = true` + `domain = "search.example.com"` + ACME/nginx (public). Then set `server.base_url`, `limiterSettings.real_ip`, firewall 80/443.

Don't flip to `0.0.0.0` without limiter + secret — bots will abuse it.

## 10. Troubleshooting

| Symptom | Fix |
|---|---|
| `searx.service failed, missing $SEARXNG_SECRET` | `sudo cat /var/lib/searx/searx.env` must be `SEARXNG_SECRET=...` single line, `chmod 600`. `sudo systemctl restart searx-init searx` |
| `502 / connection refused :8888` | `systemctl status searx-init` — `envsubst` failed. Check `$` syntax (not `@VAR@` on 26.05). Check port free: `ss -tlnp \| grep 8888` |
| `429 TOO MANY REQUESTS` + `X-Forwarded-For nor X-Real-IP header is set!` | Expected with `limiter=true` on direct localhost (no nginx). Fix is `limiter=false` (§3). Re-enable limiter only behind nginx with `limiterSettings.real_ip = { x_for=1; ipv4_prefix=32; ipv6_prefix=56; }`. Test with `curl -s` (GET), not `curl -I` (HEAD). |
| `redis connection refused / unixSocket` | `systemctl status redis-searx`. `redisCreateLocally` must be `true`. Don't hand-set `settings.valkey.url` — module sets it. |
| `settings not applying` | You set `settingsFile` — it overrides `settings`. Remove it. Also `git add` new files before `--flake` rebuild. |
| `Slow / timeouts` | Normal for first query (engines warming). If persistent: ISP blocks Google/Bing. Disable that engine (§7) or enable `image_proxy = false` to test. |
| `Build fails on unstable` | Keep `pkgs.searxng` from stable 26.05 (your NVIDIA setup is pinned stable for a reason). Don't pull from `unstablePkgs`. |

Logs:

```bash
journalctl -u searx -f
journalctl -u searx-init --no-pager | tail -30
cat /run/searx/settings.yml | head -40  # rendered, contains secret — don't paste online
```

## 11. Disable / uninstall

```bash
# in searxng.nix: services.searx.enable = false;
sudo nixos-rebuild switch --flake /etc/nixos#nixos
sudo rm -rf /var/lib/searx /var/cache/searx
```

## 12. Update

```bash
sudo nix flake update --flake /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#nixos
curl -s http://127.0.0.1:8888 | head -20
```

SearXNG tracks upstream engines — update monthly or search quality drifts as Google/Bing HTML changes.
