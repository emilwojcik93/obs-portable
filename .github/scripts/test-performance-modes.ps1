#Requires -Version 5.0
<#
.SYNOPSIS
Test all performance mode parameters

.DESCRIPTION
Tests all performance modes (33, 50, 60, 75, 90) to ensure they work correctly
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptPath
)

Write-Host "=== Testing Performance Mode Parameters ===" -ForegroundColor Yellow

$modes = @("33", "50", "60", "75", "90")
$failed = $false

foreach ($mode in $modes) {
    try {
        Write-Host "Testing PerformanceMode ${mode}..." -ForegroundColor Cyan
        $logFile = "ci-perf-test-${mode}-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
        & $ScriptPath -CheckOnly -PerformanceMode $mode -PrimaryDisplay -LogToFile $logFile
        $result = Get-Content $logFile -ErrorAction SilentlyContinue
        Remove-Item $logFile -ErrorAction SilentlyContinue
        
        # Check for performance mode specific output (mode appears in parentheses with % sign)
        $hasCorrectMode = $result -match "Performance Mode:.*\(${mode}% scaling"
        
        if ($hasCorrectMode) {
            Write-Host "  + Mode ${mode}: PASS" -ForegroundColor Green
        } else {
            Write-Host "  - Mode ${mode}: FAIL" -ForegroundColor Red
            $failed = $true
        }
        
    } catch {
        Write-Host "  - Mode ${mode}: ERROR - $($_.Exception.Message)" -ForegroundColor Red
        $failed = $true
    }
}

if ($failed) {
    Write-Host "- Some performance modes failed testing" -ForegroundColor Red
    exit 1
} else {
    Write-Host "+ All performance modes tested successfully" -ForegroundColor Green
    exit 0
}
