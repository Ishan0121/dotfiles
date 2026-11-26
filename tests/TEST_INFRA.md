# E2E Test Infrastructure (`tests/`)

This directory contains an opaque-box, non-destructive end-to-end (E2E) test suite for `/mnt/nexus/dotfiles`.

## Isolation Guarantees

1. **Isolated `$HOME`, Backup, and `PATH` Targets**: Every test that performs file operations, Stow deployment, backup/restore, PTY selection, or dry-run orchestration creates disposable temporary directories via `mktemp -d` (`TMP_HOME`, `TMP_BACKUP`, `TMP_REPO`, `TMP_BIN`).
2. **Automatic Cleanup**: Every test script registers an `EXIT` `trap` handler (`trap cleanup EXIT`) that removes all temporary directories created during the run, whether the test passes or fails.
3. **Zero Mutation of Live State**:
   - The real `$HOME` is never passed as `--target`.
   - The real `/mnt/nexus/dotfiles-backups` is never passed as `--backup-dir`.
   - `/mnt/nexus/dotfiles/stow` is treated as read-only; negative secret-scanning tests operate on a temporary directory created via `mktemp -d`.

## Test Tiers

| Tier | Script | Scope |
|------|--------|-------|
| **Tier 1: Static, Security & README Parity** | `tests/test_tier1_static.sh` | `bash -n` syntax checks and `shellcheck -x` linting on `scripts/*.sh`, `scripts/lib/*.sh`, and `tests/*.sh`; `check-secrets.sh --root /mnt/nexus/dotfiles` (exit 0); negative synthetic secret test (`sk-...` token in temp `stow/foo/bad.conf` must fail); `git check-ignore --no-index -q` spot checks; automated `README.md` vs `--help` flag parity across all 7 scripts under `scripts/` and `stow/antigravity` row verification. |
| **Tier 2: Backup & Restore** | `tests/test_tier2_backup_restore.sh` | Isolated `$TMP_HOME` and `$TMP_BACKUP` with pre-existing `.zshrc`, `.config/kitty/kitty.conf`, and `.config/nvim/init.lua`; runs `backup-restore.sh backup` (non-destructive copy), verifies backup contents match originals, verifies `list`, mutates/deletes files in `$TMP_HOME`, runs `backup-restore.sh restore`, and verifies exact restoration. |
| **Tier 3: Stow Lifecycle & Conflict Resolution** | `tests/test_tier3_stow_lifecycle.sh` | Isolated `$TMP_HOME` with pre-existing `.config/umbriel/outputs.toml` and `.config/noctalia/secrets.env`; deploys `--profile active`, verifies `--no-folding` preserves `outputs.toml` as a regular file while `config.toml` is a symlink, verifies `hypr`/`niri` are excluded under `active`, verifies Noctalia `config.toml` is rendered with `0600` permissions and injected secrets (while repo template retains `REPLACE_WITH_*`), tests `status`, `restow`, `undeploy`, and `deploy`/`undeploy` with `--profile all`; also tests `stow-manage.sh deploy --resolve-conflicts` against spaces (`Antigravity IDE`), leading hyphens (`-65fabe60`), non-directory parent blockers, colliding directories, foreign/broken symlinks, Noctalia `config.toml` preservation, and idempotency. |
| **Tier 4: Bootstrap, Interactive PTY & Conflict Handling** | `tests/test_tier4_bootstrap_dryrun.sh` | Tests `--help` on all 7 CLI scripts, `check-deps.sh`, non-TTY `install-packages.sh --dry-run` (`arch`/`fedora`), `setup-externals.sh --dry-run`, `bootstrap.sh --dry-run` with zero mutations; real `python3` PTY tests for `--yes`/`--non-interactive`, pure-Bash fallback (`TMP_BIN` excluding `fzf`/`gum`/`dialog`) covering individual toggle, Select All, Deselect All (clean exit 0 without `sudo`/`pacman`/AUR), interactive `bootstrap.sh --dry-run`, and `fzf` Deselect All (`Ctrl-D` + `Enter`); plus `bootstrap.sh` R2 conflict handling (with backup, `--no-backup`, and non-destructive `--dry-run`). |

## Running the Suite

Run all tiers in sequence:

```bash
/mnt/nexus/dotfiles/tests/run_all.sh
```

Or run an individual tier:

```bash
/mnt/nexus/dotfiles/tests/test_tier1_static.sh
/mnt/nexus/dotfiles/tests/test_tier2_backup_restore.sh
/mnt/nexus/dotfiles/tests/test_tier3_stow_lifecycle.sh
/mnt/nexus/dotfiles/tests/test_tier4_bootstrap_dryrun.sh
```
