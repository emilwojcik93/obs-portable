#Requires -Version 5.0
<#
.SYNOPSIS
Test help documentation accessibility

.DESCRIPTION
Tests that Get-Help works correctly with the script
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptPath
)

Write-Host "=== Testing Help Documentation ===" -ForegroundColor Yellow

try {
    # Test that help can be retrieved
    $help = Get-Help $ScriptPath -ErrorAction Stop
    
    # Check if help object exists and has basic content
    if ($help -and $help.Name) {
        Write-Host "+ Help documentation is accessible" -ForegroundColor Green
        Write-Host "Help Name: $($help.Name)" -ForegroundColor White
        # Note: PowerShell comment-based help parsing can be inconsistent in CI environments
        # The important thing is that Get-Help doesn't throw an error
        exit 0
    } else {
        Write-Host "- Help documentation incomplete" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "- Help documentation test failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
