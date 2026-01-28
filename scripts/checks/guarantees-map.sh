#!/usr/bin/env bash
set -euo pipefail

PASS="PASS"
FAIL="FAIL"

say() { printf "%s\n" "$*"; }
ok()  { say "${PASS}: $*"; }
bad() { say "${FAIL}: $*" >&2; exit 1; }

# scripts/checks/guarantees-map.sh -> ../../ = repo root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

MAP_FILE="docs/guarantees-map.txt"
[[ -f "$MAP_FILE" ]] || bad "missing guarantees map: $MAP_FILE"

trim() {
  # trims leading/trailing whitespace + strips trailing CR
  local s="${1:-}"
  s="${s%$'\r'}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf "%s" "$s"
}

strip_bom() {
  local s="${1:-}"
  s="${s#$(printf '\357\273\277')}"
  printf "%s" "$s"
}

say "== Check: guarantees map format and references =="

line_no=0
seen_data=0

while IFS= read -r raw || [[ -n "$raw" ]]; do
  line_no=$((line_no + 1))

  raw="$(strip_bom "$raw")"
  raw_visible="$raw"
  line="$(trim "$raw")"

  # Skip empty lines
  [[ -z "$line" ]] && continue

  # Skip comments
  [[ "${line:0:1}" == "#" ]] && continue

  # Skip header row
  if [[ "$line" == GUARANTEE* ]]; then
    continue
  fi

  # Skip separator-like rows (e.g., ----|----)
  if [[ "$line" =~ ^[-[:space:]\|]+$ ]]; then
    continue
  fi

  # Must have at least 3 pipes to form 4 fields
  pipe_count="$(printf "%s" "$line" | tr -cd '|' | wc -c | tr -d ' ')"
  if [[ "$pipe_count" -lt 3 ]]; then
    bad "map line $line_no: invalid format (expected 4 fields separated by '|'): $raw_visible"
  fi

  IFS='|' read -r guarantee enforced_by proof_command notes <<<"$line" || true

  guarantee="$(trim "${guarantee:-}")"
  enforced_by="$(trim "${enforced_by:-}")"
  proof_command="$(trim "${proof_command:-}")"
  notes="$(trim "${notes:-}")"

  [[ -n "$guarantee" ]] || bad "map line $line_no: missing GUARANTEE field (first column empty): $raw_visible"
  [[ -n "$enforced_by" ]] || bad "map line $line_no: missing ENFORCED_BY field: $raw_visible"
  [[ -n "$proof_command" ]] || bad "map line $line_no: missing PROOF_COMMAND field: $raw_visible"
  [[ -n "$notes" ]] || bad "map line $line_no: missing NOTES field: $raw_visible"

  # ENFORCED_BY may list multiple paths separated by commas
  IFS=',' read -ra paths <<<"$enforced_by"
  for p in "${paths[@]}"; do
    p="$(trim "$p")"
    [[ -z "$p" ]] && continue

    if [[ "$p" == "Makefile" || "$p" == "make" ]]; then
      [[ -f "Makefile" ]] || bad "map line $line_no: Makefile not found"
    else
      [[ -e "$p" ]] || bad "map line $line_no: ENFORCED_BY path not found: $p"
    fi
  done

  ok "mapped: $guarantee"
  seen_data=1
done < "$MAP_FILE"

(( seen_data == 1 )) || bad "no guarantee entries found (map contains only header/comments)"

ok "guarantees map present and references exist"
exit 0
