#!/usr/bin/env bash
set -euo pipefail

# Pinned dependency versions (supply-chain safety). Bump deliberately, then verify.
LARK_CLI_PACKAGE="@larksuite/cli@1.0.95"
BRIDGE_PACKAGE="lark-channel-bridge@0.7.1"

LARK_USER_ID="YOUR_LARK_OPEN_ID"
AGENT_MARKDOWN_PATH=""
SKILL_ROOT=""
SKIP_NPM_INSTALL=0
SKIP_BRIDGE_INSTALL=0
SKIP_AGENT_RULES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lark-user-id)
      LARK_USER_ID="$2"
      shift 2
      ;;
    --agent-markdown-path)
      AGENT_MARKDOWN_PATH="$2"
      shift 2
      ;;
    --skill-root)
      SKILL_ROOT="$2"
      shift 2
      ;;
    --skip-npm-install)
      SKIP_NPM_INSTALL=1
      shift
      ;;
    --skip-bridge-install)
      SKIP_BRIDGE_INSTALL=1
      shift
      ;;
    --skip-agent-rules)
      SKIP_AGENT_RULES=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SOURCE="$REPO_ROOT/skills/codex-lark-deliver"

if [[ ! -d "$SKILL_SOURCE" ]]; then
  echo "Skill source not found: $SKILL_SOURCE" >&2
  exit 1
fi

if [[ "$SKIP_NPM_INSTALL" -eq 0 || "$SKIP_BRIDGE_INSTALL" -eq 0 ]]; then
  if ! command -v npm >/dev/null 2>&1; then
    echo "npm was not found. Install Node.js first, then re-run this script." >&2
    exit 1
  fi
fi

if [[ "$SKIP_NPM_INSTALL" -eq 0 ]]; then
  npm install -g "$LARK_CLI_PACKAGE"
fi

if [[ "$SKIP_BRIDGE_INSTALL" -eq 0 ]]; then
  npm install -g "$BRIDGE_PACKAGE"
fi

targets=()
if [[ -n "$SKILL_ROOT" ]]; then
  targets+=("$SKILL_ROOT")
else
  CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
  targets+=("$CODEX_HOME_DIR/skills")
  if [[ -d "$HOME/.agents/skills" ]]; then
    targets+=("$HOME/.agents/skills")
  fi
fi

for target_root in "${targets[@]}"; do
  mkdir -p "$target_root"
  resolved_root="$(cd "$target_root" && pwd -P)"
  destination="$resolved_root/codex-lark-deliver"
  if [[ -e "$destination" || -L "$destination" ]]; then
    resolved_destination="$(cd "$destination" && pwd -P)"
    case "$resolved_destination" in
      "$resolved_root"/codex-lark-deliver) ;;
      *)
        echo "Refusing to modify path outside target root: $resolved_destination" >&2
        exit 1
        ;;
    esac
  fi
  rm -rf "$destination"
  cp -R "$SKILL_SOURCE" "$destination"
  echo "Installed skill: $destination"
done

if [[ "$SKIP_AGENT_RULES" -eq 0 ]]; then
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
  elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
  else
    echo "Python was not found; cannot update agent markdown automatically." >&2
    exit 1
  fi

  "$PYTHON_BIN" - "$LARK_USER_ID" "$AGENT_MARKDOWN_PATH" <<'PY'
import os
import re
import sys
from pathlib import Path

lark_user_id = sys.argv[1]
agent_markdown_path = sys.argv[2]

if agent_markdown_path:
    target = Path(agent_markdown_path).expanduser()
else:
    codex_home = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))).expanduser()
    candidates = [
        codex_home / "AGENTS.md",
        codex_home / "agents.markdown",
        codex_home / "AGENTS.markdown",
    ]
    target = next((path for path in candidates if path.exists()), codex_home / "AGENTS.md")

target.parent.mkdir(parents=True, exist_ok=True)

template = """<!-- BEGIN CODEX-LARK-DELIVER -->
## Feishu/Lark Completion Notice and File Delivery

These rules apply to every Codex task on this machine, including normal chat tasks, background work, and recurring automations.

### Completion Notice

- After completing any user task, send a Feishu/Lark direct message to the current user as a completion notice.
- Send the notice only to the user's own open_id unless the user explicitly names another recipient or group.
- Recipient open_id: `{{LARK_USER_ID}}`.
- Prefer this command shape:
  `lark-cli im +messages-send --as bot --user-id {{LARK_USER_ID}} --markdown "<message>"`
- The notice must briefly include:
  - task name or subject;
  - completion status;
  - links to real deliverables, Feishu cloud docs, uploaded files, or important local paths when relevant;
  - major blockers, source-access boundaries, or exact errors if something could not be completed;
  - the next action only when one is genuinely needed.
- Verify that the send returned a `message_id` when possible. If the notice fails, report the exact failure boundary in the final response.
- Do not recursively send a second completion notice only because the Feishu/Lark notification itself was sent.

### Real File Body Delivery

- If a task involves any file, deliver the file body to the user in Feishu/Lark, not merely a summary or link.
- File-like deliverables include Feishu/Lark cloud docs, PDFs, PowerPoint decks, Excel/CSV spreadsheets, Markdown files, Word docs, images, audio/video files, HTML files, web pages, source files, archives, generated reports, and any other artifact created, edited, analyzed, or relied on as an output.
- For local files, verify the file exists and is non-empty, then send the actual file artifact with Lark CLI when supported.
- For Feishu/Lark cloud docs, create or update the cloud doc in a user-visible location, verify it is fetchable, include the real cloud-document URL, and also send the document body or exported file when available.
- For URLs and web pages that are deliverables, send the URL and also deliver a concrete file body such as an HTML snapshot, PDF export, Markdown capture, or another faithful representation unless the user explicitly asks for a link-only handoff.
- The completion notice must include file-body delivery evidence: message id, uploaded-file reference, cloud-doc URL plus exported/sent file when applicable, or the exact failure boundary.
- If a file body cannot be created, exported, uploaded, sent, or verified, mark that part as failed or partial and include the exact error. Do not substitute a text-only answer or link-only answer unless the user explicitly accepts that fallback.

### Automation Discipline

- Recurring automations must follow the same completion-notice and file-body delivery rules as interactive tasks.
- When an automation has no worthwhile content to deliver, it should still send a concise Feishu/Lark status message if its task contract requires notification.
- When an automation creates a Feishu/Lark doc, the run is not complete until the doc is visible or fetchable, the notification includes the real clickable cloud-doc URL, and the file body or exported body has been sent whenever available tools allow it.
<!-- END CODEX-LARK-DELIVER -->"""

block = template.replace("{{LARK_USER_ID}}", lark_user_id)
marker = re.compile(r"<!-- BEGIN CODEX-LARK-DELIVER -->.*?<!-- END CODEX-LARK-DELIVER -->", re.S)
current = target.read_text(encoding="utf-8") if target.exists() else "# Global Codex Agent Rules\n"
if marker.search(current):
    updated = marker.sub(block, current, count=1)
else:
    updated = current.rstrip() + "\n\n" + block + "\n"
target.write_text(updated, encoding="utf-8")
print(f"Updated agent markdown: {target}")
if lark_user_id == "YOUR_LARK_OPEN_ID":
    print("WARNING: The rules were written with a placeholder open_id. Re-run with --lark-user-id once you know the recipient open_id.", file=sys.stderr)
PY
fi

echo
echo "Next verification steps:"
echo "1. Run: lark-cli auth status"
echo "2. If needed, run: lark-cli auth login"
echo "3. Pair Zara's bridge: lark-channel-bridge run"
echo "4. Restart Codex so the installed skill and agent markdown rules are loaded."
if [[ "$LARK_USER_ID" == "YOUR_LARK_OPEN_ID" ]]; then
  echo "WARNING: Replace YOUR_LARK_OPEN_ID with your real Feishu/Lark open_id for actual delivery." >&2
fi
