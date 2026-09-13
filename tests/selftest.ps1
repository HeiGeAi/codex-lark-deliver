$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-lark-deliver-" + [Guid]::NewGuid().ToString("N"))
$skillRoot = Join-Path $tempRoot "skills"
$agentRules = Join-Path $tempRoot "AGENTS.md"
$fakeBin = Join-Path $tempRoot "fake-bin"
$originalPath = $env:PATH
$originalNativeLog = $env:FAKE_NATIVE_LOG
$originalNativeExitCode = $env:FAKE_NATIVE_EXIT_CODE

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
    if (-not (Test-Path -LiteralPath (Join-Path (Join-Path $skillRoot "codex-lark-deliver") "SKILL.md"))) {
        throw "Skill installation is missing"
    }

    New-Item -ItemType Directory -Force -Path $fakeBin | Out-Null
    $fakeNativeCommand = @'
@echo off
echo %*>>"%FAKE_NATIVE_LOG%"
exit /b %FAKE_NATIVE_EXIT_CODE%
'@
    $fakeNpmCommand = Join-Path $fakeBin "npm.cmd"
    Set-Content -LiteralPath $fakeNpmCommand -Value $fakeNativeCommand -Encoding Ascii
    Set-Content -LiteralPath (Join-Path $fakeBin "lark-cli.cmd") -Value $fakeNativeCommand -Encoding Ascii
    $env:PATH = $fakeBin
    $resolvedNpmCommand = (Get-Command npm.cmd -ErrorAction Stop).Source
    if (-not [System.String]::Equals($resolvedNpmCommand, $fakeNpmCommand, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to run non-test npm command: $resolvedNpmCommand"
    }

    $npmLog = Join-Path $tempRoot "npm-success.log"
    $env:FAKE_NATIVE_LOG = $npmLog
    $env:FAKE_NATIVE_EXIT_CODE = "0"
    & (Join-Path $root "install.ps1") `
        -LarkUserId "ou_selftest" `
        -SkillRoot (Join-Path $tempRoot "npm-success-skills") `
        -SkipAgentRules | Out-Null
    $npmCalls = @(Get-Content -LiteralPath $npmLog)
    if ($npmCalls.Count -ne 2) {
        throw "Expected two successful npm calls, found $($npmCalls.Count)"
    }
    if ($npmCalls[0] -notmatch 'install -g @larksuite/cli') {
        throw "Missing @larksuite/cli npm call"
    }
    if ($npmCalls[1] -notmatch 'install -g lark-channel-bridge') {
        throw "Missing lark-channel-bridge npm call"
    }

    $env:FAKE_NATIVE_LOG = Join-Path $tempRoot "npm-failure.log"
    $env:FAKE_NATIVE_EXIT_CODE = "23"
    $npmFailure = $null
    try {
        & (Join-Path $root "install.ps1") `
            -LarkUserId "ou_selftest" `
            -SkillRoot (Join-Path $tempRoot "npm-failure-skills") `
            -SkipBridgeInstall `
            -SkipAgentRules | Out-Null
    }
    catch {
        $npmFailure = $_.Exception.Message
    }
    if ($npmFailure -notmatch 'exit code 23') {
        throw "Expected npm exit code 23 to propagate, got: $npmFailure"
    }
    if (Test-Path -LiteralPath (Join-Path (Join-Path $tempRoot "npm-failure-skills") "codex-lark-deliver")) {
        throw "Installer continued after npm failed"
    }

    $noticeScript = Join-Path (Join-Path (Join-Path (Join-Path $root "skills") "codex-lark-deliver") "scripts") "send_test_notice.ps1"
    $fakeLarkCommand = Join-Path $fakeBin "lark-cli.cmd"
    $testFile = Join-Path $tempRoot "test-delivery.txt"
    Set-Content -LiteralPath $testFile -Value "selftest artifact" -Encoding Utf8
    $larkLog = Join-Path $tempRoot "lark-success.log"
    $env:FAKE_NATIVE_LOG = $larkLog
    $env:FAKE_NATIVE_EXIT_CODE = "0"
    & $noticeScript `
        -LarkUserId "ou_selftest" `
        -File $testFile `
        -LarkCliCommand $fakeLarkCommand
    $larkCalls = @(Get-Content -LiteralPath $larkLog)
    if ($larkCalls.Count -ne 2) {
        throw "Expected two successful lark-cli calls, found $($larkCalls.Count)"
    }
    if ($larkCalls[0] -notmatch 'im \+messages-send --as bot --user-id ou_selftest --markdown') {
        throw "Missing lark-cli markdown delivery call"
    }
    if ($larkCalls[1] -notmatch 'im \+messages-send --as bot --user-id ou_selftest --file') {
        throw "Missing lark-cli file delivery call"
    }

    $env:FAKE_NATIVE_LOG = Join-Path $tempRoot "lark-failure.log"
    $env:FAKE_NATIVE_EXIT_CODE = "41"
    $larkFailure = $null
    try {
        & $noticeScript -LarkUserId "ou_selftest" -LarkCliCommand $fakeLarkCommand
    }
    catch {
        $larkFailure = $_.Exception.Message
    }
    if ($larkFailure -notmatch 'exit code 41') {
        throw "Expected lark-cli exit code 41 to propagate, got: $larkFailure"
    }

    Write-Output "selftest=ok"
}
finally {
    $env:PATH = $originalPath
    $env:FAKE_NATIVE_LOG = $originalNativeLog
    $env:FAKE_NATIVE_EXIT_CODE = $originalNativeExitCode
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

exit 0
