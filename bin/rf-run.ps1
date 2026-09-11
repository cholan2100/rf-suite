param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CommandArgs
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$SuiteDir = Split-Path -Parent $ScriptDir
$RepoRoot = Split-Path -Parent $SuiteDir

if (-not $CommandArgs) {
    Write-Host "Usage: rf-run <command> [args...]" -ForegroundColor Yellow
    Write-Host "Example: rf-run python -m agent.workflow --desc ""100mhz BPF""" -ForegroundColor Cyan
    exit 1
}

# Check for AWS mode
$AwsMode = $false
if ($env:RF_BACKEND -eq "aws" -or $env:AWS_INSTANCE_ID) {
    $AwsMode = $true
} else {
    $envFiles = @("$RepoRoot\.env", "$SuiteDir\.env")
    foreach ($ef in $envFiles) {
        if (Test-Path $ef) {
            $matches = Get-Content $ef | Where-Object { $_ -match "^(RF_BACKEND=aws|AWS_INSTANCE_ID=)" }
            if ($matches) {
                $AwsMode = $true
                break
            }
        }
    }
}

if ($AwsMode) {
    Write-Host "[RF Suite] AWS Backend Active. Dispatching command to AWS host..." -ForegroundColor Cyan
    Set-Location $RepoRoot
    if (Get-Command python -ErrorAction SilentlyContinue) {
        & python -m agent.aws.rf_remote_client run @CommandArgs
        exit $LASTEXITCODE
    } elseif (Get-Command py -ErrorAction SilentlyContinue) {
        & py -3 -m agent.aws.rf_remote_client run @CommandArgs
        exit $LASTEXITCODE
    } else {
        # Fallback to WSL python3
        $wslPath = (wsl -d Debian wslpath "$RepoRoot").Trim()
        $cmdStr = $CommandArgs -join " "
        wsl -d Debian bash -c "cd '$wslPath' && python3 -m agent.aws.rf_remote_client run $cmdStr"
        exit $LASTEXITCODE
    }
}

# Local Docker Mode
Set-Location $SuiteDir
$running = docker compose ps --status running -q rf-suite 2>$null
if ($running) {
    docker compose exec rf-suite @CommandArgs
} else {
    Write-Host "[RF Suite] Starting ephemeral container to run command..." -ForegroundColor Cyan
    docker compose run --rm rf-suite @CommandArgs
}
