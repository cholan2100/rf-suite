$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Split-Path -Parent $ScriptDir
Set-Location $RootDir

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "  Opening Interactive Bash Terminal in RF Suite" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$running = docker compose ps --status running -q rf-suite 2>$null
if ($running) {
    docker compose exec -it rf-suite bash
} else {
    Write-Host "[RF Suite] Starting interactive shell in container..." -ForegroundColor Cyan
    docker compose run --rm -it rf-suite bash
}
