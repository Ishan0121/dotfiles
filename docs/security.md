# Security Policy & Secret Hygiene

## Multi-Layer `.gitignore`

`/mnt/nexus/dotfiles/.gitignore` blocks sensitive and runtime-generated files across eight layers (evaluated top-to-bottom; negations at the bottom):

1. **SSH, GPG, PKI & Keyrings**: `.ssh/`, `.gnupg/`, `.pki/`, `keyrings/`, `nssdb/`, `id_*`, `*.pem`, `*.key`, `*.p12`, `*.gpg`, `*.kdbx`, etc.
2. **Secrets, Credentials & Tokens**: `.env`, `*.env`, `.env.*`, `secrets.*`, `**/noctalia/secrets.*`, `rclone.conf`, `.netrc`, `.git-credentials`, and catch-alls under `stow/` and `system/` (`*secret*`, `*credential*`, `*token*`).
3. **Browser Profiles, Cookies & IDE Runtime DBs**: `*.vscdb*`, `*.sqlite*`, `*.db*`, `Cookies*`, `globalStorage/`, `workspaceStorage/`, `History/`, `machineid`, `argv.json`, browser/IDE profile dirs.
4. **Shell Histories & Session Markers**: `.*_history`, `fish_history`, `.zcompdump*`, `.zsh_sessions/`.
5. **Caches, Logs & Backups**: `*.log`, `*.tmp`, `*.bak*`, `Cache/`, `CachedData/`, `GPUCache/`, `__pycache__/`, `.cache/`.
6. **Nested `.git` & External Clones**: `**/.git/`, `**/.git`, `.oh-my-zsh/`, `kitty-themes/`, `DankMaterialShell/`.
7. **Noctalia / Matugen Runtime Outputs & Machine-Specific Files**: `**/themes/noctalia*`, `**/matugen.*`, `dank-*.css`, `stow/umbriel/.config/umbriel/{noctalia.toml,outputs.toml}`, `stow/hypr/.config/hypr/{noctalia.lua,hyprtoolkit.conf}`, `stow/niri/.config/niri/noctalia.kdl`, `stow/zed/.config/zed/themes/noctalia.json`, etc.
8. **Explicit Example Allow-List**: `!*.example`, `!secrets.env.example`, `!outputs.toml.example`.

## Noctalia `secrets.env` Contract

- Tracked `stow/noctalia/.config/noctalia/config.toml` contains only placeholders:
  - `REPLACE_WITH_HOTSPOT_PASSWORD`
  - `REPLACE_WITH_WALLHAVEN_API_KEY`
- Tracked `stow/noctalia/.config/noctalia/secrets.env.example` documents `NOCTALIA_HOTSPOT_PASSWORD` and `NOCTALIA_WALLHAVEN_API_KEY`.
- Local `~/.config/noctalia/secrets.env` is gitignored.
- `scripts/stow-manage.sh` renders `~/.config/noctalia/config.toml` with mode `0600` using `secrets.env` (or preserves an existing `config.toml` unless `--force-noctalia-render` is passed).

## Automated Secret Scan (`scripts/check-secrets.sh`)

Run `./scripts/check-secrets.sh` before every commit or push. It scans `stow/` and `system/` and exits non-zero if any of the following are found:

1. Nested `.git` directories or files
2. Database files (`*.vscdb`, `*.db`, `*.sqlite`, `*.sqlite3`)
3. Private key headers (`-----BEGIN ... PRIVATE KEY-----`)
4. Known token/API key prefixes (`ghp_`, `github_pat_`, `sk-`, `AKIA`, `xox[baprs]-`)
5. Non-placeholder `password =`, `api_key =`, or `wallhaven_api_key =` assignments
6. Legacy hardcoded user home paths
7. Windows `C:\Users` paths

## Historical Archive Isolation

`/mnt/nexus/dotfiles-archive` is stored outside the Git repository with `0700` permissions (`drwx------`, owned by `lucifer:lucifer`), and its `noctalia/` subdirectory also has `0700` permissions. Never copy raw files from `/mnt/nexus/dotfiles-archive` into `stow/` without sanitizing secrets and paths first.

## Pre-Push Checklist

1. `./scripts/check-secrets.sh` passes with `0 findings`.
2. `git status` and `git diff --cached` show no untracked secrets, `.env` files, or Noctalia runtime-generated files.
3. No `system/etc/` edits or root-only credentials were staged inadvertently.
4. Any new template secrets use `REPLACE_WITH_*` placeholders and a corresponding `*.example` file.
