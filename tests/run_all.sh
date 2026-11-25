#!/usr/bin/env bash
# Run all E2E test tiers (Tiers 1-4) and print a PASS/FAIL summary.

set -euo pipefail

TESTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

TIERS=(
  "test_tier1_static.sh"
  "test_tier2_backup_restore.sh"
  "test_tier3_stow_lifecycle.sh"
  "test_tier4_bootstrap_dryrun.sh"
)

RESULTS=()
FAILED=0

for tier in "${TIERS[@]}"; do
  printf '\n>>> Running %s <<<\n' "$tier"
  if "${TESTS_DIR}/${tier}"; then
    RESULTS+=("PASS  ${tier}")
  else
    RESULTS+=("FAIL  ${tier}")
    FAILED=$((FAILED + 1))
  fi
done

printf '\n========================================\n'
printf 'E2E Test Suite Summary\n'
printf '========================================\n'
for line in "${RESULTS[@]}"; do
  printf '  %s\n' "$line"
done
printf '========================================\n'

if [[ "$FAILED" -ne 0 ]]; then
  printf 'Result: FAILED (%d tier(s) failed)\n' "$FAILED" >&2
  exit 1
fi

printf 'Result: ALL %d TIERS PASSED\n' "${#TIERS[@]}"
