#!/usr/bin/env bash
# Tier 3: Isolated Stow deploy, --no-folding, Noctalia secret rendering, status, restow, and undeploy.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
STOW_SCRIPT="${REPO_ROOT}/scripts/stow-manage.sh"
TMP_DIRS=()

cleanup() {
  local d
  for d in "${TMP_DIRS[@]}"; do
    [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
  done
}
trap cleanup EXIT

pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

echo "=== Tier 3: Stow Lifecycle & --no-folding ==="

TMP_HOME="$(mktemp -d)"
TMP_BACKUP="$(mktemp -d)"
TMP_DIRS+=("$TMP_HOME" "$TMP_BACKUP")

# Pre-populate runtime files in $TMP_HOME
mkdir -p "${TMP_HOME}/.config/umbriel" "${TMP_HOME}/.config/noctalia"
printf '# runtime outputs\noutput "DP-1" { mode "1920x1080" }\n' > "${TMP_HOME}/.config/umbriel/outputs.toml"
cat > "${TMP_HOME}/.config/noctalia/secrets.env" <<'EOF'
NOCTALIA_HOTSPOT_PASSWORD="test_pw"
NOCTALIA_WALLHAVEN_API_KEY="test_key"
EOF
chmod 0600 "${TMP_HOME}/.config/noctalia/secrets.env"

# 1. Deploy active profile
"$STOW_SCRIPT" deploy --profile active --target "$TMP_HOME" --backup-dir "$TMP_BACKUP" >/dev/null \
  || fail "stow-manage.sh deploy --profile active failed"
pass "stow-manage.sh deploy --profile active succeeded"

# 2. Verify --no-folding preserved outputs.toml as real file while config.toml is symlinked
[[ -f "${TMP_HOME}/.config/umbriel/outputs.toml" && ! -L "${TMP_HOME}/.config/umbriel/outputs.toml" ]] \
  || fail "outputs.toml was not preserved as a regular file"
grep -qF 'output "DP-1"' "${TMP_HOME}/.config/umbriel/outputs.toml" \
  || fail "outputs.toml content was altered"
[[ -L "${TMP_HOME}/.config/umbriel/config.toml" ]] \
  || fail "umbriel/config.toml was not deployed as a symlink"
pass "--no-folding preserved outputs.toml as real file and symlinked umbriel/config.toml"

# 3. Verify hypr and niri were NOT deployed under active profile
[[ ! -e "${TMP_HOME}/.config/hypr" ]] || fail "hypr should not be deployed under active profile"
[[ ! -e "${TMP_HOME}/.config/niri" ]] || fail "niri should not be deployed under active profile"
pass "Excluded optional packages (hypr, niri) under active profile"

# 4. Verify Noctalia config.toml rendered with 0600 and injected secrets, repo template untouched
noctalia_cfg="${TMP_HOME}/.config/noctalia/config.toml"
repo_noctalia_cfg="${REPO_ROOT}/stow/noctalia/.config/noctalia/config.toml"
[[ -f "$noctalia_cfg" && ! -L "$noctalia_cfg" ]] \
  || fail "Noctalia config.toml should be a rendered regular file, not a symlink"
perms="$(stat -c '%a' "$noctalia_cfg")"
[[ "$perms" == "600" ]] || fail "Expected Noctalia config.toml mode 600, got ${perms}"
grep -qF 'test_pw' "$noctalia_cfg" || fail "Noctalia config.toml missing injected test_pw"
grep -qF 'test_key' "$noctalia_cfg" || fail "Noctalia config.toml missing injected test_key"
if grep -qF 'REPLACE_WITH_' "$noctalia_cfg"; then
  fail "Rendered Noctalia config.toml still contains REPLACE_WITH_ placeholder"
fi
grep -qF 'REPLACE_WITH_' "$repo_noctalia_cfg" \
  || fail "Repo Noctalia template lost REPLACE_WITH_ placeholder"
pass "Noctalia config.toml rendered with 0600 permissions and secrets (repo template untouched)"

# 5. Run status and restow
"$STOW_SCRIPT" status --profile active --target "$TMP_HOME" >/dev/null \
  || fail "stow-manage.sh status failed"
"$STOW_SCRIPT" restow --profile active --target "$TMP_HOME" --backup-dir "$TMP_BACKUP" >/dev/null \
  || fail "stow-manage.sh restow failed"
pass "stow-manage.sh status and restow succeeded"

# 6. Undeploy active profile and verify clean removal + outputs.toml intact
"$STOW_SCRIPT" undeploy --profile active --target "$TMP_HOME" >/dev/null \
  || fail "stow-manage.sh undeploy --profile active failed"
[[ ! -e "${TMP_HOME}/.config/umbriel/config.toml" ]] \
  || fail "umbriel/config.toml symlink still exists after undeploy"
[[ ! -e "${TMP_HOME}/.zshrc" ]] \
  || fail ".zshrc symlink still exists after undeploy"
[[ -f "${TMP_HOME}/.config/umbriel/outputs.toml" && ! -L "${TMP_HOME}/.config/umbriel/outputs.toml" ]] \
  || fail "outputs.toml was lost or turned into symlink after undeploy"
broken_links="$(find "$TMP_HOME" -xtype l)"
[[ -z "$broken_links" ]] || fail "Found broken symlinks after undeploy: ${broken_links}"
pass "stow-manage.sh undeploy --profile active cleanly removed symlinks and preserved outputs.toml"

# 7. Deploy and undeploy --profile all (verifying hypr and niri)
"$STOW_SCRIPT" deploy --profile all --target "$TMP_HOME" --backup-dir "$TMP_BACKUP" >/dev/null \
  || fail "stow-manage.sh deploy --profile all failed"
[[ -L "${TMP_HOME}/.config/hypr/hyprland.lua" ]] \
  || fail "hypr/hyprland.lua was not symlinked under --profile all"
[[ -L "${TMP_HOME}/.config/niri/config.kdl" ]] \
  || fail "niri/config.kdl was not symlinked under --profile all"
pass "stow-manage.sh deploy --profile all deployed hypr and niri"

"$STOW_SCRIPT" undeploy --profile all --target "$TMP_HOME" >/dev/null \
  || fail "stow-manage.sh undeploy --profile all failed"
[[ ! -e "${TMP_HOME}/.config/hypr/hyprland.lua" ]] \
  || fail "hypr/hyprland.lua still exists after --profile all undeploy"
[[ ! -e "${TMP_HOME}/.config/niri/config.kdl" ]] \
  || fail "niri/config.kdl still exists after --profile all undeploy"
broken_links="$(find "$TMP_HOME" -xtype l)"
[[ -z "$broken_links" ]] || fail "Found broken symlinks after --profile all undeploy: ${broken_links}"
pass "stow-manage.sh undeploy --profile all cleanly removed all symlinks"

# 8. Test stow-manage.sh deploy --resolve-conflicts edge cases (dirs, symlinks, parent blocker, spaces, leading hyphens)
CONFLICT_HOME="$(mktemp -d)"
CONFLICT_BACKUP="$(mktemp -d)"
TMP_DIRS+=("$CONFLICT_HOME" "$CONFLICT_BACKUP")

# Regular files including spaces and leading-hyphen dirs
mkdir -p "${CONFLICT_HOME}/.config/Antigravity IDE/User"
printf '{"old": true}\n' > "${CONFLICT_HOME}/.config/Antigravity IDE/User/settings.json"
mkdir -p "${CONFLICT_HOME}/.config/Code/User/profiles/-65fabe60"
printf '{"old_profile": true}\n' > "${CONFLICT_HOME}/.config/Code/User/profiles/-65fabe60/settings.json"
# Non-directory parent blocking .config/foot/foot.ini
printf 'blocking file\n' > "${CONFLICT_HOME}/.config/foot"
# Colliding directory where Stow expects a file (.config/starship.toml)
mkdir -p "${CONFLICT_HOME}/.config/starship.toml"
printf 'nested\n' > "${CONFLICT_HOME}/.config/starship.toml/old.txt"
# Foreign symlink (.bashrc) and broken symlink (.profile)
ln -s /etc/hosts "${CONFLICT_HOME}/.bashrc"
ln -s /nonexistent/broken/target "${CONFLICT_HOME}/.profile"
# Existing Noctalia config.toml must be preserved even with --resolve-conflicts
mkdir -p "${CONFLICT_HOME}/.config/noctalia"
printf 'existing_noctalia = true\n' > "${CONFLICT_HOME}/.config/noctalia/config.toml"

"$STOW_SCRIPT" deploy --profile active --resolve-conflicts --target "$CONFLICT_HOME" --backup-dir "$CONFLICT_BACKUP" >/dev/null \
  || fail "stow-manage.sh deploy --resolve-conflicts failed"

for linked_rel in \
  ".config/Antigravity IDE/User/settings.json" \
  ".config/Code/User/profiles/-65fabe60/settings.json" \
  ".config/foot/foot.ini" \
  ".config/starship.toml" \
  ".bashrc" \
  ".profile"; do
  [[ -L "${CONFLICT_HOME}/${linked_rel}" && -e "${CONFLICT_HOME}/${linked_rel}" ]] \
    || fail "Expected valid Stow symlink after conflict resolution: ${linked_rel}"
done

[[ -f "${CONFLICT_HOME}/.config/noctalia/config.toml" && ! -L "${CONFLICT_HOME}/.config/noctalia/config.toml" ]] \
  || fail "Noctalia config.toml was not preserved as regular file"
grep -qF 'existing_noctalia = true' "${CONFLICT_HOME}/.config/noctalia/config.toml" \
  || fail "Noctalia config.toml content was overwritten"

c_backup_dir="$(find "$CONFLICT_BACKUP" -mindepth 1 -maxdepth 1 -type d -name 'backup-*' | head -n 1)"
[[ -n "$c_backup_dir" && -d "$c_backup_dir" ]] || fail "No backup directory created by --resolve-conflicts"
grep -qF '{"old": true}' "${c_backup_dir}/.config/Antigravity IDE/User/settings.json" \
  || fail "Backup missing space-path file"
grep -qF '{"old_profile": true}' "${c_backup_dir}/.config/Code/User/profiles/-65fabe60/settings.json" \
  || fail "Backup missing leading-hyphen path file"
grep -qF 'blocking file' "${c_backup_dir}/.config/foot" \
  || fail "Backup missing non-directory parent blocker"
[[ -f "${c_backup_dir}/.config/starship.toml/old.txt" ]] \
  || fail "Backup missing colliding directory contents"
[[ -L "${c_backup_dir}/.bashrc" && -L "${c_backup_dir}/.profile" ]] \
  || fail "Backup missing foreign/broken symlinks"

# Idempotency check: re-running deploy --resolve-conflicts reports 0 conflicts and creates no extra backup dir
re_out="$("$STOW_SCRIPT" deploy --profile active --resolve-conflicts --target "$CONFLICT_HOME" --backup-dir "$CONFLICT_BACKUP")"
printf '%s\n' "$re_out" | grep -qF '0 conflicts found' \
  || fail "Expected 0 conflicts on idempotent re-run; got: ${re_out}"
backup_count="$(find "$CONFLICT_BACKUP" -mindepth 1 -maxdepth 1 -type d -name 'backup-*' | wc -l)"
[[ "$backup_count" -eq 1 ]] || fail "Expected exactly 1 backup dir after idempotent re-run, got ${backup_count}"
pass "stow-manage.sh --resolve-conflicts handled spaces, hyphens, parent blockers, dirs, foreign symlinks, Noctalia preservation, and idempotency"

# 9. Regression (BUG-3 & BUG-4): absolute symlink into stow/ + symlink-to-directory parent collision
ABS_SYM_HOME="$(mktemp -d)"
ABS_SYM_BACKUP="$(mktemp -d)"
FOREIGN_KITTY_DIR="$(mktemp -d)"
TMP_DIRS+=("$ABS_SYM_HOME" "$ABS_SYM_BACKUP" "$FOREIGN_KITTY_DIR")

# Pre-deploy zsh with genuine Stow relative symlink (must be preserved untouched)
stow --no-folding -d "${REPO_ROOT}/stow" -t "$ABS_SYM_HOME" zsh
zshrc_inode_before="$(stat -c '%i' "${ABS_SYM_HOME}/.zshrc")"

# Absolute symlink pointing directly into stow/ (must be backed up and replaced)
mkdir -p "${ABS_SYM_HOME}/.config/foot"
ln -s "${REPO_ROOT}/stow/foot/.config/foot/foot.ini" "${ABS_SYM_HOME}/.config/foot/foot.ini"

# Symlink-to-directory parent (~/.config/kitty -> FOREIGN_KITTY_DIR with kitty.conf + extra.conf)
printf '# foreign kitty conf\n' > "${FOREIGN_KITTY_DIR}/kitty.conf"
printf '# extra user file\n' > "${FOREIGN_KITTY_DIR}/extra.conf"
ln -s "$FOREIGN_KITTY_DIR" "${ABS_SYM_HOME}/.config/kitty"

"$STOW_SCRIPT" deploy --profile active --resolve-conflicts --target "$ABS_SYM_HOME" --backup-dir "$ABS_SYM_BACKUP" >/dev/null \
  || fail "stow-manage.sh deploy --resolve-conflicts failed on absolute stow symlink / symlink-dir parent"

zshrc_inode_after="$(stat -c '%i' "${ABS_SYM_HOME}/.zshrc")"
[[ "$zshrc_inode_before" == "$zshrc_inode_after" ]] \
  || fail "Genuine relative Stow symlink .zshrc was unnecessarily replaced"

foot_link_target="$(readlink -- "${ABS_SYM_HOME}/.config/foot/foot.ini")"
[[ -L "${ABS_SYM_HOME}/.config/foot/foot.ini" && "$foot_link_target" != /* ]] \
  || fail "Absolute foot.ini symlink was not replaced with relative Stow symlink: ${foot_link_target}"

[[ -d "${ABS_SYM_HOME}/.config/kitty" && ! -L "${ABS_SYM_HOME}/.config/kitty" ]] \
  || fail "Expected real directory at .config/kitty after deploy"
[[ -L "${ABS_SYM_HOME}/.config/kitty/kitty.conf" && -e "${ABS_SYM_HOME}/.config/kitty/kitty.conf" ]] \
  || fail "Expected valid Stow symlink at .config/kitty/kitty.conf"
[[ -f "${FOREIGN_KITTY_DIR}/extra.conf" && -f "${FOREIGN_KITTY_DIR}/kitty.conf" ]] \
  || fail "Foreign kitty directory contents were unexpectedly modified"

abs_bdir="$(find "$ABS_SYM_BACKUP" -mindepth 1 -maxdepth 1 -type d -name 'backup-*' | head -n 1)"
[[ -n "$abs_bdir" && -d "$abs_bdir" ]] || fail "No backup directory created for BUG-3/BUG-4 regression test"
[[ -L "${abs_bdir}/.config/foot/foot.ini" ]] \
  || fail "Backup missing replaced absolute foot.ini symlink"
[[ ! -e "${abs_bdir}/.zshrc" && ! -L "${abs_bdir}/.zshrc" ]] \
  || fail "Genuine Stow symlink .zshrc was duplicated into backup"
[[ -L "${abs_bdir}/.config/kitty" ]] \
  || fail "Backup .config/kitty should be a symlink to foreign dir, not dereferenced"
[[ "$(readlink -- "${abs_bdir}/.config/kitty")" == "$FOREIGN_KITTY_DIR" ]] \
  || fail "Backup .config/kitty symlink target mismatch"
pass "stow-manage.sh --resolve-conflicts resolved absolute stow symlink & symlink-to-dir parent while preserving genuine Stow symlink"

echo "=== Tier 3 Complete ==="
