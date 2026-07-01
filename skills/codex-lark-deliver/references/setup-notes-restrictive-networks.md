# Field notes: setup behind an HTTP proxy / restrictive network

These are hard-won notes from a real deployment where the machine reaches the
internet through a local HTTP proxy (a common setup in mainland China). None of
this is required on an unrestricted network, but if bot pairing "just hangs" or
replies fail intermittently, this is almost certainly why.

Issues marked **[upstream]** live in `lark-channel-bridge` /
`@larksuite/channel`, not in this installer — they are documented here because
they surface while following this project's Quick Start. Consider filing them
upstream too.

## 1. QR app creation needs a TTY and can fail behind a proxy

`lark-channel-bridge run` (no `--app-id`) enters an interactive QR wizard. It
requires an attached terminal, and the registration request itself can fail
behind a proxy. The robust path is to create the Feishu/Lark app yourself and
pass credentials:

```bash
lark-channel-bridge run --profile codex --agent codex \
  --app-id cli_xxx --app-secret ****
```

The easiest way to get a correctly-configured app: in the Feishu Open Platform
developer console use the **one-click "Agent app"** creation flow (预置智能体应用).
It pre-provisions the bot, event subscription, and scopes an agent bridge needs,
and hands you the App ID / App Secret directly — no manual scope wiring.

To run **both** a Claude bot and a Codex bot, create **two separate apps** (one
per profile). A single app cannot serve both agents at once — both bots would
receive the same inbound events and race to answer.

## 2. **[upstream]** Proxy + axios ⇒ "Maximum number of redirects exceeded"

When an `HTTPS_PROXY` env var is set, `@larksuite/channel` builds an
`HttpsProxyAgent` and assigns it to the shared axios instance, but does **not**
also set `proxy: false`. axios then applies its own built-in proxy handling on
top of the agent (double proxying), which loops and throws
`ERR_FR_TOO_MANY_REDIRECTS`. The bridge then fails with:

```
could not resolve bot identity via /open-apis/bot/v3/info
```

A plain `curl` through the same proxy returns `200`, which confirms the proxy
itself is fine — it is the double-proxy in the client. The one-line upstream fix
is to set `defaults.proxy = false` alongside the proxy agent. Until that lands,
either run the bridge with **no** proxy env (direct connection) if your network
routes to the platform that way, or patch the installed SDK locally.

## 3. **[upstream]** Aggressive WS ping timeout ⇒ intermittent `cardid is invalid`

`wsConfig.pingTimeout` defaults to `3` seconds. On a jittery or proxied link
this triggers frequent false reconnects. Because a streaming reply first creates
a card and then updates it, a reconnect between those steps invalidates the
`card_id`, so the reply fails intermittently with:

```
Failed to create card content, ErrCode: 11310; ErrMsg: cardid is invalid
```

Raising the timeout (e.g. to 30s) removes the reconnect storm and makes replies
reliable. Making this configurable upstream would help a lot.

## 4. **[upstream]** Agent subprocess inherits the bridge's proxy env

If you run the bridge itself through the proxy, the spawned agent (`claude` /
`codex`) inherits `HTTP_PROXY`/`HTTPS_PROXY` too, and can hang when its own
model API streaming goes through that proxy. Point the bridge at a wrapper that
strips proxy env before exec:

```sh
#!/bin/sh
# ~/.local/bin/claude-noproxy  (and a codex-noproxy twin)
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY NODE_USE_ENV_PROXY
exec /absolute/path/to/real/claude "$@"
```

```bash
LARK_CHANNEL_CLAUDE_BIN=~/.local/bin/claude-noproxy \
LARK_CHANNEL_CODEX_BIN=~/.local/bin/codex-noproxy \
  lark-channel-bridge run --profile ...
```

This keeps the bridge's Feishu traffic on the proxy while the agents talk to
their model endpoints directly.

## 5. Claude Code CLI behind a non-Anthropic gateway can 401 on a stale OAuth

If you point the `claude` CLI at an Anthropic-compatible gateway via
`ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` (in `settings.json`), a **leftover
expired OAuth login** in the default config dir can take precedence and send the
wrong credential, producing `401` even though the gateway key is valid (a direct
`curl` to the gateway with the same key succeeds). Also watch for a shell
`ANTHROPIC_BASE_URL` that overrides the settings value.

Fix: run the agent with a **clean `CLAUDE_CONFIG_DIR`** that contains only the
gateway config and **no stored credentials file**, so the API key is the only
auth path. A wrapper can set this alongside the proxy-stripping from note 4.

## 6. Wrapper binaries: point at the real executable

Double-check which `claude`/`codex` your shell actually uses (`command -v`).
A broken shim in `~/.local/bin` can shadow the working binary in
`/opt/homebrew/bin` (or wherever your package manager installed it). The wrapper
in note 4 should `exec` the real one.
