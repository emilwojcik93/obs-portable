#Requires -Version 5.0
<#
.SYNOPSIS
Generate release notes from template

.DESCRIPTION
Generates release notes by reading template file and replacing version placeholder
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptPath,
    
    [Parameter(Mandatory = $true)]
    [string]$TemplateFile,
    
    [Parameter(Mandatory = $true)]
    [string]$OutputFile
)

Write-Host "=== Generating Release Notes ===" -ForegroundColor Yellow

try {
    # Extract version from PowerShell script
    $scriptContent = Get-Content $ScriptPath -Raw
    $versionMatch = $scriptContent | Select-String -Pattern "Version: (\d+\.\d+)" 
    
    if ($versionMatch) {
        $version = $versionMatch.Matches[0].Groups[1].Value
        Write-Host "Detected version: $version" -ForegroundColor Green
    } else {
        $version = "2.0"
        Write-Host "No version found, using default: $version" -ForegroundColor Yellow
    }
    
    # Read template file
    if (-not (Test-Path $TemplateFile)) {
        Write-Host "- Template file not found: $TemplateFile" -ForegroundColor Red
        exit 1
    }
    
    $template = Get-Content $TemplateFile -Raw
    
    # Replace version placeholder
    $releaseNotes = $template -replace '\{VERSION\}', $version
    
    # Write release notes
    $releaseNotes | Out-File -FilePath $OutputFile -Encoding UTF8
    
    Write-Host "+ Release notes generated: $OutputFile" -ForegroundColor Green
    Write-Host "Version: $version" -ForegroundColor White
    
    # Output for workflow
    Write-Output "VERSION=$version"
    
} catch {
    Write-Host "- Failed to generate release notes: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
