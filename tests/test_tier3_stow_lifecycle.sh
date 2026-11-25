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

echo "=== Tier 3 Complete ==="
