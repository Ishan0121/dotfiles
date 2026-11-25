# E2E Test Suite Readiness (`TEST_READY.md`)

**Status:** READY — All 4 test tiers executed and passed (`exit 0`).

## Executed Command

```bash
/mnt/nexus/dotfiles/tests/run_all.sh
```

## Observed Results

| Tier | Script | Outcome | Key Verifications Observed |
|------|--------|---------|----------------------------|
| **Tier 1** | `tests/test_tier1_static.sh` | **PASS** | `bash -n` and `shellcheck -x` passed on all 13 scripts (`scripts/*.sh`, `scripts/lib/*.sh`, `tests/*.sh`); `check-secrets.sh --root /mnt/nexus/dotfiles` exited `0`; negative synthetic `sk-*` token test in temp `stow/foo/bad.conf` failed non-zero as expected; `git check-ignore --no-index -q` confirmed secret/runtime paths ignored and `.example` / `scripts/check-secrets.sh` unignored. |
| **Tier 2** | `tests/test_tier2_backup_restore.sh` | **PASS** | Isolated `mktemp -d` `$TMP_HOME` and `$TMP_BACKUP`; backed up `.zshrc`, `.config/kitty/kitty.conf`, `.config/nvim/init.lua` with exact content match; `list` reported the backup directory; mutated/deleted target files were accurately restored via `backup-restore.sh restore`. |
| **Tier 3** | `tests/test_tier3_stow_lifecycle.sh` | **PASS** | `stow-manage.sh deploy --profile active` preserved `$TMP_HOME/.config/umbriel/outputs.toml` as a regular file (`--no-folding`) while symlinking `umbriel/config.toml`; excluded `hypr` and `niri` under `active`; rendered `$TMP_HOME/.config/noctalia/config.toml` with `0600` permissions and injected `test_pw` / `test_key` (repo template retained `REPLACE_WITH_*`); `status`, `restow`, and `undeploy --profile active` cleanly removed symlinks and preserved `outputs.toml` with zero broken symlinks; `deploy --profile all` and `undeploy --profile all` cleanly deployed and removed `hypr` and `niri`. |
| **Tier 4** | `tests/test_tier4_bootstrap_dryrun.sh` | **PASS** | `--help` exited `0` on `bootstrap.sh`, `install-packages.sh`, `setup-externals.sh`, and `check-deps.sh`; `check-deps.sh`, `install-packages.sh --dry-run` (`--distro arch` and `--distro fedora`), `setup-externals.sh --dry-run`, and `bootstrap.sh --dry-run` all exited `0` with zero mutations to isolated `$TMP_HOME` and `$TMP_BACKUP`. |

## Summary Output

```text
========================================
E2E Test Suite Summary
========================================
  PASS  test_tier1_static.sh
  PASS  test_tier2_backup_restore.sh
  PASS  test_tier3_stow_lifecycle.sh
  PASS  test_tier4_bootstrap_dryrun.sh
========================================
Result: ALL 4 TIERS PASSED
```
