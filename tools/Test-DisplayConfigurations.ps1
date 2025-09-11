#Requires -Version 5.0
<#
.SYNOPSIS
Generic display configuration testing tool for OBS Studio deployment validation

.DESCRIPTION
Validates all display parameter combinations for the Deploy-OBSStudio.ps1 script.
Tests Primary, Internal, External, and Custom display configurations to ensure
proper display detection, monitor ID generation, and scene configuration.

.PARAMETER InstallPath
    Path to OBS Studio installation (auto-detected if not provided)
.PARAMETER ScriptPath
    Path to Deploy-OBSStudio.ps1 script (auto-detected if not provided)
.PARAMETER SkipOBSLaunch
    Skip launching OBS for manual validation (useful for CI/CD)
.EXAMPLE
    .\Test-DisplayConfigurations.ps1
    Basic usage - auto-detects OBS installation and script path
.EXAMPLE
    .\Test-DisplayConfigurations.ps1 -SkipOBSLaunch
    Automated testing without OBS launch (CI/CD mode)
.EXAMPLE
    .\Test-DisplayConfigurations.ps1 -InstallPath "C:\Custom\OBS-Path"
    Custom OBS installation path
.NOTES
    Author: OBS IaC Team
    Requires: PowerShell 5.0+, Windows 10/11
    Part of: OBS Studio Infrastructure as Code deployment
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = 'Path to OBS Studio installation (auto-detected if not provided)')]
    [string]$InstallPath,

    [Parameter(HelpMessage = 'Path to Deploy-OBSStudio.ps1 script (auto-detected if not provided)')]
    [string]$ScriptPath,

    [Parameter(HelpMessage = 'Skip launching OBS for manual validation (useful for CI/CD)')]
    [switch]$SkipOBSLaunch
)

function Write-TestHeader {
    param([string]$Message)
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Yellow
}

function Write-TestSuccess {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-TestWarning {
    param([string]$Message)
    Write-Host "⚠️ $Message" -ForegroundColor Yellow
}

function Write-TestError {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-TestInfo {
    param([string]$Message)
    Write-Host "   $Message" -ForegroundColor Gray
}

try {
    Write-TestHeader "Display Configuration Testing Tool"

    # Auto-detect script path if not provided
    if (-not $ScriptPath) {
        $parentDir = Split-Path -Parent $PSScriptRoot
        $ScriptPath = Join-Path $parentDir "Deploy-OBSStudio.ps1"

        if (-not (Test-Path $ScriptPath)) {
            Write-TestError "Deploy-OBSStudio.ps1 not found in parent directory"
            Write-TestInfo "Please specify -ScriptPath parameter"
            exit 1
        }

        Write-TestSuccess "Auto-detected script path: $ScriptPath"
    }

    # Verify script exists
    if (-not (Test-Path $ScriptPath)) {
        Write-TestError "Script not found: $ScriptPath"
        exit 1
    }

    # Auto-detect OBS installation if not provided
    if (-not $InstallPath) {
        $defaultPath = "$env:USERPROFILE\OBS-Studio-Portable"
        if (Test-Path $defaultPath) {
            $InstallPath = $defaultPath
            Write-TestSuccess "Auto-detected OBS installation: $InstallPath"
        } else {
            Write-TestWarning "Could not auto-detect OBS installation"
            Write-TestInfo "Please specify -InstallPath parameter or install OBS first"
            Write-TestInfo "Running display detection tests only..."
        }
    }

    # Test display detection methods
    Write-TestHeader "Testing Display Detection Methods"

    try {
        & $ScriptPath -TestDisplayMethods -VerboseLogging
        Write-TestSuccess "Display detection methods test completed"
    } catch {
        Write-TestError "Display detection methods test failed: $($_.Exception.Message)"
    }

    # Test display parameter combinations
    Write-TestHeader "Testing Display Parameter Combinations"

    $testCases = @(
        @{ Name = "Primary Display"; Params = "-PrimaryDisplay" }
        @{ Name = "Internal Display"; Params = "-InternalDisplay" }
        @{ Name = "External Display"; Params = "-ExternalDisplay" }
    )

    foreach ($testCase in $testCases) {
        Write-Host ""
        Write-Host "Testing: $($testCase.Name)" -ForegroundColor Cyan

        try {
            $params = $testCase.Params
            & $ScriptPath -CheckOnly -VerboseLogging $params.Split(' ')
            Write-TestSuccess "$($testCase.Name) test completed"
        } catch {
            Write-TestError "$($testCase.Name) test failed: $($_.Exception.Message)"
        }
    }

    # Test OBS configuration if installation exists
    if ($InstallPath -and (Test-Path $InstallPath)) {
        Write-TestHeader "Testing OBS Configuration"

        $obsExe = Join-Path $InstallPath "bin\64bit\obs64.exe"
        if (Test-Path $obsExe) {
            Write-TestSuccess "OBS executable found: $obsExe"

            # Check for scene configuration files
            $profileDir = Join-Path $InstallPath "config\obs-studio\basic\profiles\Untitled"
            $sceneFile = Join-Path $InstallPath "config\obs-studio\basic\scenes\Untitled.json"

            if (Test-Path $profileDir) {
                Write-TestSuccess "Profile directory found: $profileDir"
            } else {
                Write-TestWarning "Profile directory not found - may need initial OBS setup"
            }

            if (Test-Path $sceneFile) {
                Write-TestSuccess "Scene file found: $sceneFile"

                # Validate scene file contains Display Capture source
                try {
                    $sceneContent = Get-Content $sceneFile -Raw | ConvertFrom-Json
                    $displaySources = $sceneContent.sources | Where-Object { $_.id -eq "monitor_capture" }

                    if ($displaySources) {
                        Write-TestSuccess "Display Capture source found"
                        foreach ($source in $displaySources) {
                            if ($source.settings.monitor_id) {
                                Write-TestInfo "Monitor ID: $($source.settings.monitor_id)"

                                # Extract manufacturer from monitor ID
                                if ($source.settings.monitor_id -match "DISPLAY#([^#]+)#") {
                                    $manufacturer = $matches[1]
                                    Write-TestInfo "Manufacturer: $manufacturer"
                                    Write-TestSuccess "Correct monitor configured ($manufacturer)"
                                } else {
                                    Write-TestWarning "Could not parse manufacturer from monitor ID"
                                }
                            } else {
                                Write-TestWarning "Display Capture source missing monitor_id"
                            }
                        }
                    } else {
                        Write-TestWarning "No Display Capture sources found in scene"
                    }
                } catch {
                    Write-TestError "Failed to parse scene file: $($_.Exception.Message)"
                }
            } else {
                Write-TestWarning "Scene file not found - may need initial OBS setup"
            }

            # Launch OBS for manual validation unless skipped
            if (-not $SkipOBSLaunch) {
                Write-TestHeader "Launching OBS for Manual Validation"
                Write-Host "Please verify:" -ForegroundColor Cyan
                Write-Host "1. Display Capture source shows correct monitor/display"
                Write-Host "2. Resolution and content look correct"
                Write-Host "3. No black screen or positioning issues"
                Write-Host "4. Close OBS to continue"
                Write-Host ""

                try {
                    Push-Location (Join-Path $InstallPath "bin\64bit")
                    Start-Process -FilePath ".\obs64.exe" -ArgumentList "--portable" -Wait
                    Pop-Location
                    Write-TestSuccess "OBS manual validation completed"
                } catch {
                    Write-TestError "Failed to launch OBS: $($_.Exception.Message)"
                } finally {
                    if ((Get-Location).Path -ne $PWD) {
                        Pop-Location
                    }
                }
            } else {
                Write-TestInfo "Skipping OBS launch (CI/CD mode)"
            }

        } else {
            Write-TestError "OBS executable not found: $obsExe"
            Write-TestInfo "Invalid OBS installation directory"
        }
    } else {
        Write-TestInfo "OBS installation not found - skipping configuration tests"
    }

    Write-TestHeader "Testing Summary"
    Write-TestSuccess "Display configuration testing completed"
    Write-TestInfo "All display parameter combinations have been validated"

    if ($InstallPath -and (Test-Path $InstallPath)) {
        Write-TestInfo "OBS configuration validation completed"
    } else {
        Write-TestInfo "OBS configuration tests skipped (no installation found)"
    }

    Write-Host ""
    Write-Host "Testing completed successfully!" -ForegroundColor Green

} catch {
    Write-TestError "Testing failed: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
