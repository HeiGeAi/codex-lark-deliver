---
name: codex-lark-deliver
description: Set up and operate Codex completion notices and file-body delivery through Feishu/Lark. Use when a user wants Codex, Claude Code, or another AI coding agent to notify them in Lark after every task, deliver generated files or Feishu cloud docs, install or verify Lark CLI, install or verify Zara Zhang's lark-coding-agent-bridge/lark-channel-bridge, or write these rules into AGENTS.md or agents.markdown.
---

# Codex Lark Deliver

## Overview

Use this skill to connect an AI coding agent's completion loop to Feishu/Lark: every task ends with a Lark notice, and every file-like deliverable is sent as a real file body when the platform allows it. This skill also guides setup of the official Lark CLI and Zara Zhang's `lark-coding-agent-bridge` package (`lark-channel-bridge`) so users can talk to local coding agents from Lark.

## Setup Workflow

1. Read `references/setup-checklist.md` before changing a user's machine setup.
2. Install or verify the official Lark CLI: `npm i -g @larksuite/cli`, then `lark-cli auth status`.
3. Install or verify Zara's bridge: `npm i -g lark-channel-bridge`, then `lark-channel-bridge --help`.
4. Install this skill into the user's Codex-visible skills directory.
5. Write the completion notice and file-body delivery rules into the user's agent markdown.
   - Read `references/agent-rules.md` first.
   - Prefer `scripts/write_agent_rules.ps1` on Windows.
   - Use the exact BEGIN/END markers so later runs update the same block.
6. Verify with a harmless test Lark message and, when practical, a small test file.

## Operating Rules

When performing or verifying a delivery flow:

- Treat Lark authentication, bridge pairing, and recipient open_id as required state. Do not claim setup is complete if any of them is missing.
- Use `lark-cli im +messages-send --as bot --user-id <open_id> --markdown "<message>"` for completion notices when available.
- For local deliverables, verify the file exists and is non-empty before sending it with Lark CLI file delivery.
- For Feishu cloud docs, verify the real cloud doc is fetchable and include the clickable URL in the notice.
- Preserve exact errors from Lark CLI, bridge startup, upload, or cloud-doc verification failures.
- Do not recursively send a second completion notice just because a completion notice was sent.

## Scripts

- `scripts/write_agent_rules.ps1`: upserts the delivery rules into `AGENTS.md` or another specified agent markdown file.
- `scripts/send_test_notice.ps1`: sends a small test completion notice, and optionally a test file, through Lark CLI.

## References

- `references/agent-rules.md`: canonical prompt block to write into agent markdown.
- `references/setup-checklist.md`: install, auth, bridge-pairing, and verification checklist.
