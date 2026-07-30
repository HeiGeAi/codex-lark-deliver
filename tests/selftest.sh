#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT

bash -n "$ROOT/install.sh"

for _ in 1 2; do
  HOME="$TMP_HOME" CODEX_HOME="$TMP_HOME/.codex" bash "$ROOT/install.sh" \
    --lark-user-id ou_selftest \
    --skill-root "$TMP_HOME/skills" \
    --agent-markdown-path "$TMP_HOME/AGENTS.md" \
    --skip-npm-install \
    --skip-bridge-install >/dev/null
done

test "$(grep -c '<!-- BEGIN CODEX-LARK-DELIVER -->' "$TMP_HOME/AGENTS.md")" -eq 1
grep -q -- '--as bot --user-id ou_selftest' "$TMP_HOME/AGENTS.md"
test -s "$TMP_HOME/skills/codex-lark-deliver/SKILL.md"

for script in \
  "$ROOT/install.ps1" \
  "$ROOT/skills/codex-lark-deliver/scripts/send_test_notice.ps1"; do
  if ! grep -Fq '$LASTEXITCODE' "$script"; then
    echo "Missing explicit native exit-code propagation in $script" >&2
    exit 1
  fi
done

grep -Fq 'FAKE_NATIVE_EXIT_CODE' "$ROOT/tests/selftest.ps1"

if grep -R -- '--as user' \
  "$ROOT/install.sh" \
  "$ROOT/skills/codex-lark-deliver"; then
  echo "Found stale --as user delivery command" >&2
  exit 1
fi

echo "selftest=ok"
