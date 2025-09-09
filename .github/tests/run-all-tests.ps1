#Requires -Version 5.0
<#
.SYNOPSIS
Run all CI tests locally

.DESCRIPTION
Runs all the CI test scripts locally for development and debugging
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ScriptPath = ".\Deploy-OBSStudio.ps1"
)

$ErrorActionPreference = "Continue"
$scriptsPath = ".github/scripts"

Write-Host "=======================================" -ForegroundColor Magenta
Write-Host "    Local CI Test Runner" -ForegroundColor Magenta  
Write-Host "=======================================" -ForegroundColor Magenta
Write-Host ""

# Check if main script exists
if (-not (Test-Path $ScriptPath)) {
    Write-Host "- Main script not found: $ScriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "Testing script: $ScriptPath" -ForegroundColor Cyan
Write-Host ""

$testResults = @{}

# Test 1: Script Syntax
Write-Host "1/5: Testing Script Syntax..." -ForegroundColor Yellow
try {
    & "$scriptsPath/test-script-syntax.ps1" -ScriptPath $ScriptPath
    $testResults["Syntax"] = "PASS"
} catch {
    $testResults["Syntax"] = "FAIL"
}
Write-Host ""

# Test 2: CheckOnly Mode
Write-Host "2/5: Testing CheckOnly Mode..." -ForegroundColor Yellow
try {
    & "$scriptsPath/test-checkonly-mode.ps1" -ScriptPath $ScriptPath
    $testResults["CheckOnly"] = "PASS"
} catch {
    $testResults["CheckOnly"] = "FAIL"
}
Write-Host ""

# Test 3: Performance Modes
Write-Host "3/5: Testing Performance Modes..." -ForegroundColor Yellow
try {
    & "$scriptsPath/test-performance-modes.ps1" -ScriptPath $ScriptPath
    $testResults["Performance"] = "PASS"
} catch {
    $testResults["Performance"] = "FAIL"
}
Write-Host ""

# Test 4: Help Documentation
Write-Host "4/5: Testing Help Documentation..." -ForegroundColor Yellow
try {
    & "$scriptsPath/test-help-documentation.ps1" -ScriptPath $ScriptPath
    $testResults["Help"] = "PASS"
} catch {
    $testResults["Help"] = "FAIL"
}
Write-Host ""

# Test 5: OBS Version Detection
Write-Host "5/5: Testing OBS Version Detection..." -ForegroundColor Yellow
try {
    & "$scriptsPath/test-obs-version.ps1"
    $testResults["Version"] = "PASS"
} catch {
    $testResults["Version"] = "FAIL"
}
Write-Host ""

# Summary
Write-Host "=======================================" -ForegroundColor Magenta
Write-Host "    Test Results Summary" -ForegroundColor Magenta
Write-Host "=======================================" -ForegroundColor Magenta

$passCount = 0
$totalCount = $testResults.Count

foreach ($test in $testResults.GetEnumerator()) {
    $status = $test.Value
    $color = if ($status -eq "PASS") { "Green" } else { "Red" }
    $symbol = if ($status -eq "PASS") { "+" } else { "-" }
    
    Write-Host "$symbol $($test.Key): $status" -ForegroundColor $color
    if ($status -eq "PASS") { $passCount++ }
}

Write-Host ""
Write-Host "Results: $passCount/$totalCount tests passed" -ForegroundColor $(if ($passCount -eq $totalCount) { "Green" } else { "Yellow" })

if ($passCount -eq $totalCount) {
    Write-Host "+ All tests passed! Ready for commit." -ForegroundColor Green
    exit 0
} else {
    Write-Host "- Some tests failed. Please fix issues before committing." -ForegroundColor Red
    exit 1
}
