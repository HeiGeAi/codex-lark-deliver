# Agent Markdown Rules

Copy or upsert this block into the user's system-level `AGENTS.md`, `agents.markdown`, or equivalent agent markdown file. Replace `{{LARK_USER_ID}}` with the user's own Feishu/Lark open_id before writing it.

```markdown
<!-- BEGIN CODEX-LARK-DELIVER -->
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
<!-- END CODEX-LARK-DELIVER -->
```
