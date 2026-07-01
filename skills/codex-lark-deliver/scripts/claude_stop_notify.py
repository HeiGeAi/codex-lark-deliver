#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Claude Code Stop hook: push a Feishu/Lark completion notice when a task finishes.

Why a hook instead of an agent rule?
  A markdown rule that asks the model to "send a notice after every task" is
  best-effort: the model often forgets. A Stop hook is enforced by the Claude
  Code engine, so the notice fires deterministically on every task completion.

Behaviour
  - Only notifies when the turn took >= FEISHU_NOTIFY_MIN_SECONDS (default 45s),
    so quick back-and-forth chat does not spam you. Set it to 0 to notify on
    every turn.
  - Summary is the last assistant text message of the turn.
  - The Feishu/Lark message is sent asynchronously (fire-and-forget) so the hook
    returns in a few milliseconds and never slows the session down.
  - All errors are swallowed and the hook always exits 0, so a delivery failure
    can never block Claude Code.

Wiring (in the Claude Code settings file, e.g. ~/.claude/settings.json):
  {
    "hooks": {
      "Stop": [
        { "hooks": [
          { "type": "command",
            "command": "python3 /ABS/PATH/TO/claude_stop_notify.py" }
        ] }
      ]
    }
  }

Config via env vars:
  LARK_NOTIFY_OPEN_ID        recipient open_id (REQUIRED — replace the default)
  LARK_CLI_BIN               path to lark-cli (default: resolve from PATH)
  FEISHU_NOTIFY_MIN_SECONDS  duration gate in seconds (default 45; 0 = always)
  LARK_NOTIFY_AS             lark-cli identity: bot | user (default bot)
"""
import sys, os, json, shutil, subprocess, datetime

OPEN_ID = os.environ.get("LARK_NOTIFY_OPEN_ID", "ou_REPLACE_WITH_YOUR_OPEN_ID")
LARK_BIN = os.environ.get("LARK_CLI_BIN") or shutil.which("lark-cli") or "lark-cli"
THRESHOLD = float(os.environ.get("FEISHU_NOTIFY_MIN_SECONDS", "45"))
AS_IDENTITY = os.environ.get("LARK_NOTIFY_AS", "bot")


def parse_ts(s):
    if not s:
        return None
    try:
        return datetime.datetime.fromisoformat(s.replace("Z", "+00:00"))
    except Exception:
        return None


def main():
    try:
        hook = json.load(sys.stdin)
    except Exception:
        return
    # Avoid re-entrancy: a Stop triggered by this hook must not notify again.
    if hook.get("stop_hook_active"):
        return
    # Skip when Claude Code is driven by a bridge under a dedicated config dir
    # (e.g. lark-channel-bridge). Those sessions already reply in-channel; a
    # completion DM would double up. Adjust the marker to your setup if needed.
    if "lark-channel" in (os.environ.get("CLAUDE_CONFIG_DIR", "") or ""):
        return
    if not OPEN_ID or OPEN_ID.startswith("ou_REPLACE"):
        return  # not configured yet

    tp = os.path.expanduser(hook.get("transcript_path", "") or "")
    cwd = hook.get("cwd", "") or ""
    if not tp or not os.path.exists(tp):
        return

    turn_start = None   # timestamp of the last genuine human prompt
    last_ts = None      # timestamp of the last record (turn end)
    last_assistant = ""

    try:
        with open(tp, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    o = json.loads(line)
                except Exception:
                    continue
                typ = o.get("type")
                ts = parse_ts(o.get("timestamp"))
                if ts:
                    last_ts = ts
                if typ == "user" and not o.get("isSidechain") and "toolUseResult" not in o:
                    content = (o.get("message") or {}).get("content")
                    is_prompt = isinstance(content, str) or (
                        isinstance(content, list)
                        and any(isinstance(c, dict) and c.get("type") == "text" for c in content)
                        and not any(isinstance(c, dict) and c.get("type") == "tool_result" for c in content)
                    )
                    if is_prompt and ts:
                        turn_start = ts
                elif typ == "assistant" and not o.get("isSidechain"):
                    parts = [c.get("text", "") for c in ((o.get("message") or {}).get("content") or [])
                             if isinstance(c, dict) and c.get("type") == "text"]
                    txt = "".join(parts).strip()
                    if txt:
                        last_assistant = txt
    except Exception:
        return

    duration = (last_ts - turn_start).total_seconds() if (turn_start and last_ts) else THRESHOLD
    if duration < THRESHOLD:
        return

    summary = last_assistant[:900] if last_assistant else "(task finished, no text output)"
    proj = os.path.basename(cwd.rstrip("/")) or cwd or "?"
    m, s = int(duration // 60), int(duration % 60)
    dur_str = f"{m}m{s}s" if m else f"{s}s"
    md = f"🖥️ **Claude Code · task done**\nproject: {proj}  ·  {dur_str}\n\n{summary}"

    try:
        subprocess.Popen(
            [LARK_BIN, "im", "+messages-send", "--as", AS_IDENTITY,
             "--user-id", OPEN_ID, "--markdown", md],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL, start_new_session=True,
        )
    except Exception:
        pass


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
