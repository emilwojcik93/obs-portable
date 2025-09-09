# OBS Studio Specific Technical Knowledge

## Critical Technical Requirements

### 1. Working Directory Dependencies
**CRITICAL**: OBS Studio must be launched from the `bin\64bit` directory for proper dependency resolution:

```powershell
# ✅ CORRECT - Working directory handling
$obsExeDir = Join-Path $OBSPath "bin\64bit"
Push-Location $obsExeDir
Start-Process -FilePath ".\obs64.exe" -ArgumentList @("--portable", "--startrecording") -WorkingDirectory $obsExeDir
Pop-Location

# ❌ WRONG - Will cause dependency errors
Start-Process -FilePath "${OBSPath}\bin\64bit\obs64.exe" -WorkingDirectory $OBSPath
```

### 2. Configuration File Structure
OBS configuration is split across multiple files:
- **`global.ini`**: Global OBS settings, renderer, audio
- **`basic\profiles\Untitled\basic.ini`**: Profile-specific settings (encoder, bitrate, resolution)
- **Scene Collections**: Separate JSON files for scenes and sources

### 3. Interactive First-Time Setup Requirement
**IMPORTANT**: OBS requires interactive setup on first launch:
- Script launches OBS for user to complete Auto-Configuration Wizard
- User must complete wizard and add Display Capture source manually
- Script then optimizes the existing configuration files
- This approach respects OBS's internal configuration mechanisms

## Performance Optimization System

### 1. Unified PerformanceMode Parameter
```powershell
# Performance scaling levels (% of display resolution)
-PerformanceMode 33   # Extreme: 634x396 from 1920x1200, 1500 kbps, 24fps
-PerformanceMode 50   # Ultra: 960x600 from 1920x1200, 2500 kbps, 30fps
-PerformanceMode 60   # Default: 1152x720 from 1920x1200, 3000 kbps, 30fps
-PerformanceMode 75   # Optimized: 1440x900 from 1920x1200, 6000 kbps, 30fps
-PerformanceMode 90   # Standard: 1728x1080 from 1920x1200, 10000 kbps, 30fps
```

### 2. GPU-Specific Optimizations

#### Intel QuickSync
```powershell
# Extreme performance settings
$config += "`nQSVPreset=speed"
$config += "`nQSVTargetUsage=1"     # Fastest possible
$config += "`nQSVAsyncDepth=1"      # Minimal async depth
$config += "`nQSVBFrames=0"         # No B-frames
```

#### AMD AMF (Advanced Media Framework)
```powershell
# Based on AMF Options documentation
$config += "`nAMFPreAnalysis=true"   # Intelligent content analysis
$config += "`nAMFBFrames=0"          # Disable for performance
$config += "`nAMFEnforceHRD=false"   # Reduce overhead
$config += "`nAMFFillerData=false"   # Efficiency
$config += "`nAMFVBAQ=false"         # Speed priority
$config += "`nAMFLowLatency=true"    # Minimal delay
```

#### NVIDIA NVENC
```powershell
# Ultra-low latency settings
$config += "`nNVENCPreset=p1"        # Fastest preset
$config += "`nNVENCTuning=ull"       # Ultra-low latency
$config += "`nNVENCMultipass=disabled" # Single pass for speed
$config += "`nNVENCBFrames=0"        # No B-frames
```

## Hardware Detection System

### 1. Advanced Monitor Detection
Uses proven WMI methodology for accurate monitor identification:

```powershell
# Manufacturer hash table for friendly names
$ManufacturerHash = @{
    "PHL" = "Philips"; "SAM" = "Samsung"; "DEL" = "Dell";
    "LEN" = "Lenovo"; "HWP" = "HP"; # ... 50+ manufacturers
}

# WMI query for EDID information
$wmiMonitors = Get-WmiObject -Namespace "root\WMI" -Class "WMIMonitorID"
$manufacturer = ([System.Text.Encoding]::ASCII.GetString($monitor.ManufacturerName)).Replace("$([char]0x0000)", "")
$friendlyName = $ManufacturerHash.$manufacturer
```

### 2. Display Resolution Detection
```powershell
# Current display resolution (not DPI-scaled)
Add-Type -AssemblyName System.Windows.Forms
$screens = [System.Windows.Forms.Screen]::AllScreens

# WMI for hardware capabilities
$videoControllers = Get-CimInstance -ClassName Win32_VideoController
```

### 3. GPU Classification
```powershell
# Filter out USB display adapters
if ($gpu.Name -match "DisplayLink") {
    Write-Info "USB Display Adapter: $($gpu.Name) (docking station/USB-C hub)"
    continue
}

# GPU priority detection
if ($gpu.Name -match "NVIDIA|GeForce|Quadro|RTX|GTX") { /* NVENC */ }
elseif ($gpu.Name -match "Intel.*Graphics|Intel.*Iris|Intel.*UHD") { /* QuickSync */ }
elseif ($gpu.Name -match "AMD|Radeon|RX") { /* AMF */ }
```

## Configuration Management

### 1. OBS Configuration File Modification
```powershell
# Critical settings for video configuration
$config = $config -replace "BaseCX=.*", "BaseCX=$baseWidth"
$config = $config -replace "BaseCY=.*", "BaseCY=$baseHeight"
$config = $config -replace "OutputCX=.*", "OutputCX=$outputWidth"
$config = $config -replace "OutputCY=.*", "OutputCY=$outputHeight"
$config = $config -replace "VBitrate=.*", "VBitrate=$bitrate"
$config = $config -replace "ABitrate=.*", "ABitrate=$audioBitrate"
```

### 2. Configuration Verification
```powershell
# Verify settings were applied
$verifyConfig = Get-Content -Path $profilePath -Raw
$actualBaseCX = if ($verifyConfig -match "BaseCX=(\d+)") { $matches[1] } else { "Not Set" }
$actualOutputCX = if ($verifyConfig -match "OutputCX=(\d+)") { $matches[1] } else { "Not Set" }
```

## Protection System Implementation

### 1. Background Jobs vs Scheduled Tasks
```powershell
# Use background jobs for auto-stop (no admin required)
Start-Job -ScriptBlock {
    Start-Sleep -Seconds (2 * 60 * 60)  # 2 hours
    & $ServiceScriptPath -Action AutoStop
} -ArgumentList $PSCommandPath | Out-Null

# Use scheduled tasks for system events (requires admin)
Register-ScheduledTask -TaskName "OBS\AutoRecord-Start" -Trigger $loginTrigger
```

### 2. Graceful Process Termination
```powershell
# Graceful shutdown with timeout
$obsProcesses = Get-Process -Name "obs64", "obs32" -ErrorAction SilentlyContinue
foreach ($proc in $obsProcesses) {
    $proc.CloseMainWindow()
    if (-not $proc.WaitForExit(20000)) {  # 20 second timeout
        $proc.Kill()
    }
}
```

## Display Selection Logic

### 1. Automatic Single Display
```powershell
# Auto-select when only one display detected
if ($displays.Count -eq 1) {
    $selectedDisplay = $displays[0]
    Write-Success "Single display detected: $($selectedDisplay.Name)"
    return $selectedDisplay
}
```

### 2. Interactive Multi-Display with Timeout
```powershell
# 10-second timeout for user selection
for ($i = 10; $i -gt 0; $i--) {
    if ([Console]::KeyAvailable) {
        $selection = Read-Host "Select display (1-$($displays.Count))"
        break
    }
    Write-Host "`rAuto-select in $i seconds" -NoNewline
    Start-Sleep -Seconds 1
}
```

### 3. CheckOnly Mode Behavior
```powershell
# CheckOnly should never wait for user input
if ($CheckOnly) {
    $primaryDisplay = $displays | Where-Object { $_.Primary } | Select-Object -First 1
    Write-Success "CheckOnly mode: Auto-selected primary display"
    return $primaryDisplay
}
```

## Notification System

### 1. Non-Interactive Balloon Notifications
```powershell
# Windows Forms NotifyIcon approach
Add-Type -AssemblyName System.Windows.Forms
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
$notifyIcon.Visible = $true
$notifyIcon.ShowBalloonTip(5000, $title, $message, [System.Windows.Forms.ToolTipIcon]::Info)
```

### 2. Fallback Methods
```powershell
# WScript popup as fallback
$wscript = New-Object -ComObject WScript.Shell
$wscript.Popup($message, 5, $title, 0x40)
```

These standards ensure reliable, maintainable OBS Studio automation code that handles real-world deployment scenarios effectively.
