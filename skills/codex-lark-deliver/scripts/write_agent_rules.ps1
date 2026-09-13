[CmdletBinding()]
param(
    [string]$LarkUserId = "YOUR_LARK_OPEN_ID",
    [string]$AgentMarkdownPath,
    [string]$LarkCliCommand = "lark-cli"
)

$ErrorActionPreference = "Stop"

function Resolve-AgentMarkdownPath {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        return [System.IO.Path]::GetFullPath($ExplicitPath)
    }

    $codexHome = $env:CODEX_HOME
    if (-not $codexHome) {
        $codexHome = Join-Path $HOME ".codex"
    }

    $candidates = @(
        (Join-Path $codexHome "AGENTS.md"),
        (Join-Path $codexHome "agents.markdown"),
        (Join-Path $codexHome "AGENTS.markdown")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return [System.IO.Path]::GetFullPath($candidate)
        }
    }

    return [System.IO.Path]::GetFullPath((Join-Path $codexHome "AGENTS.md"))
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Content
    )

    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

$targetPath = Resolve-AgentMarkdownPath -ExplicitPath $AgentMarkdownPath

$template = @'
<!-- BEGIN CODEX-LARK-DELIVER -->
## Feishu/Lark Completion Notice and File Delivery

These rules apply to every Codex task on this machine, including normal chat tasks, background work, and recurring automations.

### Completion Notice

- After completing any user task, send a Feishu/Lark direct message to the current user as a completion notice.
- Send the notice only to the user's own open_id unless the user explicitly names another recipient or group.
- Recipient open_id: `{{LARK_USER_ID}}`.
- Prefer this command shape:
  `{{LARK_CLI_COMMAND}} im +messages-send --as bot --user-id {{LARK_USER_ID}} --markdown "<message>"`
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
'@

$block = $template.Replace("{{LARK_USER_ID}}", $LarkUserId).Replace("{{LARK_CLI_COMMAND}}", $LarkCliCommand)
$markerPattern = "(?s)<!-- BEGIN CODEX-LARK-DELIVER -->.*?<!-- END CODEX-LARK-DELIVER -->"

if (Test-Path -LiteralPath $targetPath) {
    $current = Get-Content -LiteralPath $targetPath -Raw
    if (-not $current) {
        $current = "# Global Codex Agent Rules`r`n"
    }
} else {
    $current = "# Global Codex Agent Rules`r`n"
}

if ($current -match $markerPattern) {
    $updated = [regex]::Replace($current, $markerPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $block }, 1)
} else {
    $updated = $current.TrimEnd() + "`r`n`r`n" + $block + "`r`n"
}

Write-Utf8NoBom -Path $targetPath -Content $updated

Write-Output "Updated agent markdown: $targetPath"
if ($LarkUserId -eq "YOUR_LARK_OPEN_ID") {
    Write-Warning "The rules were written with a placeholder open_id. Re-run with -LarkUserId once you know the recipient open_id."
}
