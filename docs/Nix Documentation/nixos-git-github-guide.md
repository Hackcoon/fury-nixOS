# Managing NixOS with Git & GitHub — The Complete Beginner Guide

**For:** you — repo already lives at `/etc/nixos` (2 commits, root-owned), `gh` CLI installed, GitHub account: `Hackcoon` (git name `furynix`).
**You know nothing about git.** That's fine — this guide teaches exactly what NixOS management needs, nothing more. Read §1–3 once; keep the rest as a reference. §8 covers **jj (Jujutsu)**, a friendlier git front-end you asked about — read §1–4 before it, since jj builds on the same concepts.

Companion: `nixos-modular-guide.md` (module structure), `nixos-modularization-plan.md` (the original audit).

---

## 1. What Git Actually Is (60 seconds)

Git is a **time machine for folders**. It stores snapshots ("commits") of your files. Each commit remembers:

- **What** changed (line-by-line)
- **When** and **who**
- **Which commit came before** — forming a chain: a *history*

```
2950814  monolith snapshot          (Sep 6, 00:39)
   ↓
2e04917  modularize + HM foundation (Sep 6, 01:02)
   ↓
(your next commit here)
```

GitHub is git's **cloud counterpart**: a copy of your history on GitHub's servers ("a remote"). Push = upload commits; clone/pull = download. Local git works 100% offline; GitHub is for backup + sync + browsing.

**Why this matters for NixOS specifically:**
1. Every config change is reversible at the *file* level (`nix-rollback` only rolls back whole generations)
2. You can see *why* a line exists — `git blame modules/hardware/nvidia.nix` shows which commit added it and its message
3. Your config survives disk failure — it's on GitHub
4. Flakes *require* git — Nix literally only reads git-tracked files

## 2. The Words You Need (vocabulary, once)

| Term | Meaning | NixOS analogy |
|---|---|---|
| **repository (repo)** | a folder git watches | `/etc/nixos` |
| **commit** | one named snapshot | like a generation, but for files |
| **staging / index** | "marked for next commit" | — |
| **branch** | a parallel line of history | like a specialisation |
| **HEAD** | "the commit I'm on now" | like `/run/current-system` pointing at a generation |
| **remote** | another copy (e.g. GitHub) | like a substituter, but for your config |
| **origin** | the default remote's nickname | — |
| **push / pull** | upload / download commits | — |
| **clone** | full download of a repo | `nixos-install` for configs |
| **merge** | join two branches' changes | module system merging lists |
| **.gitignore** | files git should never track | — |

## 3. The Only Workflow You Need Daily

```bash
# 1. you edited something in /etc/nixos (as root)
sudo nano /etc/nixos/modules/core/network.nix

# 2. Nix needs to see it — git add BEFORE rebuild (flakes rule!)
sudo git -C /etc/nixos add -A

# 3. test it
nix-test

# 4. works? commit it.  (config-save = add . && commit)
sudo git -C /etc/nixos commit -m "network: explain why ignore-auto-dns needed"
nix-switch

# 5. upload to GitHub (after §6 is set up)
sudo git -C /etc/nixos push
```

That's 90% of your git life. Your aliases `config-status`, `config-diff`, `config-log`, `config-save` already wrap steps 2/4.

**Commit message style** — one line, `area: what and why`:

```
nvidia: explain why powerManagement prevents resume crashes
packages: add delta pager via home-manager
ssd: swap 30d gc for nh clean with keep-10 floor
```

The `area` prefix (module name) makes `config-log` scannable. The "why" is the part you'll thank yourself for in 6 months.

## 4. The Commands That Matter (cheat sheet)

All with `sudo git -C /etc/nixos ...` because the repo is root-owned.

> If git complains "dubious ownership", allow it once (as the user that runs git):
> `git config --global --add safe.directory /etc/nixos` (repeat with `sudo` for root's config).

### Looking (safe, run anytime)

```bash
git status                  # what changed, what's staged  (config-status)
git diff                    # unstaged changes, line by line (config-diff)
git diff --staged           # changes already git-added
git log --oneline           # history, one line each       (config-log)
git log -p modules/core/boot.nix   # full history of ONE file
git show 2e04917            # what exactly one commit did
git blame modules/core/nix.nix     # who/which commit wrote each line
```

### Saving

```bash
git add -A                  # stage everything (new + modified + deleted)
git add modules/core/nix.nix  # stage one file
git commit -m "area: message"
git commit                  # opens your editor for longer messages
```

### Undoing (read twice before running)

```bash
git restore modules/core/nix.nix          # discard UNSTAGED edits to one file
git restore --staged modules/core/nix.nix # un-stage (keep edits)
git restore .                             # discard ALL unstaged edits (dangerous)
git revert 2e04917           # NEW commit that undoes an old one (history stays honest — safest)
git reset --hard HEAD^       # delete last commit + its changes (DESTRUCTIVE)
```

Rule: **revert for anything already pushed** (history is shared), reset only for local mistakes made 30 seconds ago.

### History time travel

```bash
git checkout 2950814 -- configuration.nix  # bring ONE file back from an old commit
git diff 2950814 HEAD -- modules/           # "what changed in modules/ since the monolith?"
git stash                    # temp-save uncommitted work; git stash pop to restore
```

## 5. Branches — the "try risky things" tool

`master` = your known-good line. A branch = a playground that shares history:

```bash
sudo git -C /etc/nixos checkout -b scx-experiment    # new branch, switch to it
# ... edit modules/hardware/ssd.nix, enable services.scx ...
sudo git -C /etc/nixos add -A
sudo git -C /etc/nixos commit -m "ssd: try scx_lavd scheduler"
nix-test                                             # live with it for a day
```

Happy ending:

```bash
sudo git -C /etc/nixos checkout master
sudo git -C /etc/nixos merge scx-experiment
sudo git -C /etc/nixos branch -d scx-experiment     # delete the merged branch
```

Bad ending (throw it away):

```bash
sudo git -C /etc/nixos checkout master
sudo git -C /etc/nixos branch -D scx-experiment     # -D = force-delete unmerged
```

⚠️ **Important interaction with NixOS:** `nixos-rebuild` builds from *whatever branch is checked out*. Always `checkout master` before a "known-good" rebuild. Branch + `nix-test` (not `nix-switch`) = nothing permanent ever happens from a branch.

## 6. GitHub — Set Up Once (do this now)

Your repo is currently local-only. Put it on GitHub in 4 commands.

### 6a. Log in (as root, since the repo is root's)

```bash
sudo gh auth login
```

Answer the prompts exactly like this:
- **Where do you use GitHub?** → GitHub.com
- **Preferred protocol?** → SSH
- **Generate a new SSH key?** → Yes (skip if it asks to overwrite; accept default path)
- **Enter a passphrase** → empty (press Enter) is fine for a config repo
- **Title your key** → `nixos-fury-desktop`
- **How to authenticate?** → Login with a web browser → it shows an 8-character code → press Enter → browser opens → paste code → authorize

This does three things at once: authenticates `gh`, creates root's SSH key (`/root/.ssh/`), and **registers that key on your GitHub account**.

### 6b. Create the repo and push, one shot

```bash
sudo gh repo create nixos-config --private --source=/etc/nixos --push
```

That single command: creates `Hackcoon/nixos-config` (private), sets it as remote `origin`, pushes both commits. Verify:

```bash
sudo git -C /etc/nixos remote -v        # should show origin → your repo
sudo git -C /etc/nixos push             # "Everything up-to-date"
```

**Private, not public.** Your config reveals hardware, hostnames, installed tools, your email. Make it public later only if you decide to.

### 6c. Add a .gitignore first (before more pushes)

Some files must never enter history. Create `/etc/nixos/.gitignore`:

```
# nix build output symlink (created by nixos-rebuild build in the repo dir)
result

# pre-migration backup tarballs (they're snapshots, not config)
config-backup-*.tar.gz

# editor noise
*.swp
*~
```

Then:

```bash
sudo git -C /etc/nixos add .gitignore
sudo git -C /etc/nixos commit -m "git: ignore build outputs and backup tarballs"
```

(The already-committed `config-backup-2026-09-06.tar.gz` can stay in history — it's your pre-migration monolith, arguably worth keeping there.)

### 6d. Everyday GitHub usage

```bash
sudo git -C /etc/nixos push           # upload new commits (after config-save)
sudo git -C /etc/nixos pull            # download commits made elsewhere
sudo gh repo view --web                # open the repo in a browser
```

If push ever says "rejected — fetch first", someone (future-you on another machine) pushed; run `pull`, fix if needed, `push` again.

## 7. Golden Rule: Secrets

Git remembers **everything forever**. If a key lands in a commit, deleting the file doesn't delete it from history — and pushes copy it to GitHub.

- ✅ What's in your repo today: safe. `flake.lock`, configs, modules. The Hermes key lives in `/var/lib/hermes/env`, outside the repo, referenced by path only. Keep it that way.
- ❌ Never commit: SSH keys (`id_*`), API keys, tokens, `environmentFiles` *contents* (paths are fine — that's the whole point).
- The comment block at the top of `modules/programs/ai-services.nix` explains the correct pattern (sops-nix/agenix) for when you want fully declarative secrets.

## 8. jj (Jujutsu) — Git With Training Wheels Off

**Docs:** https://docs.jj-vcs.dev/latest/ — this section is the NixOS-relevant subset.

`jj` is a modern VCS built *on top of git*. Your repo stays a normal
git repo (GitHub, flakes, `git` CLI all keep working unchanged) — jj
just gives you a friendlier way to work with it. The package in
nixpkgs is `jujutsu`, binary is `jj`, current version 1.9.2.

### Why it's genuinely easier (verified on a real colocated test repo)

- **No staging area.** Every file on disk is *automatically snapshotted*
  into the working-copy commit whenever you run any `jj` command.
  No `git add` — you literally cannot forget it.
- **The killer feature for NixOS:** that auto-snapshot **puts new files
  into the git index**. The #1 flakes gotcha (§3: "Nix only sees
  git-tracked files") disappears — create a module, run `jj st`,
  and nixos-rebuild can already see it.
- **No "detached HEAD" anxiety.** Your work-in-progress is always a
  real commit with a real ID; finishing it just means giving it a
  description.
- **Undo for everything.** `jj undo` reverts the last *operation*
  (even a push!), and `jj op log` shows every operation ever — git
  has nothing comparable for beginners.
- **Conflicts can be committed.** Nothing ever fails mid-operation
  with your repo in a broken half-state.

### Set it up on /etc/nixos (colocated mode)

"Colocated" = jj and git share the same `.git` — jj imports/exports
automatically on every command. This is exactly what you want, since
Nix reads the git repo directly:

```bash
# 1. install jj (add jujutsu to modules/packages/system-packages.nix,
#    or just for root's experiments:
nix profile install nixpkgs#jujutsu   # as fury; for the root-owned
                                      # repo, use sudo -i first
                                      # (sudo -i = fresh root login shell;
                                      #  sudo -E preserves your env — use -i here
                                      #  so root's jj config/SSH apply cleanly)

# 2. enable colocation — one-time, non-destructive:
cd /etc/nixos
sudo jj git init --colocate .         # imports existing history

# 3. identity (root's config, since the repo is root-owned):
# NOTE: new jj uses `jj config set user.name` (no --user flag):
sudo jj config set user.name "furynix"
sudo jj config set user.email "235014707+Hackcoon@users.noreply.github.com"
```

Nothing about the repo changes on disk — same files, same history,
`.jj/` metadata added. You can keep using plain git whenever you want.

### Your daily loop, jj edition

```bash
cd /etc/nixos
sudo nano modules/core/network.nix     # edit anything

sudo jj st                             # auto-snapshot happened; shows changes
                                       # (and git index updated → nix sees them!)

nix-test                               # try it

sudo jj describe -m "network: explain ignore-auto-dns"   # name the change

nix-switch                             # make permanent

sudo jj bookmark set main -r @-       # move 'main' to include the finished change
sudo jj git push --bookmark main      # backup to GitHub
```

The mental shift: in git you *create* commits; in jj your work
*already is* a commit and you just *name* it (`describe`) and *place*
it (`bookmark set`).

### The four jj concepts that replace git's

| Git concept | jj replacement |
|---|---|
| staging area + `git add` | automatic — every command snapshots |
| `HEAD` / current branch | `@` — "the working-copy commit", always exists |
| branches | **bookmarks** (`main` is one) — updated manually |
| reflog | **operation log** — every jj AND git command, undoable |

### Translation table (git → jj)

| You want | git | jj |
|---|---|---|
| What changed? | `git status` / `config-status` | `jj st` |
| Diff of work | `git diff` | `jj diff` |
| History | `git log --oneline` | `jj log` |
| Commit work | `git add -A && git commit` | `jj describe` (already snapshotted) |
| Fix last message | `git commit --amend` | `jj describe` again (yes, edit in place) |
| Undo ANYTHING | (reflog archaeology) | `jj undo` — or `jj op log` then `jj op restore <op>` |
| Discard work | `git reset --hard` (destructive!) | `jj abandon` (safe — recoverable via op log) |
| Unstage a file | `git restore --staged f` | `jj file untrack f` (needs .gitignore entry) |
| Old experiment | `git checkout -b name` | `jj new main -m "experiment"` |
| Merge / abandon | `git merge` / `git branch -D` | `jj squash` / `jj abandon` |
| Blame | `git blame f` | `jj file annotate f` |
| Push | `git push` | `jj git push --bookmark main` |
| Pull | `git pull` | `jj git fetch` (+ `jj bookmark set` if needed) |

### The three jj rules that trip up git users

1. **`jj` commands leave the git repo in "detached HEAD"** — that's
   *normal and fine*. Nix/flakes don't care (they read the index and
   files, not HEAD). `git status` will say "not on any branch" —
   ignore it while using jj.
2. **Bookmarks don't move themselves.** After `jj describe`, your
   change sits *ahead of* `main` until you `jj bookmark set main -r @-`.
   Forgetting = push shows "up to date" while your work stays local.
3. **Mixing mutating git commands into jj workflows** can create
   confusing bookmark conflicts. Safe pattern: **use jj for writing,
   git (or `gh`) only for reading and GitHub auth things.**

### Undo demo (worth 60 seconds on a scratch repo)

```bash
cd /tmp && mkdir jjdemo && cd jjdemo && jj git init --colocate .
echo a > f && jj st && jj describe -m "add f"
jj log                     # see it
jj abandon                 # oops, throw it away
jj log                     # gone!
jj undo                    # wait, I want it back
jj log                     # back again
jj op log                  # every step recorded
```

That safety net — *no command is irreversible* — is the real argument
for jj as a beginner. Git's `reset --hard` has no such mercy.

### Should you switch? (honest recommendation)

- **Keep this section as a playground**, not a requirement. Your git
  aliases, the workflow in §3, and everything in §4–6 keep working
  untouched — jj is additive.
- **Try jj for a week on the repo** (colocated mode is reversible:
  just delete `.jj/` to stop, nothing else changes).
- **Good jj fit for you:** forgetting `git add` before rebuilds (the
  auto-snapshot fixes exactly this), fear of destructive commands
  (`undo` everywhere), messy experiment cleanup.
- **Stay-with-git fit:** IDE integration, following tutorials written
  for git, muscle memory you build from this guide's §4.
- Either way, **learn §1–4 first** — jj *replaces* git's staging area
  and branches, but you still need to know what commits, remotes and
  push/pull *are*.

## 9. Recovery — Every Scenario, Worst to Best

You have **three** independent safety nets. Know which to reach for:

| Situation | Tool | Command |
|---|---|---|
| "One file is messed up, system still boots" | git file restore | `sudo git -C /etc/nixos checkout <sha> -- path/to/file.nix` then rebuild |
| "Config evaluates but new settings are bad" | generation rollback | `nix-rollback` (whole system, instant) |
| "System doesn't boot / login broken" | boot menu | reboot → pick previous generation in Lanzaboote menu |
| "Disk died / new machine" | GitHub clone | §10 |
| "I deleted a whole module and committed" | git revert | `sudo git -C /etc/nixos revert <sha>` |
| "I ran a git/jj command and regret it" | jj op log undo | `sudo jj undo` (or `jj op restore <id>`) — works on pushes too (§8) |

The ladder is independent: git rollback doesn't touch generations, generation rollback doesn't touch git. After any `nix-rollback`, also fix the *files* (git) so the next rebuild doesn't resurrect the problem.

## 10. Restoring on a New Machine (or after disk loss)

```bash
# 1. clone (anywhere; note SSH URL — needs YOUR user's key for this one:
#    run `gh auth login` as your user too on the new machine)
gh repo clone Hackcoon/nixos-config /etc/nixos   # (on a fresh install, may need sudo + tweak)

# 2. hardware-configuration.nix is MACHINE-SPECIFIC.
#    Never overwrite a new machine's generated one with the repo copy:
sudo nixos-generate-config --root /mnt   # when installing; keep ITS file

# 3. check the repo's copy in:
#    - flake.nix hostname if different
#    - modules/hardware/realtek-eee.nix (enp5s0 is THIS board's NIC name)
#    - modules/hardware/nvidia.nix (TU116 is THIS machine's GPU)

# 4. rebuild
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

This is the real payoff of the modular split: `hardware/` isolates exactly the machine-specific parts (§5 of the modular guide).

## 11. Optional Level-Ups (skip until curious)

**Show the git revision in system info** — makes generations traceable to commits. In flake.nix's `modules` list add:

```nix
{ system.configurationRevision = self.rev or self.dirtyRev or null; }
```

Then `nixos-rebuild list-generations` shows the commit hash instead of "Unknown", and `nixos-version --json` confirms it. (The `dirtyRev` fallback marks rebuilds with uncommitted changes — the git version of a warning label.)

**Tags for milestones**:

```bash
sudo git -C /etc/nixos tag -a v26.05-modular -m "first modular build"
sudo git -C /etc/nixos push --follow-tags
```

**CI build check on every push** — GitHub Actions can run `nix flake check` so you learn about breakage before you're at the machine. Worth it only once you have a second device or push from a laptop; ask me when you want it.

**Browsing on the phone:** the GitHub app / web UI is read-only for you — great for "what does my nvidia module look like" from the couch.

## 12. Your Aliases ↔ This Guide

Already wired in `modules/programs/shell.nix`:

| Alias | Does | Guide section |
|---|---|---|
| `config-status` | `git status` | §4 looking |
| `config-diff` | `git diff` | §4 looking |
| `config-log` | last 10 commits | §4 looking |
| `config-save` | `git add . && git commit` | §3 saving |

Not aliased (deliberately — the dangerous ones should be typed in full): `push`, `revert`, `reset`, `checkout`.

## 14. Secrets in Git Repos with sops-nix / age

Never commit plaintext secrets (§7). The NixOS-native pattern is **encrypted-in-repo, decrypted-at-activation**:

```bash
# 1. age key (per-machine, NEVER in the repo):
#   root key lives at /var/lib/sops-nix/key.txt (or ~/.config/sops/age/keys.txt for user)
#   public key = `age-keygen -y /var/lib/sops-nix/key.txt`

# 2. repo policy — /etc/nixos/.sops.yaml (COMMITTED, contains only public keys):
# creation_rules:
#   - path_regex: secrets/[^/]+\.yaml$
#     key_groups:
#       - age: [ "age1qlak...fury-desktop-pubkey..." ]

# 3. create an encrypted secret (COMMIT the .yaml, never the plaintext):
# sops secrets/wg-private.yaml   # type: plain text, sops encrypts on save

# 4. wire into NixOS (decrypted to /run/secrets/ at activation):
# { config, ... }: {
#   sops.defaultSopsFile = ./secrets/wg-private.yaml;
#   sops.secrets."wg-private".path = "/run/secrets/wg-private";  # .path for privateKeyFile etc.
# }
# networking.wg-quick.interfaces.wg0.privateKeyFile = config.sops.secrets."wg-private".path;
```

Rules:
- `.sops.yaml` + `secrets/*.yaml` (encrypted) ARE committed; `key.txt` NEVER is.
- agenix (`age.secrets`) is the equivalent alternative — same shape, `age.secrets."name".file = ./secrets/name.age;`.
- `environmentFiles = [ config.sops.secrets."hermes-env".path ]` for service env files (see ai-services.nix header).
- Rotate: `sops updatekeys secrets/*.yaml` after adding a new host key.
- Verify: `sops -d secrets/wg-private.yaml | head` decrypts locally; `/run/secrets/` is tmpfs (never hits disk).

## 15. Pre-commit Hooks + nixfmt / treefmt + CI

Format + evaluate on every commit/push so breakage never reaches the machine:

```nix
# flake.nix — pre-commit-hooks.nix input (COMMITTED lock):
# inputs.pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
# outputs = { pre-commit-hooks, ... }: {
#   checks.x86_64-linux.pre-commit = pre-commit-hooks.lib.x86_64-linux.run {
#     src = ./.;
#     hooks = {
#       nixfmt.enable = true;        # single-language formatter (your nix-format alias)
#       # treefmt.enable = true;     # multi-language (nix + md + sh) — pick ONE formatter stack
#       statix.enable = true;        # nix linter (optional)
#       deadnix.enable = true;       # unused bindings (optional)
#     };
#   };
# }
```

```bash
# install once per clone (root-owned repo → sudo):
# pre-commit install   # runs nixfmt/treefmt on `git commit`, blocks on dirty format
nix fmt                # manual: formats the whole tree (needs `formatter` flake output)
```

GitHub Actions CI — dry-build every push (catches eval errors before you're at the machine):

```yaml
# .github/workflows/check.yaml (COMMITTED):
# name: check
# on: [push, pull_request]
# jobs:
#   check:
#     runs-on: ubuntu-latest
#     steps:
#       - uses: actions/checkout@v4
#       - uses: cachix/install-nix-action@v27
#       - run: nix flake check --show-trace
#       - run: nix run nixpkgs#nixos-rebuild -- dry-build --flake .#nixos --show-trace
```

Cost note: CI runners are x86_64 Ubuntu — `dry-build` evaluates fully but builds only what cachix can't substitute; CUDA/custom kernels may OOM the free runner — `nix flake check` alone is the cheap 80%.

## 16. Signing Commits + Root/gh Auth + safe.directory / sudo / jj Notes

**Signing (ssh or gpg) — provesfurynix wrote it:**

```bash
# SSH signing (simplest — reuses your GitHub SSH key):
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub   # /root/.ssh/ for root's repo
git config --global commit.gpgsign true
# gh ssh-key add ~/.ssh/id_ed25519.pub --type signing   # register as SIGNING key too

# GPG alternative (if you already have a YubiKey/gpg setup):
# git config --global gpg.format openpgp
# git config --global user.signingkey <KEYID>
# git config --global commit.gpgsign true
# Verify: git log --show-signature -1
```

**gh ssh vs https for root (§6 deep-dive):**
- SSH (`git@github.com:...`) = key-based, no token expiry, correct for a root-owned push repo — what `sudo gh auth login` → SSH sets up.
- HTTPS (`https://github.com/...`) = token-based (`gh auth` stores in root's keyring); expires, prompts, breaks non-interactive `push` — avoid for `/etc/nixos`.
- Check: `sudo git -C /etc/nixos remote -v` must show `git@github.com:Hackcoon/...`, NOT `https://`. Fix: `sudo git -C /etc/nixos remote set-url origin git@github.com:Hackcoon/nixos-config.git`.

**safe.directory (why §4's warning exists):**
- Git refuses repos owned by another uid ("dubious ownership") — `/etc/nixos` is root-owned, you run as `fury`.
- Fix per-identity that RUNS git: `git config --global --add safe.directory /etc/nixos` (as fury) AND `sudo git config --global --add safe.directory /etc/nixos` (as root). Both — they have separate `--global` files.

**sudo -i vs -E (jj §8 rule restated):**
- `sudo -i` = fresh root login shell (root's `$HOME=/root`, root's jj/git config, root's SSH) — use for repo writes.
- `sudo -E` = preserve YOUR env (`$HOME=/home/fury` leaks into root's command — wrong jj identity, wrong SSH key). Use `-i` for `jj`/`gh`/commits; `-E` only for read-only inspection.

**jj 1.9+ config names (current — no `--user` flag):**
- `jj config set user.name "furynix"` + `jj config set user.email "..."` (repo-local: `jj config set --repo ...`).
- Bookmarks (not branches): `jj bookmark set main -r @-`, `jj git push --bookmark main`.
- Colocated: `jj git init --colocate .` once; `.jj/` is metadata (add `.jj/` to nothing — it's already ignored via `.jj/repo/store` internals, but never `git add .jj`).

## 17. Quick Reference Card (print this section)

```bash
# DAILY (git)
sudo git -C /etc/nixos add -A            # before EVERY rebuild (flakes!)
nix-test                                 # try it
sudo git -C /etc/nixos commit -m "area: why"
nix-switch                               # make permanent
sudo git -C /etc/nixos push              # backup to GitHub

# DAILY (jj — after §8 setup; no add needed!)
cd /etc/nixos && sudo jj st              # snapshot+index done automatically
nix-test
sudo jj describe -m "area: why"
nix-switch
sudo jj bookmark set main -r @- && sudo jj git push --bookmark main

# LOOK
config-status / config-diff / config-log     # git versions
jj st / jj diff / jj log                     # jj versions
git show <sha>
git log -p <file>

# BRANCH (risky experiments)
git checkout -b name → nix-test → merge OR abandon     # git way
jj new main -m "experiment" → nix-test → squash/abandon  # jj way
git checkout master                     # ALWAYS return before known-good rebuild

# UNDO
git restore <file>                       # uncommitted edits (git)
jj abandon / jj undo                     # anything, safely (jj)
git revert <sha>                         # committed, pushed (git)
nix-rollback                             # whole system
boot menu                                # system won't start

# NEVER
# ...commit a key/token
# ...git add a file you haven't looked at (git diff --staged first)
# ...push --force (until you understand why I said not to)
```
