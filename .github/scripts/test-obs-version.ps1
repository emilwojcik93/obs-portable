#Requires -Version 5.0
<#
.SYNOPSIS
Test OBS Studio version detection

.DESCRIPTION
Tests GitHub API access and OBS Studio version detection
#>

Write-Host "=== Testing OBS Studio Version Detection ===" -ForegroundColor Yellow

try {
    # Test GitHub API access for OBS Studio releases
    $apiUrl = "https://api.github.com/repos/obsproject/obs-studio/releases/latest"
    Write-Host "Fetching latest OBS Studio release from GitHub API..." -ForegroundColor Cyan
    
    $response = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
    $latestVersion = $response.tag_name
    
    if ($latestVersion) {
        Write-Host "+ OBS Studio version detection successful" -ForegroundColor Green
        Write-Host "Latest Version: $latestVersion" -ForegroundColor White
        
        # Set output for workflow
        Write-Output "VERSION_STATUS=PASS"
        Write-Output "OBS_VERSION=$latestVersion"
        exit 0
    } else {
        Write-Host "- Could not detect OBS Studio version" -ForegroundColor Red
        Write-Output "VERSION_STATUS=FAIL"
        Write-Output "VERSION_ERROR=No version found in API response"
        exit 1
    }
    
} catch {
    Write-Host "- OBS version detection failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Output "VERSION_STATUS=FAIL"
    Write-Output "VERSION_ERROR=$($_.Exception.Message)"
    exit 1
}
