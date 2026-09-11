param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CommandArgs
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$SuiteDir = Split-Path -Parent $ScriptDir
$RepoRoot = Split-Path -Parent $SuiteDir

Set-Location $RepoRoot

if (Get-Command python -ErrorAction SilentlyContinue) {
    & python -m agent.aws.rf_remote_client @CommandArgs
    exit $LASTEXITCODE
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    & py -3 -m agent.aws.rf_remote_client @CommandArgs
    exit $LASTEXITCODE
} else {
    $wslPath = (wsl -d Debian wslpath "$RepoRoot").Trim()
    $cmdStr = $CommandArgs -join " "
    wsl -d Debian bash -c "cd '$wslPath' && python3 -m agent.aws.rf_remote_client $cmdStr"
    exit $LASTEXITCODE
}
