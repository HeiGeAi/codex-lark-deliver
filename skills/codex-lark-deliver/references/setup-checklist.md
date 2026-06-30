# Setup Checklist

Use this checklist when setting up or troubleshooting Codex/Lark delivery.

## Required Pieces

- Node.js and npm are available.
- Official Lark CLI is installed:
  `npm i -g @larksuite/cli`
- Zara Zhang's bridge package is installed:
  `npm i -g lark-channel-bridge`
- The user has completed Lark CLI authentication:
  `lark-cli auth login`
- The bridge has been paired with the user's PersonalAgent in Feishu/Lark:
  `lark-channel-bridge run`
- The user has a known recipient open_id for completion notices.
- The agent markdown contains the `CODEX-LARK-DELIVER` rules block.

## Verification

1. Run `lark-cli auth status`.
2. Send a small markdown test message to the target open_id.
3. Send a small test file if file delivery is part of the user's workflow.
4. Run `lark-channel-bridge --help`.
5. Start the bridge with `lark-channel-bridge run` and confirm the first-run QR or pairing flow completes.
6. Confirm the agent markdown block contains the real open_id, not a placeholder.

## Boundaries

- Lark login, app authorization, and bridge QR pairing require the user to authorize in a browser or in Feishu/Lark. Do not claim these are complete unless verified.
- File delivery depends on the Lark CLI scopes and the message/file APIs available to the user's tenant.
- Keep app secrets and tokens out of tracked files.
- If an upload or send fails, preserve the exact command output in the handoff.
