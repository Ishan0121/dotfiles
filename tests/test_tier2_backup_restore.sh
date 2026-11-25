#!/usr/bin/env bash
# Tier 2: Isolated backup and restore lifecycle test.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_SCRIPT="${REPO_ROOT}/scripts/backup-restore.sh"
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

echo "=== Tier 2: Backup & Restore Lifecycle ==="

TMP_HOME="$(mktemp -d)"
TMP_BACKUP="$(mktemp -d)"
TMP_DIRS+=("$TMP_HOME" "$TMP_BACKUP")

# Pre-populate isolated $TMP_HOME with files that collide with stow/
mkdir -p "${TMP_HOME}/.config/kitty" "${TMP_HOME}/.config/nvim"
printf '# original zshrc\nexport TEST_VAR="original"\n' > "${TMP_HOME}/.zshrc"
printf '# original kitty.conf\nfont_size 11.0\n' > "${TMP_HOME}/.config/kitty/kitty.conf"
printf '%s\n' '-- original init.lua' 'vim.g.test_flag = true' > "${TMP_HOME}/.config/nvim/init.lua"

# 1. Run backup
"$BACKUP_SCRIPT" backup --target "$TMP_HOME" --backup-dir "$TMP_BACKUP" >/dev/null \
  || fail "backup-restore.sh backup failed"

backup_dir="$(find "$TMP_BACKUP" -mindepth 1 -maxdepth 1 -type d -name 'backup-*' | head -n 1)"
[[ -n "$backup_dir" && -d "$backup_dir" ]] || fail "No backup-* directory created in ${TMP_BACKUP}"
pass "Created backup directory: $(basename -- "$backup_dir")"

# 2. Verify backed-up files match originals
for rel in ".zshrc" ".config/kitty/kitty.conf" ".config/nvim/init.lua"; do
  [[ -f "${backup_dir}/${rel}" ]] || fail "Missing backed-up file: ${rel}"
  cmp -s "${TMP_HOME}/${rel}" "${backup_dir}/${rel}" || fail "Backup mismatch for: ${rel}"
done
pass "All backed-up files match original contents"

# Verify list action works
list_out="$("$BACKUP_SCRIPT" list --backup-dir "$TMP_BACKUP")"
printf '%s\n' "$list_out" | grep -qF "$backup_dir" || fail "backup-restore.sh list did not report ${backup_dir}"
pass "backup-restore.sh list reported backup directory"

# 3. Mutate and delete files in $TMP_HOME
printf '# mutated zshrc\n' > "${TMP_HOME}/.zshrc"
rm -f "${TMP_HOME}/.config/kitty/kitty.conf"
printf '%s\n' '-- mutated init.lua' > "${TMP_HOME}/.config/nvim/init.lua"

# 4. Run restore
"$BACKUP_SCRIPT" restore "$backup_dir" --target "$TMP_HOME" >/dev/null \
  || fail "backup-restore.sh restore failed"

# 5. Verify original contents are restored
for rel in ".zshrc" ".config/kitty/kitty.conf" ".config/nvim/init.lua"; do
  [[ -f "${TMP_HOME}/${rel}" ]] || fail "File not restored: ${rel}"
  cmp -s "${TMP_HOME}/${rel}" "${backup_dir}/${rel}" || fail "Restored file mismatch: ${rel}"
done
pass "Modified and deleted files restored accurately to ${TMP_HOME}"

echo "=== Tier 2 Complete ==="
