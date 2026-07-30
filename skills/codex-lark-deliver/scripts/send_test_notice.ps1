[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$LarkUserId,

    [string]$File,
    [string]$LarkCliCommand = "lark-cli"
)

$ErrorActionPreference = "Stop"

function Assert-NativeCommandSucceeded {
    param(
        [string]$CommandName,
        [int]$ExitCode
    )

    if ($ExitCode -ne 0) {
        throw "$CommandName failed with exit code $ExitCode."
    }
}

$command = Get-Command $LarkCliCommand -ErrorAction SilentlyContinue
if (-not $command) {
    throw "Lark CLI command not found: $LarkCliCommand"
}

$message = "Codex Lark Deliver test: completion notices are connected. Time: $([DateTimeOffset]::Now.ToString("o"))"
& $command.Source im +messages-send --as bot --user-id $LarkUserId --markdown $message
$larkExitCode = $LASTEXITCODE
Assert-NativeCommandSucceeded -CommandName "lark-cli markdown delivery" -ExitCode $larkExitCode

if ($File) {
    $resolved = Resolve-Path -LiteralPath $File
    $item = Get-Item -LiteralPath $resolved
    if ($item.Length -le 0) {
        throw "Test file is empty: $resolved"
    }
    & $command.Source im +messages-send --as bot --user-id $LarkUserId --file $resolved
    $larkExitCode = $LASTEXITCODE
    Assert-NativeCommandSucceeded -CommandName "lark-cli file delivery" -ExitCode $larkExitCode
}
