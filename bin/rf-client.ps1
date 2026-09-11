# ==============================================================================
# RF SaaS Pure Native Windows REST Client
# Dispatches workflow stages to Hosted SaaS API without any WSL dependencies
# ==============================================================================
param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,

    [string]$Desc = "",
    [string[]]$Stages = @(),
    [string]$ServerUrl = "http://192.168.0.100:8000",
    [string]$OutputDir = "projects"
)

$ErrorActionPreference = "Stop"

Write-Host "[RF SaaS Client] Connecting to SaaS API at $ServerUrl..." -ForegroundColor Cyan

# 1. Prepare run payload
$stageList = @()
foreach ($s in $Stages) {
    if ($s -match ',') {
        $stageList += ($s -split ',')
    } else {
        $stageList += $s
    }
}
$stageList = @($stageList | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$payload = @{}
if ($stageList.Count -gt 0) {
    $payload["stages"] = $stageList
}
if ($Desc) {
    $payload["desc"] = $Desc
}

$jsonBody = $payload | ConvertTo-Json -Compress
$runUri = "$ServerUrl/v1/projects/$ProjectName/run"

Write-Host "[RF SaaS Client] Dispatching stage(s) [$(($Stages -join ', '))] for '$ProjectName'..." -ForegroundColor Green
$response = Invoke-RestMethod -Uri $runUri -Method Post -ContentType "application/json" -Body $jsonBody -TimeoutSec 600

Write-Host "[RF SaaS Client] Server execution status: $($response.status)" -ForegroundColor Green

# 2. Sync generated artifacts back to local projects directory
$localProjectDir = Join-Path $OutputDir $ProjectName
if (-not (Test-Path $localProjectDir)) {
    New-Item -ItemType Directory -Path $localProjectDir -Force | Out-Null
}

if ($response.artifacts) {
    $artifactsObj = $response.artifacts
    $names = @()
    if ($artifactsObj -is [System.Management.Automation.PSCustomObject]) {
        $names = $artifactsObj.PSObject.Properties.Name
    } elseif ($artifactsObj -is [System.Collections.IDictionary]) {
        $names = $artifactsObj.Keys
    }

    Write-Host "[RF SaaS Client] Syncing $($names.Count) artifact(s) to local workspace: $localProjectDir" -ForegroundColor Cyan
    $wc = New-Object System.Net.WebClient
    try {
        foreach ($relPath in $names) {
            $downloadUri = "$ServerUrl/v1/projects/$ProjectName/artifacts/$relPath"
            $destFile = Join-Path $localProjectDir ($relPath -replace '/', '\')
            $destDir = Split-Path $destFile -Parent
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }

            # Check if file is already on local disk with non-zero size (local volume mount)
            if (Test-Path $destFile) {
                $item = Get-Item $destFile
                if ($item.Length -gt 0) {
                    Write-Host "  -> Verified $relPath ($($item.Length) bytes)" -ForegroundColor DarkGray
                    continue
                }
            }

            $tmpFile = "$destFile.tmp"
            try {
                $wc.DownloadFile($downloadUri, $tmpFile)
                if ((Get-Item $tmpFile).Length -gt 0) {
                    Move-Item -Path $tmpFile -Destination $destFile -Force
                    Write-Host "  -> Synced $relPath" -ForegroundColor DarkGray
                } else {
                    Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
                }
            } catch {
                Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
                Write-Host "  -> Skip/Error $relPath : $_" -ForegroundColor Yellow
            }
        }
    } finally {
        $wc.Dispose()
    }
}

Write-Host "[RF SaaS Client] [OK] All deliverables synchronized successfully!" -ForegroundColor Green
return $response
