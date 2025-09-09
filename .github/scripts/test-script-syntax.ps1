#Requires -Version 5.0
<#
.SYNOPSIS
Test PowerShell script syntax validation

.DESCRIPTION
Validates that Deploy-OBSStudio.ps1 has correct PowerShell syntax
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptPath
)

Write-Host "=== Testing PowerShell Script Syntax ===" -ForegroundColor Yellow

try {
    # Test script syntax without execution
    $null = Get-Command $ScriptPath -Syntax -ErrorAction Stop
    Write-Host "+ Script syntax is valid" -ForegroundColor Green
    exit 0
} catch {
    Write-Host "- Script syntax error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
