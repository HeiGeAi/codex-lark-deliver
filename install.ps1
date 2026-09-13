[CmdletBinding()]
param(
    [string]$LarkUserId = "YOUR_LARK_OPEN_ID",
    [string]$AgentMarkdownPath,
    [string]$SkillRoot,
    [switch]$SkipNpmInstall,
    [switch]$SkipBridgeInstall,
    [switch]$SkipAgentRules
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    return [System.IO.Path]::GetFullPath($PSScriptRoot)
}

function Get-NpmCommand {
    $command = Get-Command npm.cmd -ErrorAction SilentlyContinue
    if (-not $command) {
        $command = Get-Command npm -ErrorAction SilentlyContinue
    }
    if (-not $command) {
        throw "npm was not found. Install Node.js first, then re-run this script."
    }
    return $command.Source
}

function Assert-NativeCommandSucceeded {
    param(
        [string]$CommandName,
        [int]$ExitCode
    )

    if ($ExitCode -ne 0) {
        throw "$CommandName failed with exit code $ExitCode."
    }
}

function Assert-ChildPath {
    param(
        [string]$Child,
        [string]$Parent
    )

    $childFull = [System.IO.Path]::GetFullPath($Child)
    $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    if (-not $childFull.StartsWith($parentFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to modify path outside expected parent. Child=$childFull Parent=$parentFull"
    }
}

function Get-SkillTargets {
    param([string]$ExplicitRoot)

    if ($ExplicitRoot) {
        return @([System.IO.Path]::GetFullPath($ExplicitRoot))
    }

    $targets = New-Object System.Collections.Generic.List[string]
    $codexHome = $env:CODEX_HOME
    if (-not $codexHome) {
        $codexHome = Join-Path $HOME ".codex"
    }
    $targets.Add((Join-Path $codexHome "skills"))

    $agentsSkills = Join-Path (Join-Path $HOME ".agents") "skills"
    if (Test-Path -LiteralPath $agentsSkills) {
        $targets.Add($agentsSkills)
    }

    return $targets | Select-Object -Unique
}

function Install-Skill {
    param(
        [string]$Source,
        [string[]]$Targets
    )

    foreach ($targetRoot in $Targets) {
        New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null
        $destination = Join-Path $targetRoot "codex-lark-deliver"
        Assert-ChildPath -Child $destination -Parent $targetRoot
        if (Test-Path -LiteralPath $destination) {
            Remove-Item -LiteralPath $destination -Recurse -Force
        }
        Copy-Item -LiteralPath $Source -Destination $destination -Recurse
        Write-Output "Installed skill: $destination"
    }
}

$repoRoot = Get-RepoRoot
$skillSource = Join-Path (Join-Path $repoRoot "skills") "codex-lark-deliver"
if (-not (Test-Path -LiteralPath $skillSource)) {
    throw "Skill source not found: $skillSource"
}

if (-not $SkipNpmInstall -or -not $SkipBridgeInstall) {
    $npm = Get-NpmCommand
}

if (-not $SkipNpmInstall) {
    & $npm install -g @larksuite/cli
    $npmExitCode = $LASTEXITCODE
    Assert-NativeCommandSucceeded `
        -CommandName "npm install -g @larksuite/cli" `
        -ExitCode $npmExitCode
}

if (-not $SkipBridgeInstall) {
    & $npm install -g lark-channel-bridge
    $npmExitCode = $LASTEXITCODE
    Assert-NativeCommandSucceeded `
        -CommandName "npm install -g lark-channel-bridge" `
        -ExitCode $npmExitCode
}

$targets = Get-SkillTargets -ExplicitRoot $SkillRoot
Install-Skill -Source $skillSource -Targets $targets

if (-not $SkipAgentRules) {
    $writer = Join-Path (Join-Path $skillSource "scripts") "write_agent_rules.ps1"
    if ($AgentMarkdownPath) {
        & $writer -LarkUserId $LarkUserId -AgentMarkdownPath $AgentMarkdownPath
    } else {
        & $writer -LarkUserId $LarkUserId
    }
}

Write-Output ""
Write-Output "Next verification steps:"
Write-Output "1. Run: lark-cli auth status"
Write-Output "2. If needed, run: lark-cli auth login"
Write-Output "3. Pair Zara's bridge: lark-channel-bridge run"
Write-Output "4. Restart Codex so the installed skill and agent markdown rules are loaded."
if ($LarkUserId -eq "YOUR_LARK_OPEN_ID") {
    Write-Warning "Replace YOUR_LARK_OPEN_ID with your real Feishu/Lark open_id for actual delivery."
}
