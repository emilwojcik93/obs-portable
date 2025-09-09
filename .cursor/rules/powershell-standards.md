# PowerShell Coding Standards

## MANDATORY Variable Bracketing Rules

### Critical: Special Characters Require Brackets
```powershell
# ✅ CORRECT - Always use brackets with special characters
Write-Host "Progress: ${progress}%" -ForegroundColor Cyan
$logPath = "${env:TEMP}\OBS-Setup-${timestamp}.log"
$registryPath = "HKCU:\Software\${appName}:Settings"
$downloadUrl = "https://api.github.com/repos/${owner}/${repo}/releases"

# ❌ WRONG - Causes parsing errors
Write-Host "Progress: $progress%" -ForegroundColor Cyan  # % causes issues
$logPath = "$env:TEMP\OBS-Setup-$timestamp.log"        # \ can cause issues
$registryPath = "HKCU:\Software\$appName:Settings"      # : causes parsing errors
```

### Special Characters Requiring Brackets
- **Percentage signs**: `${var}%` instead of `$var%`
- **Colons**: `${var}:` instead of `$var:`
- **Path separators**: `${var}\` instead of `$var\`
- **URL components**: `${var}/` instead of `$var/`
- **File extensions**: `${var}.log` instead of `$var.log`
- **Hyphens in paths**: `${var}-suffix` instead of `$var-suffix`

## Character Encoding Requirements

### PowerShell Scripts (.ps1) - ASCII/UTF-8 ONLY
```powershell
# ✅ CORRECT - ASCII/UTF-8 characters only
Write-Host "Setup completed successfully!" -ForegroundColor Green
$status = "OK"

# ❌ WRONG - No Unicode characters in PowerShell
Write-Host "Setup completed successfully! ✅" -ForegroundColor Green  # Don't use ✅
$status = "✓"  # Don't use ✓
```

### Configuration Files - ASCII/UTF-8 ONLY
- No Unicode symbols in `.ps1`, `.psm1`, `.psd1`, or configuration files
- Use standard ASCII characters for all code, comments, and string literals
- Avoid emoji, special Unicode symbols, or non-ASCII characters

## PowerShell Best Practices

### Function Naming
```powershell
# ✅ CORRECT - Use approved PowerShell verbs
function Get-SystemConfiguration { }
function Set-OBSConfiguration { }
function Test-Environment { }
function New-ScheduledTask { }
function Remove-OBSDeployment { }

# ❌ WRONG - Non-standard verbs
function Retrieve-SystemConfiguration { }  # Use Get-
function Configure-OBS { }                 # Use Set-
function Check-Environment { }             # Use Test-
```

### Parameter Validation
```powershell
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$false, HelpMessage="Performance optimization level")]
    [ValidateSet("33", "50", "60", "75", "90")]
    [string]$PerformanceMode = "60",
    
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$InstallPath = "${env:USERPROFILE}\OBS-Studio-Portable",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)
```

### Error Handling
```powershell
# Always use try/catch for external operations
try {
    $response = Invoke-RestMethod -Uri $apiUrl -TimeoutSec 30
    Write-Success "API call successful"
} catch {
    Write-Error "API call failed: $($_.Exception.Message)"
    throw
} finally {
    # Cleanup operations
}
```

### Logging Standards
```powershell
# Use consistent logging functions
function Write-Info { param([string]$Message) Write-Host $Message -ForegroundColor Cyan }
function Write-Success { param([string]$Message) Write-Host $Message -ForegroundColor Green }
function Write-Warning { param([string]$Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Error { param([string]$Message) Write-Host $Message -ForegroundColor Red }
```

### Path Handling
```powershell
# Always use Join-Path for cross-platform compatibility
$configPath = Join-Path $installPath "config"
$logFile = Join-Path $logPath "Setup-${timestamp}.log"

# Test paths before using
if (-not (Test-Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath -Force | Out-Null
}
```

## Script Structure Standards

### Header Template
```powershell
#Requires -Version 5.0
<#
.SYNOPSIS
    Brief description of script purpose
.DESCRIPTION
    Detailed description including IaC context
.PARAMETER ParameterName
    Description of each parameter with examples
.EXAMPLE
    .\Script.ps1 -Parameter "Value"
    Description of what this example does
.NOTES
    Author: [Author Name]
    Version: [Version Number]
    Requires: PowerShell 5.0+, Windows OS
    IaC Context: Infrastructure automation for [purpose]
#>
```

### Main Execution Pattern
```powershell
[CmdletBinding(SupportsShouldProcess)]
param(
    # Parameters here
)

$ErrorActionPreference = "Stop"

# Main execution with proper error handling
try {
    # Step-by-step execution with logging
    Write-Info "Starting infrastructure deployment"
    
    # Your main logic here
    
    Write-Success "Infrastructure deployment completed successfully!"
    
} catch {
    Write-Error "Infrastructure deployment failed: $($_.Exception.Message)"
    Write-Info "Error details: $($_.ScriptStackTrace)"
    exit 1
} finally {
    # Cleanup operations
}
```

## Testing and Validation

### Support Multiple Execution Modes
```powershell
# Always support WhatIf and CheckOnly modes
if ($WhatIfPreference) {
    Write-Info "[WHATIF] Would perform action: $action"
    return
}

if ($CheckOnly) {
    Write-Info "[CHECK] Validating prerequisites only"
    # Validation logic only
    return
}

# Normal execution
```

### Idempotent Operations
```powershell
# Check current state before making changes
if (Test-Path $targetFile) {
    $currentVersion = Get-FileVersion $targetFile
    if ($currentVersion -eq $expectedVersion) {
        Write-Info "File already up to date"
        return
    }
}

# Proceed with update only if needed
```

## Performance and Security

### Secure Operations
```powershell
# Validate all user inputs
if (-not (Test-Path $UserProvidedPath)) {
    Write-Error "Invalid path provided: $UserProvidedPath"
    exit 1
}

# Use secure download methods
$response = Invoke-RestMethod -Uri $downloadUrl -TimeoutSec 30 -UseBasicParsing
```

### Efficient Resource Usage
```powershell
# Use efficient cmdlets and avoid unnecessary operations
$items = Get-ChildItem -Path $path -Filter "*.ps1" -Recurse
# Instead of: Get-ChildItem $path | Where-Object { $_.Extension -eq ".ps1" }

# Dispose of objects when appropriate
$object.Dispose()
```

## Repository-Specific Standards

### OBS Studio Working Directory
```powershell
# CRITICAL: OBS must be launched from bin\64bit directory
$obsExeDir = Join-Path $OBSPath "bin\64bit"
Push-Location $obsExeDir
Start-Process -FilePath ".\obs64.exe" -WorkingDirectory $obsExeDir
Pop-Location
```

### Performance Mode Implementation
```powershell
# Use switch statements for performance mode configuration
switch ($PerformanceMode) {
    "33" { 
        $bitrate = 1500
        $scaling = 0.33
        $description = "Extreme performance"
    }
    "50" { 
        $bitrate = 2500
        $scaling = 0.50
        $description = "Ultra-lightweight"
    }
    # ... etc
}
```

### Hardware Detection Patterns
```powershell
# Use consistent hardware detection patterns
$gpus = Get-CimInstance -ClassName Win32_VideoController | Where-Object { 
    $_.Status -eq "OK" -and $_.Name -notmatch "Microsoft Basic|Remote Desktop|DisplayLink" 
}

# Filter out non-GPU devices
if ($gpu.Name -match "DisplayLink") {
    Write-Info "USB Display Adapter: $($gpu.Name) (docking station/USB-C hub)"
    continue
}
```

These standards ensure consistent, maintainable, and professional PowerShell code throughout the OBS Studio IaC repository.
