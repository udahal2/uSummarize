<#
Copyright Ujjwol © 2025
This script automates the management of the deepsearcher project,
including running, updating, and exiting applications.
Optimized for efficiency and enhanced with caching and additional functionality.
#>

param(
    $rule = "default"
)

$MAIN = "deepsearcher.runner"
$CP_DELIM = ";"
if ($IsMacOS -or $IsLinux) {
    $CP_DELIM = ":" 
}

$cacheFile = ".build_cache.json"

function Get-CurrentBranch {
    return (git rev-parse --abbrev-ref HEAD)
}

function CacheBuildInfo {
    param ([string]$branch)
    @{ LastSuccessfulBranch = $branch } | ConvertTo-Json | Set-Content -Path $cacheFile -Encoding UTF8
}

function GetCachedBuildInfo {
    if (Test-Path $cacheFile) {
        return (Get-Content -Path $cacheFile -Raw | ConvertFrom-Json).LastSuccessfulBranch
    }
    return $null
}

if ($rule -eq "default") {
    Write-Output "Default rule: Running update and then launching deepsearcher."
    & $MyInvocation.MyCommand.Path "update"
    & $MyInvocation.MyCommand.Path "run"
}

elseif ($rule -eq "update") {
    Write-Output "Updating deepsearcher..."
    git add .
    $commitMessage = if ($args.Length -gt 0) { $args[0] } else { "updated deepsearcher" }
    git commit -m "$commitMessage"
    git pull origin $(Get-CurrentBranch)
    git push origin $(Get-CurrentBranch)
    CacheBuildInfo -branch (Get-CurrentBranch)
}

elseif ($rule -eq "run") {
    Write-Output "Running deepsearcher..."
    if (Test-Path "requirements.txt") {
        Write-Output "Installing dependencies..."
        python -m venv venv
        .\venv\Scripts\activate
        pip install -r requirements.txt
    }
    Write-Output "Starting deepsearcher OCR pipeline..."
    python -m deepsearcher.runner
    Start-Process "cmd.exe" -ArgumentList "/c start http://localhost:10000"
}

elseif ($rule -eq "exit") {
    Write-Output "Stopping deepsearcher services..."
    Get-Process | Where-Object { $_.ProcessName -match "gunicorn" } | Stop-Process -Force
    Write-Output "Exiting script. Goodbye!"
}

elseif ($rule -eq "CTLFS") {
    Write-Output "Checking last successful branch..."
    $lastBranch = GetCachedBuildInfo
    if ($lastBranch) {
        Write-Output "Switching to last successful branch: $lastBranch"
        git checkout $lastBranch
        git pull origin $lastBranch
    } else {
        Write-Output "No cached branch found."
    }
}

else {
    Write-Output "build: *** No rule to make target '$rule'. Stop."
}
