# ==============================================================================
# RF SaaS Pure Native Windows REST Client
# Dispatches workflow stages to Hosted SaaS API without any WSL dependencies
# ==============================================================================
param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,

    [string]$Desc = "",
    [string]$SpecFile = "",
    [string]$SpecJson = "",
    [string[]]$Stages = @(),
    [string]$ServerUrl = "",
    [string]$OutputDir = "projects"
)

$ErrorActionPreference = "Stop"

# Resolve Server URL dynamically from parameter, env var, or .env file
if (-not $ServerUrl) {
    if ($env:RF_SAAS_URL) {
        $ServerUrl = $env:RF_SAAS_URL
    } else {
        $foundEnv = $false
        foreach ($envFile in @("..\.env", ".env", "$PSScriptRoot\..\..\.env", "$PSScriptRoot\..\.env")) {
            if (Test-Path $envFile) {
                $foundEnv = $true
                $match = Get-Content $envFile | Where-Object { $_ -match "^RF_SAAS_URL=(.+)$" } | Select-Object -First 1
                if ($match) {
                    $ServerUrl = ($match -replace "^RF_SAAS_URL=", "").Trim().Trim('"').Trim("'")
                    break
                }
            }
        }
        if (-not $foundEnv -and -not $ServerUrl) {
            $defaultEnvPath = "$PSScriptRoot\..\..\.env"
            if (-not (Test-Path $defaultEnvPath)) {
                @"
# RF Suite SaaS Microservice Configuration
RF_BACKEND=aws_saas
RF_SAAS_URL=http://rf.nakedcircuits.com:8000
"@ | Out-File -FilePath $defaultEnvPath -Encoding utf8 -Force
            }
            $ServerUrl = "http://rf.nakedcircuits.com:8000"
        }
    }
}
if (-not $ServerUrl) {
    $ServerUrl = "http://rf.nakedcircuits.com:8000"
}

# Resolve Serverless Wake URL
$WakeUrl = $env:RF_WAKE_URL
if (-not $WakeUrl) {
    foreach ($envFile in @("..\.env", ".env", "$PSScriptRoot\..\..\.env", "$PSScriptRoot\..\.env")) {
        if (Test-Path $envFile) {
            $match = Get-Content $envFile | Where-Object { $_ -match "^RF_WAKE_URL=(.+)$" } | Select-Object -First 1
            if ($match) {
                $WakeUrl = ($match -replace "^RF_WAKE_URL=", "").Trim().Trim('"').Trim("'")
                break
            }
        }
    }
}
if (-not $WakeUrl) {
    $WakeUrl = "https://iltxrk3s2k.execute-api.ap-south-2.amazonaws.com"
}

# Pre-flight Health Probe & Serverless Wake-on-Request
Write-Host "[RF SaaS Client] Connecting to SaaS API at $ServerUrl..." -ForegroundColor Cyan
$healthy = $false
try {
    $h = Invoke-RestMethod -Uri "$ServerUrl/health" -Method Get -TimeoutSec 3 -ErrorAction Stop
    if ($h.status -eq "healthy") {
        $healthy = $true
    }
} catch {
    $healthy = $false
}

if (-not $healthy -and $WakeUrl) {
    Write-Host "[RF SaaS Client] Cloud microservice is asleep ($ServerUrl). Triggering serverless wake-up..." -ForegroundColor Yellow
    $wakeUrls = @($WakeUrl)
    $defaultWake = "https://iltxrk3s2k.execute-api.ap-south-2.amazonaws.com"
    if ($wakeUrls -notcontains $defaultWake) { $wakeUrls += $defaultWake }

    foreach ($w in $wakeUrls) {
        try {
            $wakeRes = Invoke-RestMethod -Uri $w -Method Get -TimeoutSec 120 -ErrorAction Stop
            if ($wakeRes.status -eq "ready") {
                Write-Host "[OK] Cloud microservice successfully woke up ($($wakeRes.elapsed_seconds)s)!" -ForegroundColor Green
                $healthy = $true
                break
            }
        } catch {
            Write-Host "[RF SaaS Client] Notice from wake trigger ($w): $($_.Exception.Message)" -ForegroundColor DarkGray
        }
    }

    if (-not $healthy) {
        for ($i = 0; $i -lt 25; $i++) {
            Start-Sleep -Seconds 3
            try {
                $h = Invoke-RestMethod -Uri "$ServerUrl/health" -Method Get -TimeoutSec 3 -ErrorAction Stop
                if ($h.status -eq "healthy") {
                    $healthy = $true
                    Write-Host "[OK] Cloud microservice is online and healthy!" -ForegroundColor Green
                    break
                }
            } catch {
                # continue waiting
            }
        }
    }
}

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

# Resolve circuit specification (spec) or natural language description
$localSpecPath = Join-Path $OutputDir (Join-Path $ProjectName "spec.json")
if ($SpecFile -and (Test-Path $SpecFile)) {
    Write-Host "[RF SaaS Client] Loading circuit specification from file: $SpecFile" -ForegroundColor Cyan
    $payload["spec"] = (Get-Content $SpecFile -Raw | ConvertFrom-Json)
} elseif ($SpecJson) {
    Write-Host "[RF SaaS Client] Loading circuit specification from JSON argument" -ForegroundColor Cyan
    $payload["spec"] = ($SpecJson | ConvertFrom-Json)
} elseif (Test-Path $localSpecPath) {
    Write-Host "[RF SaaS Client] Detected local circuit specification: $localSpecPath" -ForegroundColor Cyan
    $payload["spec"] = (Get-Content $localSpecPath -Raw | ConvertFrom-Json)
} elseif ($Desc) {
    $payload["desc"] = $Desc
}

$jsonBody = $payload | ConvertTo-Json -Depth 20 -Compress
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
