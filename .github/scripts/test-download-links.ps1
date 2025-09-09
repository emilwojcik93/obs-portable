#Requires -Version 5.0
<#
.SYNOPSIS
Test OBS Studio download link availability

.DESCRIPTION
Tests that OBS Studio download links are accessible
#>

Write-Host "=== Testing OBS Studio Download Links ===" -ForegroundColor Yellow

try {
    # Test GitHub API access for OBS Studio releases
    $apiUrl = "https://api.github.com/repos/obsproject/obs-studio/releases/latest"
    Write-Host "Fetching latest OBS Studio release..." -ForegroundColor Cyan
    
    $response = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
    $windowsAsset = $response.assets | Where-Object { $_.name -like "*Windows-x64.zip" } | Select-Object -First 1
    
    if ($windowsAsset) {
        Write-Host "Found Windows asset: $($windowsAsset.name)" -ForegroundColor Cyan
        Write-Host "Testing download link accessibility..." -ForegroundColor Cyan
        
        # Test HEAD request to check if download link is accessible
        $headResponse = Invoke-WebRequest -Uri $windowsAsset.browser_download_url -Method Head -ErrorAction Stop
        
        if ($headResponse.StatusCode -eq 200) {
            # Get file size
            $contentLengthHeader = $headResponse.Headers["Content-Length"]
            $sizeBytes = if ($contentLengthHeader -is [array]) { [int64]$contentLengthHeader[0] } else { [int64]$contentLengthHeader }
            $sizeMB = [math]::Round($sizeBytes / 1MB, 2)
            
            Write-Host "+ Download link is accessible" -ForegroundColor Green
            Write-Host "File Size: $sizeMB MB" -ForegroundColor White
            
            # Set output for workflow
            Write-Output "DOWNLOAD_STATUS=PASS"
            Write-Output "DOWNLOAD_SIZE_MB=$sizeMB"
            exit 0
        } else {
            Write-Host "- Download link returned status: $($headResponse.StatusCode)" -ForegroundColor Red
            Write-Output "DOWNLOAD_STATUS=FAIL"
            Write-Output "DOWNLOAD_ERROR=HTTP $($headResponse.StatusCode)"
            exit 1
        }
    } else {
        Write-Host "- No Windows download asset found" -ForegroundColor Red
        Write-Output "DOWNLOAD_STATUS=FAIL"
        Write-Output "DOWNLOAD_ERROR=No Windows asset found"
        exit 1
    }
    
} catch {
    Write-Host "- Download link test failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Output "DOWNLOAD_STATUS=FAIL"
    Write-Output "DOWNLOAD_ERROR=$($_.Exception.Message)"
    exit 1
}
