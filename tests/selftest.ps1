$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-lark-deliver-" + [Guid]::NewGuid().ToString("N"))
$skillRoot = Join-Path $tempRoot "skills"
$agentRules = Join-Path $tempRoot "AGENTS.md"

try {
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

    foreach ($attempt in 1..2) {
        & (Join-Path $root "install.ps1") `
            -LarkUserId "ou_selftest" `
            -SkillRoot $skillRoot `
            -AgentMarkdownPath $agentRules `
            -SkipNpmInstall `
            -SkipBridgeInstall | Out-Null
    }

    $content = Get-Content -LiteralPath $agentRules -Raw
    $markerCount = ([regex]::Matches($content, '<!-- BEGIN CODEX-LARK-DELIVER -->')).Count
    if ($markerCount -ne 1) {
        throw "Expected one agent-rules block, found $markerCount"
    }
    if ($content -notmatch '--as bot --user-id ou_selftest') {
        throw "Bot delivery command was not installed"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $skillRoot "codex-lark-deliver\SKILL.md"))) {
        throw "Skill installation is missing"
    }

    Write-Output "selftest=ok"
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
