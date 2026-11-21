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

# Missing option values must fail cleanly with exit code 2 (not bash unbound variable).
set +e
missing_out="$(bash "$ROOT/install.sh" --lark-user-id 2>&1)"
missing_rc=$?
set -e
test "$missing_rc" -eq 2
grep -Fq 'requires a value' <<<"$missing_out"

# Updating an existing rules block with backslash escapes must not fail re.sub.
HOME="$TMP_HOME" CODEX_HOME="$TMP_HOME/.codex" bash "$ROOT/install.sh" \
  --lark-user-id 'ou_\1literal' \
  --skill-root "$TMP_HOME/skills" \
  --agent-markdown-path "$TMP_HOME/AGENTS.md" \
  --skip-npm-install \
  --skip-bridge-install >/dev/null
grep -Fq -- '--as bot --user-id ou_\1literal' "$TMP_HOME/AGENTS.md"

# Dangling symlink and regular file at destination must be rejected cleanly.
mkdir -p "$TMP_HOME/bad-link-skills" "$TMP_HOME/bad-file-skills"
ln -s "$TMP_HOME/nonexistent-target" "$TMP_HOME/bad-link-skills/codex-lark-deliver"
set +e
link_out="$(HOME="$TMP_HOME" CODEX_HOME="$TMP_HOME/.codex" bash "$ROOT/install.sh" \
  --lark-user-id ou_selftest \
  --skill-root "$TMP_HOME/bad-link-skills" \
  --skip-agent-rules --skip-npm-install --skip-bridge-install 2>&1)"
link_rc=$?
set -e
test "$link_rc" -eq 1
grep -Fq 'Refusing to modify symlink' <<<"$link_out"
test -L "$TMP_HOME/bad-link-skills/codex-lark-deliver"

printf 'keep-me\n' > "$TMP_HOME/bad-file-skills/codex-lark-deliver"
set +e
file_out="$(HOME="$TMP_HOME" CODEX_HOME="$TMP_HOME/.codex" bash "$ROOT/install.sh" \
  --lark-user-id ou_selftest \
  --skill-root "$TMP_HOME/bad-file-skills" \
  --skip-agent-rules --skip-npm-install --skip-bridge-install 2>&1)"
file_rc=$?
set -e
test "$file_rc" -eq 1
grep -Fq 'Refusing to overwrite non-directory' <<<"$file_out"
grep -qxF 'keep-me' "$TMP_HOME/bad-file-skills/codex-lark-deliver"

# Duplicate default targets (CODEX_HOME == $HOME/.agents) must install once.
mkdir -p "$TMP_HOME/.agents/skills"
dedup_out="$(HOME="$TMP_HOME" CODEX_HOME="$TMP_HOME/.agents" bash "$ROOT/install.sh" \
  --lark-user-id ou_selftest \
  --skip-agent-rules --skip-npm-install --skip-bridge-install)"
test "$(grep -c '^Installed skill:' <<<"$dedup_out")" -eq 1

for script in \
  "$ROOT/install.ps1" \
  "$ROOT/skills/codex-lark-deliver/scripts/send_test_notice.ps1"; do
  if ! grep -Fq '$LASTEXITCODE' "$script"; then
    echo "Missing explicit native exit-code propagation in $script" >&2
    exit 1
  fi
done

grep -Fq 'FAKE_NATIVE_EXIT_CODE' "$ROOT/tests/selftest.ps1"

if [[ "$(tail -n 1 "$ROOT/tests/selftest.ps1")" != "exit 0" ]]; then
  echo "PowerShell self-test must end with an explicit successful exit" >&2
  exit 1
fi

if grep -R -- '--as user' \
  "$ROOT/install.sh" \
  "$ROOT/skills/codex-lark-deliver"; then
  echo "Found stale --as user delivery command" >&2
  exit 1
fi

echo "selftest=ok"
