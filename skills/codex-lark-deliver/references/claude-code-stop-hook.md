# Deterministic completion notices for Claude Code (Stop hook)

The agent-rules block asks the model to send a Feishu/Lark notice after each
task. In practice a model-driven rule is best-effort — Claude Code often does
not actually run the command. If you want the notice to fire **every time a
task finishes**, use a Claude Code **Stop hook** instead: it is enforced by the
engine, not by the model.

## 1. Point the hook script at your recipient

`scripts/claude_stop_notify.py` reads a few env vars (all optional except the
open_id):

| env var | meaning | default |
| --- | --- | --- |
| `LARK_NOTIFY_OPEN_ID` | recipient open_id (**required**) | placeholder |
| `LARK_CLI_BIN` | path to `lark-cli` | resolved from `PATH` |
| `FEISHU_NOTIFY_MIN_SECONDS` | only notify if the turn took at least this long | `45` |
| `LARK_NOTIFY_AS` | `bot` or `user` | `bot` |

The duration gate means quick Q&A does not spam you; only turns that actually
did work (>= 45s by default) push a notice. Set it to `0` to notify on every
turn.

## 2. Register the hook in your Claude Code settings

Add this to `~/.claude/settings.json` (merge with any existing keys):

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 /ABS/PATH/TO/skills/codex-lark-deliver/scripts/claude_stop_notify.py"
          }
        ]
      }
    ]
  }
}
```

If you prefer to keep the recipient in the settings file itself, wrap the
command in a small shell snippet that exports `LARK_NOTIFY_OPEN_ID` before
calling the script.

Start a **new** Claude Code session afterwards — hooks are loaded at session
start, and Claude Code may ask you to review the new hook once.

## Notes

- The script sends the Feishu/Lark message asynchronously (detached process),
  so the hook returns in a few milliseconds and never slows the session.
- Every error is swallowed and the hook always exits `0`, so a delivery failure
  can never block Claude Code.
- If you also run Claude Code headlessly under a bridge (e.g.
  `lark-channel-bridge`) with its own `CLAUDE_CONFIG_DIR`, the script skips
  those sessions (they already reply in-channel) to avoid double notifications.
