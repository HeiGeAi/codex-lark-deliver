# Codex Lark Deliver

Codex Lark Deliver is an open-source Codex Skill and installer that makes a practical workflow repeatable:

- connect Codex or another local coding agent to Feishu/Lark;
- install the official Lark CLI;
- install Zara Zhang's `lark-coding-agent-bridge` package;
- write agent-level rules so every task ends with a Feishu/Lark completion notice;
- require real file-body delivery for generated artifacts, not link-only handoffs.

## Why

Codex can finish work while you are away from the computer. A local sound or desktop notification is easy to miss. Feishu/Lark is often where the real work continues: files can be viewed on mobile, forwarded to teammates, searched, and handled inside the existing company workflow.

This project adds the missing operating discipline: when the agent finishes, it should notify you in Feishu/Lark, and if it created a file, it should send the actual file body whenever the platform supports it.

## What It Installs

The installer performs four actions:

1. Installs the official Lark CLI (version pinned in the installer):
   `npm i -g @larksuite/cli@1.0.95`
2. Installs Zara Zhang's bridge package (version pinned in the installer):
   `npm i -g lark-channel-bridge@0.7.1`
3. Copies the `codex-lark-deliver` Skill into the user's Codex-visible skills directory.
4. Writes an idempotent `CODEX-LARK-DELIVER` rules block into `AGENTS.md` or another chosen agent markdown file.

Authentication and QR pairing still require the user to authorize in Lark/Feishu. The script installs and configures the local pieces; it does not bypass Lark authorization.

Both npm dependencies are pinned to an exact version in `install.sh` and `install.ps1` (`LARK_CLI_PACKAGE` / `BRIDGE_PACKAGE` or `$LarkCliPackage` / `$BridgePackage`) as a supply-chain safeguard. To upgrade, bump the pinned version deliberately in both installers, review the upstream changelog, and re-run the self-tests.

## Quick Start

Windows PowerShell:

```powershell
git clone https://github.com/HeiGeAi/codex-lark-deliver.git
cd codex-lark-deliver
powershell -ExecutionPolicy Bypass -File .\install.ps1 -LarkUserId "ou_your_open_id"
```

macOS/Linux:

```bash
git clone https://github.com/HeiGeAi/codex-lark-deliver.git
cd codex-lark-deliver
bash ./install.sh --lark-user-id "ou_your_open_id"
```

Then verify:

```bash
lark-cli auth status
lark-cli auth login
lark-channel-bridge run
```

Restart Codex after installation so the new Skill and agent markdown rules are loaded.

## Usage Scenarios

- You start a long Codex task, leave your laptop, and receive a Feishu/Lark message when it completes.
- Codex generates a PDF, spreadsheet, PowerPoint deck, Markdown report, image, archive, or HTML snapshot, then sends the actual file body to you in Feishu/Lark.
- Codex creates a Feishu cloud doc, verifies it is fetchable, sends the real cloud-doc URL, and also sends an exported/source body when available.
- A recurring automation generates a daily report and sends both the status notice and the report artifact.
- A teammate needs the output in Feishu/Lark, where you can forward the file without returning to the desktop.

## What The Agent Rule Requires

The installed markdown block tells the agent to:

- send a completion notice after every task;
- include task name, status, deliverable links, blockers, and exact errors when something fails;
- verify a returned `message_id` when possible;
- deliver file bodies for local files, cloud docs, web pages, and other artifacts;
- mark delivery as partial or failed when the file body cannot be created, uploaded, sent, or verified;
- apply the same discipline to recurring automations.

The canonical rule block lives in `skills/codex-lark-deliver/references/agent-rules.md`.

## Credits

This project is built on two excellent pieces of work:

- Lark/Feishu and the official `@larksuite/cli`, which provide command-line access to Feishu/Lark messages, docs, files, and platform APIs.
- Zara Zhang's [`lark-coding-agent-bridge`](https://github.com/zarazhangrui/lark-coding-agent-bridge), which bridges Feishu/Lark messenger with local coding agents such as Claude Code and Codex through the `lark-channel-bridge` package.

Codex Lark Deliver does not replace those projects. It adds a small but important layer on top: one installer plus an agent markdown rule set that turns "the bridge exists" into a repeatable completion-notice and file-delivery workflow.

## Repository Layout

```text
.
├── install.ps1
├── install.sh
├── LICENSE
├── PROMO.zh-CN.md
├── README.md
├── SECURITY.md
├── .github/
│   └── workflows/
│       └── ci.yml
├── tests/
│   ├── selftest.ps1
│   └── selftest.sh
└── skills/
    └── codex-lark-deliver/
        ├── SKILL.md
        ├── agents/openai.yaml
        ├── references/
        │   ├── agent-rules.md
        │   └── setup-checklist.md
        └── scripts/
            ├── send_test_notice.ps1
            └── write_agent_rules.ps1
```

## Safety Notes

- Keep Lark app secrets, tokens, verification tokens, and encrypt keys out of git.
- Use a real recipient open_id. The installer writes a placeholder if you omit it, but delivery will not work until it is replaced.
- Treat remote coding-agent execution as sensitive. Zara's bridge should be configured with allowlisted users and clear confirmation boundaries before it performs code changes or other side-effecting work.
- Do not call setup complete until `lark-cli auth status`, a test message, and bridge pairing have been verified.

## License

MIT

## More open-source tools

This project is part of the HeiGe AI open-source arsenal. Browse all projects with purpose and license at [heigeai.com/opensource](https://www.heigeai.com/en/opensource/).
