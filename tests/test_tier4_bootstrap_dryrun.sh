#!/usr/bin/env bash
# Tier 4: --help, --dry-run, R1 interactive/non-interactive PTY, and R2 conflict handling tests.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/scripts"
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

echo "=== Tier 4: Bootstrap, Interactive PTY & Conflict Handling Checks ==="

TMP_HOME="$(mktemp -d)"
TMP_BACKUP="$(mktemp -d)"
TMP_BIN="$(mktemp -d)"
TMP_DIRS+=("$TMP_HOME" "$TMP_BACKUP" "$TMP_BIN")

# 1. --help on all 7 CLI scripts and per-app setup scripts
for script in \
  bootstrap.sh \
  stow-manage.sh \
  install-packages.sh \
  backup-restore.sh \
  setup-externals.sh \
  check-deps.sh \
  check-secrets.sh \
  setup/zsh.sh \
  setup/git.sh \
  setup/nvim.sh \
  setup/vscode.sh \
  setup/antigravity.sh \
  setup/kitty.sh \
  setup/voxtype.sh \
  setup/noctalia-greeter.sh \
  setup/mpd.sh \
  setup/ydotool.sh \
  setup/desktop.sh \
  setup/docker.sh \
  setup/podman.sh \
  setup/rust.sh \
  setup/postgresql.sh \
  setup/virt.sh \
  setup/tailscale.sh \
  setup/ufw.sh \
  setup/bluetooth.sh \
  setup/snapper.sh \
  setup/paccache.sh; do
  "${SCRIPTS_DIR}/${script}" --help >/dev/null \
    || fail "${script} --help exited non-zero"
done
pass "--help succeeded on all core and setup scripts"

for setup_script in zsh.sh git.sh nvim.sh kitty.sh voxtype.sh mpd.sh desktop.sh; do
  "${SCRIPTS_DIR}/setup/${setup_script}" --dry-run --target "$TMP_HOME" >/dev/null \
    || fail "setup/${setup_script} --dry-run failed"
done
for setup_script in vscode.sh antigravity.sh noctalia-greeter.sh ydotool.sh docker.sh podman.sh rust.sh postgresql.sh virt.sh tailscale.sh ufw.sh bluetooth.sh snapper.sh paccache.sh; do
  "${SCRIPTS_DIR}/setup/${setup_script}" --dry-run >/dev/null \
    || fail "setup/${setup_script} --dry-run failed"
done
pass "All per-app setup scripts succeeded in --dry-run mode"

# 2. check-deps.sh execution
"${SCRIPTS_DIR}/check-deps.sh" >/dev/null \
  || fail "check-deps.sh failed"
pass "check-deps.sh succeeded"

# 3. install-packages.sh --dry-run (non-TTY stdout >/dev/null and stdin </dev/null)
"${SCRIPTS_DIR}/install-packages.sh" --dry-run --distro arch >/dev/null \
  || fail "install-packages.sh --dry-run --distro arch >/dev/null failed"
"${SCRIPTS_DIR}/install-packages.sh" --dry-run --distro arch </dev/null >/dev/null \
  || fail "install-packages.sh --dry-run --distro arch </dev/null failed"
"${SCRIPTS_DIR}/install-packages.sh" --dry-run --distro fedora >/dev/null \
  || fail "install-packages.sh --dry-run --distro fedora >/dev/null failed"
pass "install-packages.sh --dry-run non-TTY runs succeeded for arch and fedora"

# 4. setup-externals.sh --dry-run against isolated $TMP_HOME
"${SCRIPTS_DIR}/setup-externals.sh" --dry-run --target "$TMP_HOME" >/dev/null \
  || fail "setup-externals.sh --dry-run failed"
pass "setup-externals.sh --dry-run succeeded"

# 5. bootstrap.sh --dry-run against isolated $TMP_HOME and $TMP_BACKUP
"${SCRIPTS_DIR}/bootstrap.sh" --dry-run --target "$TMP_HOME" --backup-dir "$TMP_BACKUP" >/dev/null \
  || fail "bootstrap.sh --dry-run failed"
pass "bootstrap.sh --dry-run succeeded"

# 6. Verify zero mutations to $TMP_HOME and $TMP_BACKUP
home_entries="$(find "$TMP_HOME" -mindepth 1)"
backup_entries="$(find "$TMP_BACKUP" -mindepth 1)"
[[ -z "$home_entries" ]] || fail "Dry-run mutated TMP_HOME: ${home_entries}"
[[ -z "$backup_entries" ]] || fail "Dry-run mutated TMP_BACKUP: ${backup_entries}"
pass "Verified zero mutations to isolated TMP_HOME and TMP_BACKUP"

# 7. Build TMP_BIN excluding fzf, gum, dialog to deterministically test pure-Bash fallback
python3 - "$TMP_BIN" <<'PY'
import os, sys

tmp_bin = sys.argv[1]
excluded = {"fzf", "gum", "dialog"}
for src_dir in ("/usr/bin", "/bin"):
    if not os.path.isdir(src_dir):
        continue
    for name in os.listdir(src_dir):
        if name in excluded:
            continue
        dst = os.path.join(tmp_bin, name)
        if not os.path.lexists(dst):
            os.symlink(os.path.join(src_dir, name), dst)
PY

# 8. R1 PTY tests (explicit --yes/--non-interactive, pure-Bash fallback, and fzf if present)
python3 - "$SCRIPTS_DIR" "$TMP_BIN" "$TMP_HOME" "$TMP_BACKUP" <<'PY'
import os
import pty
import re
import select
import shutil
import signal
import sys
import tempfile
import time

scripts_dir, tmp_bin, tmp_home, tmp_backup = sys.argv[1:5]


def run_pty_seq(cmd, steps, env_overrides=None, cwd=None, timeout=15.0):
    """Run cmd in a PTY, advancing a search offset so repeated prompts match cleanly."""
    pid, fd = pty.fork()
    if pid == 0:
        if cwd:
            os.chdir(cwd)
        env = os.environ.copy()
        if env_overrides:
            env.update(env_overrides)
        os.execvpe(cmd[0], cmd, env)

    buf = b""
    search_from = 0
    step_idx = 0
    deadline = time.monotonic() + timeout
    try:
        while True:
            if step_idx < len(steps):
                wait_for, send_bytes, delay = steps[step_idx]
                text = buf.decode(errors="replace")
                if wait_for is None:
                    time.sleep(delay)
                    os.write(fd, send_bytes)
                    search_from = len(text)
                    step_idx += 1
                else:
                    pos = text.find(wait_for, search_from)
                    if pos != -1:
                        if delay:
                            time.sleep(delay)
                        os.write(fd, send_bytes)
                        search_from = pos + len(wait_for)
                        step_idx += 1

            remaining = deadline - time.monotonic()
            if remaining <= 0:
                os.kill(pid, signal.SIGKILL)
                os.waitpid(pid, 0)
                raise RuntimeError(
                    f"Timeout running {cmd} at step {step_idx}. Output:\n"
                    + buf.decode(errors="replace")[-1000:]
                )

            r, _, _ = select.select([fd], [], [], min(0.15, remaining))
            if r:
                try:
                    chunk = os.read(fd, 4096)
                    if not chunk:
                        break
                    buf += chunk
                except OSError:
                    break
            else:
                done_pid, status = os.waitpid(pid, os.WNOHANG)
                if done_pid == pid:
                    return os.waitstatus_to_exitcode(status), buf.decode(errors="replace")

        _, status = os.waitpid(pid, 0)
        return os.waitstatus_to_exitcode(status), buf.decode(errors="replace")
    finally:
        try:
            os.close(fd)
        except OSError:
            pass


bash_env = {"PATH": tmp_bin, "DOTFILES_PKG_SELECTOR": "auto", "TERM": "xterm-256color"}

# 8a. Explicit --yes and --non-interactive in PTY (must not prompt or hang)
for flag in ("--yes", "--non-interactive"):
    rc, out = run_pty_seq(
        [f"{scripts_dir}/install-packages.sh", "--dry-run", "--distro", "arch", flag],
        [],
        env_overrides=bash_env,
    )
    assert rc == 0, f"install-packages.sh {flag} failed ({rc}): {out}"
    assert "Selected (" not in out, f"{flag} unexpectedly prompted: {out}"
    assert "[DRY-RUN]" in out and "pacman" in out, f"Missing dry-run pacman output for {flag}: {out}"

rc, out = run_pty_seq(
    [
        f"{scripts_dir}/bootstrap.sh",
        "--dry-run",
        "--skip-externals",
        "--yes",
        "--target",
        tmp_home,
        "--backup-dir",
        tmp_backup,
    ],
    [],
    env_overrides=bash_env,
)
assert rc == 0, f"bootstrap.sh --yes failed ({rc}): {out}"
assert "Selected (" not in out, f"bootstrap.sh --yes unexpectedly prompted: {out}"
assert "Bootstrap complete!" in out, f"bootstrap.sh --yes did not complete: {out}"
print("[PASS] R1: --yes and --non-interactive bypassed prompts inside PTY")

# 8b. Pure-Bash fallback: toggle individual package (#1 antigravity-ide off) + confirm
rc, out = run_pty_seq(
    [f"{scripts_dir}/install-packages.sh", "--dry-run", "--distro", "arch", "--category", "aur"],
    [
        ("Selected (", b"1\n", 0.02),
        ("Selected (", b"c\n", 0.02),
    ],
    env_overrides=bash_env,
)
assert rc == 0, f"AUR toggle test failed ({rc}): {out}"
assert "Interactive mode (bash):" in out, f"Did not use pure-Bash fallback: {out}"
dry_lines = [ln for ln in out.splitlines() if "[DRY-RUN]" in ln]
assert len(dry_lines) == 1, f"Expected 1 DRY-RUN line, got {dry_lines}"
assert "antigravity-ide" not in dry_lines[0], f"Deselected pkg still in dry-run: {dry_lines[0]}"
assert "appimagelauncher" in dry_lines[0], f"Remaining AUR pkg missing in dry-run: {dry_lines[0]}"
print("[PASS] R1: Pure-Bash fallback toggled individual AUR package and printed only selected")

# 8c. Pure-Bash fallback: Deselect All (n) -> Select All (a) -> deselect #1 -> Enter confirm
rc, out = run_pty_seq(
    [f"{scripts_dir}/install-packages.sh", "--dry-run", "--distro", "arch", "--category", "fonts"],
    [
        ("Selected (", b"n\n", 0.02),
        ("Selected (0/", b"a\n", 0.02),
        ("Selected (", b"1\n", 0.02),
        ("Selected (", b"\n", 0.02),
    ],
    env_overrides=bash_env,
)
assert rc == 0, f"Fonts select-all/deselect test failed ({rc}): {out}"
dry_lines = [ln for ln in out.splitlines() if "[DRY-RUN]" in ln]
assert len(dry_lines) == 1, f"Expected 1 DRY-RUN line for fonts, got {dry_lines}"
assert "adobe-source-han-sans-otc-fonts" not in dry_lines[0], f"First font still present: {dry_lines[0]}"
assert "noto-fonts" in dry_lines[0], f"Selected font missing: {dry_lines[0]}"
print("[PASS] R1: Pure-Bash fallback handled Deselect All -> Select All -> toggle off -> Enter")

# 8d. Pure-Bash fallback: Deselect All + confirm WITHOUT --dry-run (clean skip, exit 0, no sudo/AUR)
rc, out = run_pty_seq(
    [f"{scripts_dir}/install-packages.sh", "--distro", "arch", "--category", "aur"],
    [
        ("Selected (", b"n\n", 0.02),
        ("Selected (0/", b"c\n", 0.02),
    ],
    env_overrides=bash_env,
)
assert rc == 0, f"Deselect All clean skip failed ({rc}): {out}"
assert "No packages selected; skipping package installation." in out, f"Missing skip message: {out}"
print("[PASS] R1: Deselect All exited 0 cleanly without invoking pacman/AUR/sudo")

# 8e. bootstrap.sh interactive PTY integration (--dry-run --skip-externals, without --skip-packages)
rc, out = run_pty_seq(
    [
        f"{scripts_dir}/bootstrap.sh",
        "--dry-run",
        "--skip-externals",
        "--target",
        tmp_home,
        "--backup-dir",
        tmp_backup,
    ],
    [
        ("Selected (", b"n\n", 0.02),
        ("Selected (0/", b"a\n", 0.02),
        ("Selected (", b"1\n", 0.02),
        ("Selected (", b"c\n", 0.02),
        ("Set up zsh (", b"y\n", 0.02),
        ("Set up desktop (", b"n\n", 0.02),
        ("Set up kitty (", b"q\n", 0.02),
    ],
    env_overrides=bash_env,
)
assert rc == 0, f"bootstrap.sh interactive PTY failed ({rc}): {out}"
assert "Interactive mode (bash):" in out, f"bootstrap.sh did not trigger pure-Bash selector: {out}"
assert "Zsh setup complete." in out, f"bootstrap.sh did not run confirmed zsh setup: {out}"
assert "Skipped desktop." in out, f"bootstrap.sh did not skip declined desktop setup: {out}"
assert "Stopped per-app setup prompts" in out, f"bootstrap.sh did not stop on 'q': {out}"
assert "Bootstrap complete!" in out, f"bootstrap.sh did not complete: {out}"
print("[PASS] R1: bootstrap.sh interactive PTY selection + per-app setup prompts + dry-run succeeded")

# 8f. Optional fzf selector Deselect All (Ctrl-D + Enter) if fzf is installed
if shutil.which("fzf"):
    fzf_env = os.environ.copy()
    fzf_env["DOTFILES_PKG_SELECTOR"] = "fzf"
    fzf_env["TERM"] = "xterm-256color"
    rc, out = run_pty_seq(
        [f"{scripts_dir}/install-packages.sh", "--distro", "arch", "--category", "aur"],
        [(None, b"\x04\r", 0.4)],
        env_overrides=fzf_env,
    )
    assert rc == 0, f"fzf Deselect All failed ({rc}): {out}"
    assert "No packages selected; skipping package installation." in out, (
        f"fzf Deselect All did not yield 0 selected: {out}"
    )
    print("[PASS] R1: fzf selector Deselect All (Ctrl-D + Enter) cleanly skipped with exit 0")

    # 8g. Regression (BUG-2): fzf selector with TMPDIR containing a space
    with tempfile.TemporaryDirectory() as td:
        tmp_space = os.path.join(td, "tmp with space")
        os.makedirs(tmp_space)
        fzf_space_env = fzf_env.copy()
        fzf_space_env["TMPDIR"] = tmp_space
        rc, out = run_pty_seq(
            [f"{scripts_dir}/install-packages.sh", "--distro", "arch", "--category", "aur"],
            [(None, b"\x04\r", 0.4)],
            env_overrides=fzf_space_env,
        )
        assert rc == 0, f"fzf TMPDIR-with-space failed ({rc}): {out}"
        assert "No packages selected; skipping package installation." in out, (
            f"fzf TMPDIR-with-space did not yield 0 selected: {out}"
        )
        assert os.listdir(tmp_space) == [], f"fzf leaked temp files in {tmp_space}: {os.listdir(tmp_space)}"
    print("[PASS] R1: fzf selector handled TMPDIR with spaces and cleaned up temp files")

# 8h. Regression (BUG-1): zero-padded indices (08, 09, 08-09) and '*' without CWD globbing
rc, out = run_pty_seq(
    [f"{scripts_dir}/install-packages.sh", "--dry-run", "--distro", "arch", "--category", "aur"],
    [
        ("Selected (", b"08\n", 0.02),
        ("Selected (", b"c\n", 0.02),
    ],
    env_overrides=bash_env,
)
assert rc == 0, f"Zero-padded 08 test failed ({rc}): {out}"
assert "value too great for base" not in out, f"Octal error on 08: {out}"
dry_lines = [ln for ln in out.splitlines() if "[DRY-RUN]" in ln]
assert len(dry_lines) == 1, f"Expected 1 DRY-RUN line on 08 toggle, got {dry_lines}"
assert "voxtype-bin" not in dry_lines[0], f"Package #8 (voxtype-bin) was not toggled off by 08: {dry_lines[0]}"
assert "win2xcur" in dry_lines[0], f"Package #9 (win2xcur) unexpectedly missing: {dry_lines[0]}"

rc, out = run_pty_seq(
    [f"{scripts_dir}/install-packages.sh", "--dry-run", "--distro", "arch", "--category", "aur"],
    [
        ("Selected (", b"08-09\n", 0.02),
        ("Selected (", b"09\n", 0.02),
        ("Selected (", b"c\n", 0.02),
    ],
    env_overrides=bash_env,
)
assert rc == 0, f"Zero-padded 08-09 / 09 test failed ({rc}): {out}"
assert "value too great for base" not in out, f"Octal error on 08-09/09: {out}"
dry_lines = [ln for ln in out.splitlines() if "[DRY-RUN]" in ln]
assert len(dry_lines) == 1, f"Expected 1 DRY-RUN line on 08-09/09 toggle, got {dry_lines}"
assert "voxtype-bin" not in dry_lines[0] and "win2xcur" in dry_lines[0], (
    f"08-09 then 09 did not leave #8 off and #9 on: {dry_lines[0]}"
)

with tempfile.TemporaryDirectory() as glob_cwd:
    open(os.path.join(glob_cwd, "eitype"), "w").close()
    open(os.path.join(glob_cwd, "extra_cwd_file"), "w").close()
    rc, out = run_pty_seq(
        [f"{scripts_dir}/install-packages.sh", "--dry-run", "--distro", "arch", "--category", "aur"],
        [
            ("Selected (", b"*\n", 0.02),
            ("Selected (", b"c\n", 0.02),
        ],
        env_overrides=bash_env,
        cwd=glob_cwd,
    )
    assert rc == 0, f"Wildcard '*' test failed ({rc}): {out}"
    assert "Unknown command or package: *" in out, f"Expected literal '*' warning, got: {out}"
    assert "extra_cwd_file" not in out, f"Wildcard '*' expanded CWD filenames: {out}"
    dry_lines = [ln for ln in out.splitlines() if "[DRY-RUN]" in ln]
    assert len(dry_lines) == 1 and "eitype" in dry_lines[0], (
        f"Wildcard '*' unexpectedly toggled eitype via CWD globbing: {dry_lines}"
    )
print("[PASS] R1: Pure-Bash fallback handled 08/09/08-09 without octal errors and '*' without CWD globbing")
PY

home_entries_after_pty="$(find "$TMP_HOME" -mindepth 1)"
backup_entries_after_pty="$(find "$TMP_BACKUP" -mindepth 1)"
[[ -z "$home_entries_after_pty" ]] || fail "Interactive bootstrap --dry-run mutated TMP_HOME: ${home_entries_after_pty}"
[[ -z "$backup_entries_after_pty" ]] || fail "Interactive bootstrap --dry-run mutated TMP_BACKUP: ${backup_entries_after_pty}"
pass "Verified zero mutations to TMP_HOME and TMP_BACKUP after interactive bootstrap --dry-run"

# 9. R2: Automatic Stow conflict handling in bootstrap.sh (with backup)
R2_HOME="$(mktemp -d)"
R2_BACKUP="$(mktemp -d)"
TMP_DIRS+=("$R2_HOME" "$R2_BACKUP")

mkdir -p "${R2_HOME}/.config/kitty"
printf '# pre-existing bashrc\n' > "${R2_HOME}/.bashrc"
printf '# pre-existing bash_profile\n' > "${R2_HOME}/.bash_profile"
printf '# pre-existing bash_logout\n' > "${R2_HOME}/.bash_logout"
printf '# pre-existing profile\n' > "${R2_HOME}/.profile"
printf '# pre-existing kitty\n' > "${R2_HOME}/.config/kitty/kitty.conf"
ln -s /nonexistent/foreign/zshrc "${R2_HOME}/.zshrc"

"${SCRIPTS_DIR}/bootstrap.sh" \
  --skip-packages \
  --skip-externals \
  --yes \
  --target "$R2_HOME" \
  --backup-dir "$R2_BACKUP" >/dev/null \
  || fail "bootstrap.sh R2 conflict resolution failed"

r2_backup_count="$(find "$R2_BACKUP" -mindepth 1 -maxdepth 1 -type d -name 'backup-*' | wc -l)"
[[ "$r2_backup_count" -eq 1 ]] || fail "Expected 1 unified backup dir in R2_BACKUP, got ${r2_backup_count}"
r2_bdir="$(find "$R2_BACKUP" -mindepth 1 -maxdepth 1 -type d -name 'backup-*' | head -n 1)"

grep -qF '# pre-existing bashrc' "${r2_bdir}/.bashrc" || fail "R2 backup missing .bashrc content"
grep -qF '# pre-existing kitty' "${r2_bdir}/.config/kitty/kitty.conf" || fail "R2 backup missing kitty.conf content"
[[ -L "${r2_bdir}/.zshrc" ]] || fail "R2 backup missing foreign symlink .zshrc"

for rel in ".bashrc" ".bash_profile" ".bash_logout" ".profile" ".config/kitty/kitty.conf" ".zshrc"; do
  [[ -L "${R2_HOME}/${rel}" && -e "${R2_HOME}/${rel}" ]] \
    || fail "Expected valid Stow symlink at ${R2_HOME}/${rel}"
done
[[ -f "${R2_HOME}/.config/noctalia/config.toml" && ! -L "${R2_HOME}/.config/noctalia/config.toml" ]] \
  || fail "Expected rendered Noctalia config.toml in R2_HOME"
pass "R2: bootstrap.sh backed up colliding files/symlinks and deployed Stow cleanly"

# 10. R2: Automatic Stow conflict handling with --no-backup
R2_NB_HOME="$(mktemp -d)"
R2_NB_BACKUP="$(mktemp -d)"
TMP_DIRS+=("$R2_NB_HOME" "$R2_NB_BACKUP")

printf '# nb bashrc\n' > "${R2_NB_HOME}/.bashrc"
printf '# nb bash_profile\n' > "${R2_NB_HOME}/.bash_profile"
printf '# nb bash_logout\n' > "${R2_NB_HOME}/.bash_logout"
printf '# nb profile\n' > "${R2_NB_HOME}/.profile"

"${SCRIPTS_DIR}/bootstrap.sh" \
  --skip-packages \
  --skip-externals \
  --no-backup \
  --yes \
  --target "$R2_NB_HOME" \
  --backup-dir "$R2_NB_BACKUP" >/dev/null \
  || fail "bootstrap.sh --no-backup conflict resolution failed"

for rel in ".bashrc" ".bash_profile" ".bash_logout" ".profile"; do
  [[ -L "${R2_NB_HOME}/${rel}" && -e "${R2_NB_HOME}/${rel}" ]] \
    || fail "Expected valid Stow symlink with --no-backup at ${R2_NB_HOME}/${rel}"
done
nb_entries="$(find "$R2_NB_BACKUP" -mindepth 1)"
[[ -z "$nb_entries" ]] || fail "--no-backup created unexpected files in backup dir: ${nb_entries}"
pass "R2: bootstrap.sh --no-backup resolved conflicts without writing backups"

# 11. R2: bootstrap.sh --dry-run with colliding files leaves target & backup untouched
R2_DRY_HOME="$(mktemp -d)"
R2_DRY_BACKUP="$(mktemp -d)"
TMP_DIRS+=("$R2_DRY_HOME" "$R2_DRY_BACKUP")

printf '# dry bashrc\n' > "${R2_DRY_HOME}/.bashrc"
printf '# dry bash_profile\n' > "${R2_DRY_HOME}/.bash_profile"
printf '# dry bash_logout\n' > "${R2_DRY_HOME}/.bash_logout"
printf '# dry profile\n' > "${R2_DRY_HOME}/.profile"
ln -s /nonexistent/foreign/zshrc "${R2_DRY_HOME}/.zshrc"

dry_conflict_out="$("${SCRIPTS_DIR}/bootstrap.sh" \
  --dry-run \
  --skip-packages \
  --skip-externals \
  --yes \
  --target "$R2_DRY_HOME" \
  --backup-dir "$R2_DRY_BACKUP" 2>&1)" \
  || fail "bootstrap.sh --dry-run with conflicts failed"

[[ "$dry_conflict_out" == *"[DRY-RUN]"* ]] \
  || fail "Expected [DRY-RUN] messages during conflict preview"
[[ "$dry_conflict_out" == *"Stow conflict"* ]] \
  || fail "Expected Stow conflict messages during conflict preview"

for rel in ".bashrc" ".bash_profile" ".bash_logout" ".profile"; do
  [[ -f "${R2_DRY_HOME}/${rel}" && ! -L "${R2_DRY_HOME}/${rel}" ]] \
    || fail "--dry-run altered regular file ${rel}"
done
grep -qF '# dry bashrc' "${R2_DRY_HOME}/.bashrc" || fail "--dry-run altered .bashrc contents"
[[ -L "${R2_DRY_HOME}/.zshrc" ]] || fail "--dry-run removed .zshrc symlink"
[[ "$(readlink -- "${R2_DRY_HOME}/.zshrc")" == "/nonexistent/foreign/zshrc" ]] \
  || fail "--dry-run altered .zshrc symlink target"
dry_b_entries="$(find "$R2_DRY_BACKUP" -mindepth 1)"
[[ -z "$dry_b_entries" ]] || fail "--dry-run created files in R2_DRY_BACKUP: ${dry_b_entries}"
pass "R2: bootstrap.sh --dry-run reported planned conflict actions with zero mutations"

# 12. R2 Regression (BUG-3 & BUG-4): absolute symlink into stow/ and symlink-to-directory parent
R2_ADV_HOME="$(mktemp -d)"
R2_ADV_BACKUP="$(mktemp -d)"
R2_FOREIGN_KITTY="$(mktemp -d)"
TMP_DIRS+=("$R2_ADV_HOME" "$R2_ADV_BACKUP" "$R2_FOREIGN_KITTY")

# Absolute symlink pointing into stow/ (must be backed up and replaced by Stow's canonical relative symlink)
mkdir -p "${R2_ADV_HOME}/.config/foot"
ln -s "${REPO_ROOT}/stow/foot/.config/foot/foot.ini" "${R2_ADV_HOME}/.config/foot/foot.ini"

# Symlink-to-directory parent (~/.config/kitty -> foreign_dir with kitty.conf + extra.conf)
printf '# foreign kitty.conf\n' > "${R2_FOREIGN_KITTY}/kitty.conf"
printf '# extra user file\n' > "${R2_FOREIGN_KITTY}/extra.conf"
ln -s "$R2_FOREIGN_KITTY" "${R2_ADV_HOME}/.config/kitty"

"${SCRIPTS_DIR}/bootstrap.sh" \
  --skip-packages \
  --skip-externals \
  --yes \
  --target "$R2_ADV_HOME" \
  --backup-dir "$R2_ADV_BACKUP" >/dev/null \
  || fail "bootstrap.sh R2 failed on absolute stow symlink / symlink-to-directory parent"

adv_foot_target="$(readlink -- "${R2_ADV_HOME}/.config/foot/foot.ini")"
[[ -L "${R2_ADV_HOME}/.config/foot/foot.ini" && "$adv_foot_target" != /* ]] \
  || fail "R2 absolute foot.ini symlink was not replaced with relative Stow symlink: ${adv_foot_target}"
[[ -d "${R2_ADV_HOME}/.config/kitty" && ! -L "${R2_ADV_HOME}/.config/kitty" ]] \
  || fail "R2 .config/kitty is not a real directory after Stow deploy"
[[ -L "${R2_ADV_HOME}/.config/kitty/kitty.conf" && -e "${R2_ADV_HOME}/.config/kitty/kitty.conf" ]] \
  || fail "R2 .config/kitty/kitty.conf symlink missing after deploy"
[[ -f "${R2_FOREIGN_KITTY}/extra.conf" && -f "${R2_FOREIGN_KITTY}/kitty.conf" ]] \
  || fail "R2 foreign kitty dir lost files"

adv_bdir="$(find "$R2_ADV_BACKUP" -mindepth 1 -maxdepth 1 -type d -name 'backup-*' | head -n 1)"
[[ -n "$adv_bdir" && -d "$adv_bdir" ]] || fail "R2 BUG-3/BUG-4 backup dir missing"
[[ -L "${adv_bdir}/.config/foot/foot.ini" ]] \
  || fail "R2 backup missing replaced absolute foot.ini symlink"
[[ -L "${adv_bdir}/.config/kitty" ]] \
  || fail "R2 backup .config/kitty must be preserved as a symlink to foreign dir"
[[ "$(readlink -- "${adv_bdir}/.config/kitty")" == "$R2_FOREIGN_KITTY" ]] \
  || fail "R2 backup .config/kitty symlink target mismatch"
pass "R2: bootstrap.sh resolved absolute stow symlink and preserved symlink-to-directory parent in backup"

# 13. Regression: install-packages.sh filters missing pacman repo packages cleanly
MOCK_ROOT="$(mktemp -d)"
MOCK_BIN="$(mktemp -d)"
MOCK_LOG_DIR="$(mktemp -d)"
TMP_DIRS+=("$MOCK_ROOT" "$MOCK_BIN" "$MOCK_LOG_DIR")
MOCK_LOG="${MOCK_LOG_DIR}/calls.log"

mkdir -p "${MOCK_ROOT}/packages"
printf 'valid-repo-pkg\naur-only-pkg\nmissing-pkg\n' > "${MOCK_ROOT}/packages/common.txt"
printf 'explicit-aur-pkg\nmissing-aur-pkg\n' > "${MOCK_ROOT}/packages/aur.txt"
for empty_cat in arch development desktop fonts; do
  : > "${MOCK_ROOT}/packages/${empty_cat}.txt"
done

cat > "${MOCK_BIN}/pacman" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -Ssq)
    printf 'valid-repo-pkg\n'
    ;;
  -Sg)
    ;;
  -Sp|-Qq)
    exit 1
    ;;
  -S)
    printf 'PACMAN:%s\n' "$*" >> "${MOCK_LOG}"
    ;;
esac
EOF

cat > "${MOCK_BIN}/paru" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -Sia)
    if [[ "${3:-}" == "aur-only-pkg" ]]; then
      exit 0
    fi
    exit 1
    ;;
  -Si)
    shift
    [[ "${1:-}" == "--" ]] && shift
    rc=0
    for p in "$@"; do
      case "$p" in
        explicit-aur-pkg|aur-only-pkg) ;;
        *)
          printf "error: package '%s' was not found\n" "$p" >&2
          rc=1
          ;;
      esac
    done
    exit "$rc"
    ;;
  -S)
    printf 'PARU:%s\n' "$*" >> "${MOCK_LOG}"
    ;;
esac
EOF

cat > "${MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF

chmod +x "${MOCK_BIN}/pacman" "${MOCK_BIN}/paru" "${MOCK_BIN}/sudo"

filter_out="$(
  DOTFILES_ROOT="$MOCK_ROOT" \
  MOCK_LOG="$MOCK_LOG" \
  PATH="${MOCK_BIN}:${TMP_BIN}" \
  "${SCRIPTS_DIR}/install-packages.sh" --distro arch --yes 2>&1
)" || fail "install-packages.sh failed when filtering unavailable pacman packages: ${filter_out}"

grep -qF "PACMAN:-S --needed --noconfirm valid-repo-pkg" "$MOCK_LOG" \
  || fail "Expected valid-repo-pkg in pacman -S call; got: $(cat "$MOCK_LOG")"
grep -qF "PARU:-S --needed --noconfirm explicit-aur-pkg aur-only-pkg" "$MOCK_LOG" \
  || fail "Expected aur-only-pkg routed to paru; got: $(cat "$MOCK_LOG")"
if grep -qF "missing-pkg" "$MOCK_LOG"; then
  fail "Unavailable missing-pkg should have been skipped, not installed: $(cat "$MOCK_LOG")"
fi
if grep -qF "missing-aur-pkg" "$MOCK_LOG"; then
  fail "Unavailable missing-aur-pkg should have been skipped, not installed: $(cat "$MOCK_LOG")"
fi
[[ "$filter_out" == *"not found in pacman repos; queuing for paru"* ]] \
  || fail "Expected AUR fallback warning in output: ${filter_out}"
[[ "$filter_out" == *"not found in pacman repos or AUR; skipping"* ]] \
  || fail "Expected unavailable package skip warning in output: ${filter_out}"
[[ "$filter_out" == *"not found in paru repos or AUR; skipping"* ]] \
  || fail "Expected unavailable AUR package skip warning in output: ${filter_out}"
pass "install-packages.sh filtered missing repo/AUR packages, routed AUR fallbacks, and skipped unavailable packages"

echo "=== Tier 4 Complete ==="
