#Requires -Version 5.0
<#
.SYNOPSIS
Generate comprehensive health report

.DESCRIPTION
Generates a comprehensive health report based on all test results
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptStatus,
    
    [Parameter(Mandatory = $true)]
    [string]$VersionStatus,
    
    [Parameter(Mandatory = $true)]
    [string]$DownloadStatus,
    
    [Parameter(Mandatory = $true)]
    [string]$PerformanceStatus,
    
    [Parameter(Mandatory = $false)]
    [string]$ObsVersion = "",
    
    [Parameter(Mandatory = $false)]
    [string]$DownloadSize = "",
    
    [Parameter(Mandatory = $false)]
    [string]$PerformancePassCount = "0",
    
    [Parameter(Mandatory = $false)]
    [string]$PerformanceTotalCount = "5"
)

Write-Host ""
Write-Host "=== Weekly Infrastructure Health Report ===" -ForegroundColor Magenta
Write-Host ""

# Script functionality
Write-Host "Script Functionality: $ScriptStatus" -ForegroundColor $(if($ScriptStatus -eq 'PASS'){'Green'}else{'Red'})

# OBS version detection
Write-Host "OBS Version Detection: $VersionStatus" -ForegroundColor $(if($VersionStatus -eq 'PASS'){'Green'}else{'Red'})
if ($ObsVersion) {
    Write-Host "   Latest OBS Version: $ObsVersion" -ForegroundColor White
}

# Download link availability
Write-Host "Download Link: $DownloadStatus" -ForegroundColor $(if($DownloadStatus -eq 'PASS'){'Green'}else{'Red'})
if ($DownloadSize) {
    Write-Host "   Download Size: $DownloadSize MB" -ForegroundColor White
}

# Performance modes
Write-Host "Performance Modes: $PerformanceStatus ($PerformancePassCount/$PerformanceTotalCount)" -ForegroundColor $(if($PerformanceStatus -eq 'PASS'){'Green'}else{'Red'})

Write-Host ""

# Overall health assessment
$allPassed = ($ScriptStatus -eq 'PASS') -and ($VersionStatus -eq 'PASS') -and ($DownloadStatus -eq 'PASS') -and ($PerformanceStatus -eq 'PASS')

if ($allPassed) {
    Write-Host "Overall Health Status: EXCELLENT" -ForegroundColor Green
    Write-Host "+ All infrastructure components are functioning correctly" -ForegroundColor Green
    Write-Host "+ OBS Studio integration is stable and up-to-date" -ForegroundColor Green
    Write-Host "+ Remote execution capabilities are verified" -ForegroundColor Green
} else {
    Write-Host "Overall Health Status: NEEDS ATTENTION" -ForegroundColor Yellow
    Write-Host "Some components require investigation" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next health check: $(Get-Date (Get-Date).AddDays(7) -Format 'yyyy-MM-dd')" -ForegroundColor Gray

# Generate health status data
$healthData = @{
    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
    overallStatus = if ($allPassed) { "EXCELLENT" } else { "NEEDS_ATTENTION" }
    scriptStatus = $ScriptStatus
    versionStatus = $VersionStatus
    downloadStatus = $DownloadStatus
    performanceStatus = $PerformanceStatus
    obsVersion = $ObsVersion
}

$healthData | ConvertTo-Json | Out-File -FilePath "health-status.json" -Encoding UTF8
Write-Host "+ Health status data generated" -ForegroundColor Green
