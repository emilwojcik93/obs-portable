# Troubleshooting Guide - Common Issues and Solutions

## Development History and Lessons Learned

### 1. Parameter Naming Conflicts
**Issue**: `Check` and `WhatIf` are reserved PowerShell parameters
**Solution**: 
- Renamed `Check` → `CheckOnly`
- Use built-in `SupportsShouldProcess` for `WhatIf` functionality
**Code Fix**: `[CmdletBinding(SupportsShouldProcess)]`

### 2. OBS Configuration Wizard Bypass Attempts
**Issue**: Attempted to programmatically bypass OBS Auto-Configuration Wizard
**Problem**: OBS has robust first-run detection mechanisms
**Solution**: Interactive first-time setup approach
- Script launches OBS for user to complete wizard
- User completes wizard and adds Display Capture source
- Script then optimizes the existing configuration files
**Lesson**: Respect application's internal configuration mechanisms

### 3. Working Directory Dependencies
**Issue**: OBS failing to start from scheduled tasks
**Root Cause**: OBS needs to run from `bin\64bit` directory for dependency resolution
**Solution**: Proper `Push-Location`/`Pop-Location` handling
```powershell
# Correct implementation
$obsExeDir = Join-Path $OBSPath "bin\64bit"
Push-Location $obsExeDir
Start-Process -FilePath ".\obs64.exe" -WorkingDirectory $obsExeDir
Pop-Location
```

### 4. Scheduled Task Permission Issues
**Issue**: Dynamic task creation failing in service scripts
**Root Cause**: Service scripts lack admin privileges for task creation
**Solution**: Use PowerShell background jobs for auto-stop timer
```powershell
# Background job approach (no admin required)
Start-Job -ScriptBlock {
    Start-Sleep -Seconds (2 * 60 * 60)  # 2 hours
    & $ServiceScriptPath -Action AutoStop
} | Out-Null
```

### 5. Display Resolution Detection Issues
**Issue**: Detecting 1280x800 instead of 1920x1200 for primary display
**Root Cause**: DPI scaling affecting System.Windows.Forms.Screen
**Solution**: Multi-method resolution detection with scaling factor correction
```powershell
# DPI scaling detection and correction
if ($screen.Primary -and $actualWidth -lt 1600) {
    $possibleScales = @(1.25, 1.5, 1.75, 2.0)
    foreach ($scale in $possibleScales) {
        $scaledWidth = [math]::Round($actualWidth * $scale)
        if ($scaledWidth -eq 1920) {
            $actualWidth = $scaledWidth
            break
        }
    }
}
```

### 6. Monitor Manufacturer Detection
**Issue**: WMI monitor detection returning empty results
**Root Cause**: Strict filtering skipping monitors without complete EDID data
**Solution**: Robust error handling with fallback methods
```powershell
# Improved WMI monitor detection
try {
    if ($monitor.UserFriendlyName -and $monitor.UserFriendlyName.Length -gt 0) {
        $monModel = ([System.Text.Encoding]::ASCII.GetString($monitor.UserFriendlyName)).Replace("$([char]0x0000)", "")
    }
} catch { 
    $monModel = $null 
}

# Only skip if absolutely no useful data
if (-not $monModel -and $monManufacturer -eq "UNK") { continue }
```

### 7. Unicode Character Issues
**Issue**: `→` and `✓` characters causing display problems in PowerShell
**Solution**: Replace with ASCII equivalents
- `→` → `->` 
- `✓` → `+`
- Use Unicode only in markdown documentation

### 8. Configuration File Modification
**Issue**: OBS settings not being applied despite script claiming success
**Root Cause**: Incorrect parameter names or missing configuration sections
**Solution**: Comprehensive configuration modification with verification
```powershell
# Critical OBS video settings
$config = $config -replace "BaseCX=.*", "BaseCX=$baseWidth"
$config = $config -replace "BaseCY=.*", "BaseCY=$baseHeight"
$config = $config -replace "OutputCX=.*", "OutputCX=$outputWidth"
$config = $config -replace "OutputCY=.*", "OutputCY=$outputHeight"

# Verify settings were applied
$verifyConfig = Get-Content -Path $profilePath -Raw
$actualBaseCX = if ($verifyConfig -match "BaseCX=(\d+)") { $matches[1] } else { "Not Set" }
```

## Performance Optimization Troubleshooting

### Encoder Overload Issues

#### Problem: Severe Encoder Overload on Intel Integrated Graphics
**Symptoms**: Persistent "encoding overloaded" warnings despite optimization
**Root Cause**: Hardware insufficient for selected resolution/bitrate combination
**Solutions**:
1. **Use Extreme Performance Mode**: `-PerformanceMode 33` (33% scaling)
2. **Lower Resolution Further**: 634x396 from 1920x1200
3. **Reduce Bitrate**: 1500 kbps for Intel QuickSync
4. **Lower FPS**: 24fps instead of 30fps
5. **Minimize Audio**: 64 kbps audio bitrate

#### Problem: DisplayLink Devices Listed as GPUs
**Issue**: USB docking stations appearing as graphics adapters
**Solution**: Filter out DisplayLink devices
```powershell
if ($gpu.Name -match "DisplayLink") {
    Write-Info "USB Display Adapter: $($gpu.Name) (docking station/USB-C hub)"
    continue
}
```

## Display Selection Troubleshooting

### Multi-Display Detection Issues

#### Problem: Script Reports "Only 1 display detected" when 2 exist
**Root Cause**: Inconsistent display array population
**Debugging**: Add debug output to verify counts
```powershell
Write-Info "DEBUG: displays.Count = $($displays.Count), screens.Count = $($screens.Count)"
```
**Solution**: Ensure display processing loop completes for all screens

#### Problem: Manufacturer Detection Returning "Unknown"
**Root Cause**: WMI monitor data not being matched with screen objects
**Solution**: Improved monitor matching logic
```powershell
# Use first available monitor with valid data
$monitor = $monitorInfo | Where-Object { 
    $_.Name -and $_.Name -ne "" -and 
    $_.Manufacturer -and $_.Manufacturer -ne "" 
} | Select-Object -First 1
```

## Service and Task Management

### Scheduled Task Creation Issues
**Problem**: Tasks not being created or not working properly
**Root Cause**: Incorrect working directory or insufficient permissions
**Solutions**:
1. **Admin Rights Check**: Verify admin rights before task creation
2. **Working Directory**: Set correct working directory for OBS executable
3. **Task Folder Organization**: Use dedicated "OBS" folder in Task Scheduler

### Background Job Management
**Benefit**: No admin rights required for auto-stop timer
**Implementation**: PowerShell background jobs instead of dynamic scheduled tasks
**Cleanup**: Properly clean up background jobs on script exit

## Configuration Verification

### File Location Issues
**Problem**: Configuration files not found or in wrong location
**Check**: Verify OBS portable mode is properly configured
```powershell
# Ensure portable_mode.txt exists
$portableModeFile = Join-Path $InstallPath "portable_mode.txt"
if (-not (Test-Path $portableModeFile)) {
    Set-Content -Path $portableModeFile -Value "" -Encoding UTF8
}
```

### Settings Not Persisting
**Problem**: Settings revert after OBS restart
**Root Cause**: Configuration modified before OBS creates complete configuration
**Solution**: Wait for OBS wizard completion, then modify existing configuration

## Common User Issues

### Admin Rights Requirements
**Issue**: Users confused about when admin rights are needed
**Solution**: Clear messaging and helpful guidance
```powershell
if (-not (Test-AdminRights) -and $InstallScheduledTasks) {
    Show-AdminCommand -CurrentCommand $reconstructedCommand
}
```

### Display Selection Confusion
**Issue**: Users unsure which display to select in multi-display setups
**Solution**: 
- Auto-select single displays
- 10-second timeout with auto-select primary
- Clear display information (manufacturer, resolution, position)

These troubleshooting patterns represent real-world issues encountered during development and their battle-tested solutions.
