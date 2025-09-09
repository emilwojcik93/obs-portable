#Requires -Version 5.0
<#
.SYNOPSIS
    OBS Studio Infrastructure as Code Deployment Script
.DESCRIPTION
    Complete IaC solution for OBS Studio portable deployment with:
    - 5-tier performance optimization system (33%, 50%, 60%, 75%, 90% scaling)
    - Advanced hardware detection (real monitor names, GPU classification)
    - Interactive first-time setup with post-configuration automation
    - Enterprise scheduled tasks and protection systems
    - Microsoft OneDrive/SharePoint integration
    - Non-interactive balloon notifications
    - Comprehensive encoder overload prevention
.PARAMETER InstallPath
    Directory where OBS Studio will be installed
.PARAMETER VerboseLogging
    Enable verbose logging output
.PARAMETER CheckOnly
    Only check environment and hardware
.PARAMETER Force
    Force reinstallation
.PARAMETER InstallScheduledTasks
    Install scheduled tasks for auto-recording (requires admin)
.PARAMETER EnableNotifications
    Enable Windows balloon notifications
.PARAMETER Cleanup
    Remove existing installation and tasks
.PARAMETER PerformanceMode
    Performance optimization level: 33, 50, 60, 75, 90 (% of display resolution)
    33 = Extreme performance (severe encoder overload)
    50 = Ultra-lightweight (encoder overload prevention) 
    60 = Lightweight (default ultra performance)
    75 = Optimized (lower-end hardware)
    90 = Standard (modern hardware)
.PARAMETER TestNotifications
    Test balloon notifications (shows demo)
.PARAMETER PrimaryDisplay
    Use primary/main display for recording
.PARAMETER InternalDisplay
    Use internal display for recording (requires dual display setup)
.PARAMETER ExternalDisplay
    Use external display for recording (requires dual display setup)
.PARAMETER CustomDisplay
    Use custom resolution for recording (format: 1920x1080)
.EXAMPLE
    .\Deploy-OBSStudio.ps1 -Force
    Default deployment with 60% scaling (lightweight performance)
.EXAMPLE
    .\Deploy-OBSStudio.ps1 -Force -PerformanceMode 33 -PrimaryDisplay
    Extreme performance mode for severe encoder overload (33% scaling)
.EXAMPLE
    .\Deploy-OBSStudio.ps1 -CheckOnly -PerformanceMode 50
    Preview ultra-lightweight settings without making changes
.EXAMPLE
    .\Deploy-OBSStudio.ps1 -Force -InstallScheduledTasks -EnableNotifications
    Complete enterprise deployment with auto-recording service
.NOTES
    Author: OBS IaC Team
    Version: 2.0 - Unified Performance System
    Requires: PowerShell 5.0+, Windows 10/11
    GitHub: https://github.com/[username]/obs_studio-portable
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(HelpMessage="Directory where OBS Studio will be installed")]
    [ValidateNotNullOrEmpty()]
    [string]$InstallPath = "${env:USERPROFILE}\OBS-Studio-Portable",
    
    [Parameter(HelpMessage="Enable verbose logging output")]
    [switch]$VerboseLogging,
    
    [Parameter(HelpMessage="Only check environment and hardware")]
    [switch]$CheckOnly,
    
    [Parameter(HelpMessage="Force reinstallation")]
    [switch]$Force,
    
    [Parameter(HelpMessage="Install scheduled tasks for auto-recording (requires admin)")]
    [switch]$InstallScheduledTasks,
    
    [Parameter(HelpMessage="Enable Windows balloon notifications")]
    [switch]$EnableNotifications,
    
    [Parameter(HelpMessage="Remove existing installation and tasks")]
    [switch]$Cleanup,
    
    [Parameter(HelpMessage="Performance optimization level: 33, 50, 60, 75, 90 (% of display resolution)")]
    [ValidateSet("33", "50", "60", "75", "90")]
    [string]$PerformanceMode = "60",
    
    [Parameter(HelpMessage="Test balloon notifications (shows demo)")]
    [switch]$TestNotifications,
    
    [Parameter(HelpMessage="Use primary/main display for recording")]
    [switch]$PrimaryDisplay,
    
    [Parameter(HelpMessage="Use internal display for recording (requires dual display setup)")]
    [switch]$InternalDisplay,
    
    [Parameter(HelpMessage="Use external display for recording (requires dual display setup)")]
    [switch]$ExternalDisplay,
    
    [Parameter(HelpMessage="Use custom resolution for recording (format: 1920x1080)")]
    [ValidatePattern('^\d+x\d+$')]
    [string]$CustomDisplay
)

$ErrorActionPreference = "Stop"

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-AdminCommand {
    param([string]$CurrentCommand)
    
    Write-Host ""
    Write-Warning "Administrator rights are required for scheduled task installation."
    Write-Host ""
    Write-Host "Please run the following command from an elevated PowerShell window:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host $CurrentCommand -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To open elevated PowerShell:" -ForegroundColor Gray
    Write-Host "1. Press Win+X" -ForegroundColor Gray
    Write-Host "2. Select 'Windows PowerShell (Admin)' or 'Terminal (Admin)'" -ForegroundColor Gray
    Write-Host "3. Navigate to: $PWD" -ForegroundColor Gray
    Write-Host "4. Run the command above" -ForegroundColor Gray
    Write-Host ""
}

function Write-Info { param([string]$Message) Write-Host $Message -ForegroundColor Cyan }
function Write-Success { param([string]$Message) Write-Host $Message -ForegroundColor Green }
function Write-Warning { param([string]$Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Error { param([string]$Message) Write-Host $Message -ForegroundColor Red }

function Show-BalloonNotification {
    param(
        [string]$Title = "OBS Studio",
        [string]$Message,
        [string]$Type = "Info",
        [int]$Duration = 5000
    )
    
    if (-not $EnableNotifications -and -not $TestNotifications) { return }
    
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        
        $balloon = New-Object System.Windows.Forms.NotifyIcon
        
        switch ($Type) {
            "Warning" { 
                $balloon.Icon = [System.Drawing.SystemIcons]::Warning
                $balloon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning
            }
            "Error" { 
                $balloon.Icon = [System.Drawing.SystemIcons]::Error
                $balloon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Error
            }
            default { 
                $balloon.Icon = [System.Drawing.SystemIcons]::Information
                $balloon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
            }
        }
        
        $balloon.BalloonTipText = $Message
        $balloon.BalloonTipTitle = $Title
        $balloon.Visible = $true
        $balloon.ShowBalloonTip($Duration)
        
        Start-Sleep -Milliseconds ($Duration + 1000)
        $balloon.Dispose()
        
    } catch {
        Write-Warning "Notification failed: $($_.Exception.Message)"
    }
}

function Get-DisplayConfiguration {
    param(
        [switch]$PrimaryDisplay,
        [switch]$InternalDisplay,
        [switch]$ExternalDisplay,
        [string]$CustomDisplay,
        [switch]$CheckOnly
    )
    
    # Get all available displays with both Forms and WMI data
    Add-Type -AssemblyName System.Windows.Forms
    $screens = [System.Windows.Forms.Screen]::AllScreens
    
    # Get actual display resolutions from WMI (not DPI-scaled)
    $wmiDisplays = @()
    try {
        $videoControllers = Get-CimInstance -ClassName Win32_VideoController | Where-Object { $_.CurrentHorizontalResolution -and $_.CurrentVerticalResolution }
        foreach ($controller in $videoControllers) {
            $wmiDisplays += @{
                Width = $controller.CurrentHorizontalResolution
                Height = $controller.CurrentVerticalResolution
                Name = $controller.Name
            }
        }
    } catch {
        $wmiDisplays = @()
    }
    
    # Get detailed monitor information from WMI using proven Get-Monitor.ps1 logic
    function Get-MonitorInfo {
        try {
            # Manufacturer hash table from Get-Monitor.ps1 for friendly names
            $ManufacturerHash = @{
                "AAC" = "AcerView"; "ACR" = "Acer"; "AOC" = "AOC"; "AIC" = "AG Neovo";
                "APP" = "Apple Computer"; "AST" = "AST Research"; "AUO" = "Asus"; "BNQ" = "BenQ";
                "CMO" = "Acer"; "CPL" = "Compal"; "CPQ" = "Compaq"; "CPT" = "Chunghwa Picture Tubes, Ltd.";
                "CTX" = "CTX"; "DEC" = "DEC"; "DEL" = "Dell"; "DPC" = "Delta"; "DWE" = "Daewoo";
                "EIZ" = "EIZO"; "ELS" = "ELSA"; "ENC" = "EIZO"; "EPI" = "Envision"; "FCM" = "Funai";
                "FUJ" = "Fujitsu"; "FUS" = "Fujitsu-Siemens"; "GSM" = "LG Electronics"; "GWY" = "Gateway 2000";
                "HEI" = "Hyundai"; "HIT" = "Hyundai"; "HSL" = "Hansol"; "HTC" = "Hitachi/Nissei";
                "HWP" = "HP"; "IBM" = "IBM"; "ICL" = "Fujitsu ICL"; "IVM" = "Iiyama";
                "KDS" = "Korea Data Systems"; "LEN" = "Lenovo"; "LGD" = "Asus"; "LPL" = "Fujitsu";
                "MAX" = "Belinea"; "MEI" = "Panasonic"; "MEL" = "Mitsubishi Electronics"; "MS_" = "Panasonic";
                "NAN" = "Nanao"; "NEC" = "NEC"; "NOK" = "Nokia Data"; "NVD" = "Fujitsu";
                "OPT" = "Optoma"; "PHL" = "Philips"; "REL" = "Relisys"; "SAN" = "Samsung";
                "SAM" = "Samsung"; "SBI" = "Smarttech"; "SGI" = "SGI"; "SNY" = "Sony";
                "SRC" = "Shamrock"; "SUN" = "Sun Microsystems"; "SEC" = "Hewlett-Packard";
                "TAT" = "Tatung"; "TOS" = "Toshiba"; "TSB" = "Toshiba"; "VSC" = "ViewSonic";
                "ZCM" = "Zenith"; "UNK" = "Unknown"; "_YV" = "Fujitsu"
            }
            
            $monitors = @()
            
            # Use the exact working method from Get-Monitor.ps1
            $wmiMonitors = Get-WmiObject -Namespace "root\WMI" -Class "WMIMonitorID" -ErrorAction SilentlyContinue
            
            foreach ($monitor in $wmiMonitors) {
                # Extract and clean monitor data using Get-Monitor.ps1 logic with error handling
                $monModel = $null
                $monSerialNumber = "Unknown"
                $monManufacturer = "UNK"
                
                try {
                    if ($monitor.UserFriendlyName -and $monitor.UserFriendlyName.Length -gt 0) {
                        $monModel = ([System.Text.Encoding]::ASCII.GetString($monitor.UserFriendlyName)).Replace("$([char]0x0000)", "")
                    }
                } catch { }
                
                try {
                    if ($monitor.SerialNumberID -and $monitor.SerialNumberID.Length -gt 0) {
                        $monSerialNumber = ([System.Text.Encoding]::ASCII.GetString($monitor.SerialNumberID)).Replace("$([char]0x0000)", "")
                    }
                } catch { }
                
                try {
                    if ($monitor.ManufacturerName -and $monitor.ManufacturerName.Length -gt 0) {
                        $monManufacturer = ([System.Text.Encoding]::ASCII.GetString($monitor.ManufacturerName)).Replace("$([char]0x0000)", "")
                    }
                } catch { }
                
                # Only skip if we have absolutely no useful data
                if (-not $monModel -and $monManufacturer -eq "UNK") { continue }
                
                # Get friendly manufacturer name from hash table
                $monManufacturerFriendly = $ManufacturerHash.$monManufacturer
                if ($monManufacturerFriendly -eq $null) {
                    $monManufacturerFriendly = $monManufacturer
                }
                
                # Use a generic name if model is not available but manufacturer is
                if (-not $monModel -and $monManufacturer -ne "UNK") {
                    $monModel = "$monManufacturerFriendly Monitor"
                }
                
                $monitors += @{
                    Manufacturer = $monManufacturerFriendly
                    ManufacturerCode = $monManufacturer
                    Name = $monModel
                    SerialNumber = $monSerialNumber
                    InstanceName = $monitor.InstanceName
                }
            }
            
            # If no WMI data found, try fallback method
            if ($monitors.Count -eq 0) {
                try {
                    $desktopMonitors = Get-CimInstance -ClassName Win32_DesktopMonitor | Where-Object { $_.ScreenWidth -and $_.ScreenHeight }
                    foreach ($desktopMonitor in $desktopMonitors) {
                        $monitors += @{
                            Manufacturer = if ($desktopMonitor.MonitorManufacturer) { $desktopMonitor.MonitorManufacturer } else { "Unknown" }
                            ManufacturerCode = "UNK"
                            Name = if ($desktopMonitor.Name) { $desktopMonitor.Name } else { "Generic Monitor" }
                            SerialNumber = "Unknown"
                            InstanceName = $desktopMonitor.DeviceID
                        }
                    }
                } catch {
                    # Final fallback - return empty array
                }
            }
            
            return $monitors
        } catch {
            return @()
        }
    }
    
    $monitorInfo = Get-MonitorInfo
    
    # Debug: Show monitor info
    if ($VerboseLogging) {
        Write-Info "Found $($monitorInfo.Count) monitors from WMI"
        foreach ($mon in $monitorInfo) {
            Write-Info "  Monitor: $($mon.Manufacturer) $($mon.Name) ($($mon.SerialNumber))"
        }
    }
    
    # Get detailed display information
    $displays = @()
    $displayIndex = 1
    $script:usedMonitors = @()  # Track used monitors to avoid duplicates
    
    foreach ($screen in $screens) {
        # Try to get actual resolution from WMI instead of DPI-scaled resolution
        $actualWidth = $screen.Bounds.Width
        $actualHeight = $screen.Bounds.Height
        
        # Try to get accurate resolution, but be careful not to mix up displays
        if (-not $screen.Primary -and $wmiDisplays.Count -gt 0) {
            # For secondary (external) screens, use WMI data if available
            $externalWMI = $wmiDisplays | Select-Object -First 1
            if ($externalWMI -and ($externalWMI.Width -ne $actualWidth -or $externalWMI.Height -ne $actualHeight)) {
                $actualWidth = $externalWMI.Width
                $actualHeight = $externalWMI.Height
            }
        }
        # For primary screen, trust System.Windows.Forms.Screen unless it looks obviously wrong
        # If the Forms resolution is very small (like 1280x800), try to scale it up
        if ($screen.Primary -and $actualWidth -lt 1600 -and $actualHeight -lt 1000) {
            # This looks like a DPI-scaled resolution, try to detect the scaling factor
            $possibleScales = @(1.25, 1.5, 1.75, 2.0)
            foreach ($scale in $possibleScales) {
                $scaledWidth = [math]::Round($actualWidth * $scale)
                $scaledHeight = [math]::Round($actualHeight * $scale)
                # Check if this results in a common resolution
                if (($scaledWidth -eq 1920 -and $scaledHeight -eq 1200) -or
                    ($scaledWidth -eq 1920 -and $scaledHeight -eq 1080) -or
                    ($scaledWidth -eq 2560 -and $scaledHeight -eq 1440)) {
                    $actualWidth = $scaledWidth
                    $actualHeight = $scaledHeight
                    break
                }
            }
        }
        
        $displayInfo = @{
            Index = $displayIndex
            Width = $actualWidth
            Height = $actualHeight
            X = $screen.Bounds.X
            Y = $screen.Bounds.Y
            Primary = $screen.Primary
            DeviceName = $screen.DeviceName
            WorkingArea = "$($screen.WorkingArea.Width)x$($screen.WorkingArea.Height)"
        }
        
        # Try to match with WMI monitor info
        $monitor = $null
        if ($monitorInfo.Count -gt 0) {
            # For any screen, try to find a monitor with valid data
            # Since we may have multiple WMI monitors but fewer actual screens, 
            # use the first available monitor with valid data for any screen
            $monitor = $monitorInfo | Where-Object { $_.Name -and $_.Name -ne "" -and $_.Manufacturer -and $_.Manufacturer -ne "" } | Select-Object -First 1
            
            # If we found a monitor for the first display, remove it from the list for subsequent displays
            if ($monitor -and $displayIndex -eq 1) {
                $script:usedMonitors = @($monitor)
            } elseif ($monitor -and $displayIndex -gt 1) {
                # For subsequent displays, try to find an unused monitor
                $availableMonitors = $monitorInfo | Where-Object { 
                    $_.Name -and $_.Name -ne "" -and 
                    $_.Manufacturer -and $_.Manufacturer -ne "" -and
                    $script:usedMonitors -notcontains $_
                }
                if ($availableMonitors) {
                    $monitor = $availableMonitors | Select-Object -First 1
                    $script:usedMonitors += $monitor
                }
            }
        }
        
        if ($monitor -and $monitor.Name) {
            $displayInfo.Name = $monitor.Name
            $displayInfo.Manufacturer = $monitor.Manufacturer
            $displayInfo.ManufacturerCode = $monitor.ManufacturerCode
            $displayInfo.Model = $monitor.Name
            $displayInfo.SerialNumber = $monitor.SerialNumber
            
            # Try to get physical size information by matching instance names
            try {
                $physicalParams = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams -ErrorAction SilentlyContinue
                $matchingPhysical = $physicalParams | Where-Object { $_.InstanceName -eq $monitor.InstanceName }
                if ($matchingPhysical -and $matchingPhysical.MaxHorizontalImageSize -and $matchingPhysical.MaxVerticalImageSize) {
                    $diagonal = [math]::Round([math]::Sqrt([math]::Pow($matchingPhysical.MaxHorizontalImageSize, 2) + [math]::Pow($matchingPhysical.MaxVerticalImageSize, 2)) / 2.54, 1)
                    $displayInfo.PhysicalSize = "$($matchingPhysical.MaxHorizontalImageSize)x$($matchingPhysical.MaxVerticalImageSize)cm ($diagonal`")"
                } else {
                    $displayInfo.PhysicalSize = $null
                }
            } catch {
                $displayInfo.PhysicalSize = $null
            }
        } else {
            # Fallback to generic names based on screen properties
            if ($screen.Primary) {
                $displayInfo.Name = "Primary Display"
            } else {
                $displayInfo.Name = "Display $displayIndex"
            }
            $displayInfo.Manufacturer = "Unknown"
            $displayInfo.ManufacturerCode = "UNK"
            $displayInfo.Model = "Generic Monitor"
            $displayInfo.SerialNumber = "Unknown"
            $displayInfo.PhysicalSize = $null
        }
        
        $displays += $displayInfo
        $displayIndex++
    }
    
    
    # Handle custom display resolution
    if ($CustomDisplay) {
        if ($CustomDisplay -match '^(\d+)x(\d+)$') {
            $customWidth = [int]$matches[1]
            $customHeight = [int]$matches[2]
            
            # Check if this resolution matches any detected display
            $matchingDisplay = $displays | Where-Object { $_.Width -eq $customWidth -and $_.Height -eq $customHeight }
            if (-not $matchingDisplay) {
                Write-Error "Custom resolution ${CustomDisplay} does not match any detected display resolution. Available resolutions: $(($displays | ForEach-Object { "$($_.Width)x$($_.Height)" }) -join ', ')"
                exit 1
            }
            
            return @{
                Width = $customWidth
                Height = $customHeight
                Source = "Custom ($CustomDisplay)"
                Display = $matchingDisplay
            }
        }
    }
    
    # Handle primary display selection
    if ($PrimaryDisplay) {
        $selectedDisplay = $displays | Where-Object { $_.Primary } | Select-Object -First 1
        if (-not $selectedDisplay) { $selectedDisplay = $displays[0] }
        
        $displayName = if ($selectedDisplay.Name) { $selectedDisplay.Name } else { "Primary Display" }
        return @{
            Width = $selectedDisplay.Width
            Height = $selectedDisplay.Height
            Source = "Primary Display - $displayName"
            Display = $selectedDisplay
        }
    }

    # Handle internal/external display selection
    if ($InternalDisplay -or $ExternalDisplay) {
        if ($displays.Count -lt 2) {
            Write-Error "Internal/External display selection requires dual display setup. Only $($displays.Count) display(s) detected."
            exit 1
        }
        
        if ($InternalDisplay) {
            # Primary display is usually internal for laptops
            $selectedDisplay = $displays | Where-Object { $_.Primary } | Select-Object -First 1
            if (-not $selectedDisplay) { $selectedDisplay = $displays[0] }
            return @{
                Width = $selectedDisplay.Width
                Height = $selectedDisplay.Height
                Source = "Internal Display (Primary)"
                Display = $selectedDisplay
            }
        }
        
        if ($ExternalDisplay) {
            # Non-primary display is usually external
            $selectedDisplay = $displays | Where-Object { -not $_.Primary } | Select-Object -First 1
            if (-not $selectedDisplay) { $selectedDisplay = $displays[1] }
            return @{
                Width = $selectedDisplay.Width
                Height = $selectedDisplay.Height
                Source = "External Display"
                Display = $selectedDisplay
            }
        }
    }
    
    # Interactive display selection if no parameters provided
    if (-not ($PrimaryDisplay -or $InternalDisplay -or $ExternalDisplay -or $CustomDisplay)) {
        # If only one display, use it automatically
        if ($displays.Count -eq 1) {
            $selectedDisplay = $displays[0]
            $displayName = if ($selectedDisplay.Name) { $selectedDisplay.Name } else { "Primary Display" }
            $manufacturerText = if ($selectedDisplay.Manufacturer -and $selectedDisplay.Manufacturer -ne "Unknown") {
                " - $($selectedDisplay.Manufacturer)"
            } else {
                ""
            }
            Write-Success "Single display detected: $displayName ($($selectedDisplay.Width)x$($selectedDisplay.Height))$manufacturerText"
            return @{
                Width = $selectedDisplay.Width
                Height = $selectedDisplay.Height
                Source = "Single Display - $displayName"
                Display = $selectedDisplay
            }
        }
        
        # If in CheckOnly mode, auto-select primary display without prompting
        if ($CheckOnly) {
            $primaryDisplay = $displays | Where-Object { $_.Primary } | Select-Object -First 1
            if (-not $primaryDisplay) { $primaryDisplay = $displays[0] }
            
            $displayName = if ($primaryDisplay.Name) { $primaryDisplay.Name } else { "Primary Display" }
            Write-Success "CheckOnly mode: Auto-selected primary display - $displayName ($($primaryDisplay.Width)x$($primaryDisplay.Height))"
            return @{
                Width = $primaryDisplay.Width
                Height = $primaryDisplay.Height
                Source = "CheckOnly - Primary Display"
                Display = $primaryDisplay
            }
        }
        
        # Multiple displays - check for same resolution
        $uniqueResolutions = $displays | Group-Object { "$($_.Width)x$($_.Height)" }
        if ($uniqueResolutions.Count -eq 1) {
            # All displays have same resolution - need user selection
            Write-Host ""
            Write-Host "=== Display Selection ===" -ForegroundColor Yellow
            Write-Host "Detected $($displays.Count) displays with same resolution:" -ForegroundColor Cyan
            Write-Host ""
        } else {
            # Different resolutions - show selection
            Write-Host ""
            Write-Host "=== Display Selection ===" -ForegroundColor Yellow
            Write-Host "Detected $($displays.Count) display(s):" -ForegroundColor Cyan
            Write-Host ""
        }
        
        foreach ($display in $displays) {
            $primaryText = if ($display.Primary) { " (Primary)" } else { "" }
            $positionText = "Position: ($($display.X), $($display.Y))"
            $sizeText = if ($display.PhysicalSize) { ", Size: $($display.PhysicalSize)" } else { "" }
            
            Write-Host "$($display.Index). $($display.Name)$primaryText" -ForegroundColor Green
            Write-Host "   Resolution: $($display.Width)x$($display.Height)" -ForegroundColor White
            Write-Host "   $positionText$sizeText" -ForegroundColor Gray
            Write-Host "   Manufacturer: $($display.Manufacturer) ($($display.ManufacturerCode))" -ForegroundColor Gray
            Write-Host "   Serial: $($display.SerialNumber), Device: $($display.DeviceName)" -ForegroundColor Gray
            Write-Host ""
        }
        
        # Interactive selection with 10-second timeout
        Write-Host "Auto-selecting primary display in 10 seconds if no selection made..." -ForegroundColor Yellow
        
        $timeout = 10
        $selection = $null
        
        for ($i = $timeout; $i -gt 0; $i--) {
            if ([Console]::KeyAvailable) {
                $selection = Read-Host "`rSelect display for recording (1-$($displays.Count)) or CTRL-C to exit"
                break
            }
            Write-Host "`rSelect display for recording (1-$($displays.Count)) or CTRL-C to exit (auto-select in $i seconds)" -NoNewline -ForegroundColor Cyan
            Start-Sleep -Seconds 1
        }
        
        if (-not $selection) {
            # Timeout - auto-select primary display
            Write-Host ""
            $primaryDisplay = $displays | Where-Object { $_.Primary } | Select-Object -First 1
            if (-not $primaryDisplay) { $primaryDisplay = $displays[0] }
            
            $displayName = if ($primaryDisplay.Name) { $primaryDisplay.Name } else { "Primary Display" }
            Write-Success "Timeout - Auto-selected primary display: $displayName ($($primaryDisplay.Width)x$($primaryDisplay.Height))"
            return @{
                Width = $primaryDisplay.Width
                Height = $primaryDisplay.Height
                Source = "Timeout - Primary Display"
                Display = $primaryDisplay
            }
        }
        
        # Process user selection
        $selectedIndex = $null
        if ([int]::TryParse($selection, [ref]$selectedIndex) -and $selectedIndex -ge 1 -and $selectedIndex -le $displays.Count) {
            $selectedDisplay = $displays[$selectedIndex - 1]
            Write-Success "Selected: $($selectedDisplay.Name) ($($selectedDisplay.Width)x$($selectedDisplay.Height))"
            return @{
                Width = $selectedDisplay.Width
                Height = $selectedDisplay.Height
                Source = "Interactive Selection - $($selectedDisplay.Name)"
                Display = $selectedDisplay
            }
        } else {
            Write-Warning "Invalid selection. Auto-selecting primary display."
            $primaryDisplay = $displays | Where-Object { $_.Primary } | Select-Object -First 1
            if (-not $primaryDisplay) { $primaryDisplay = $displays[0] }
            
            return @{
                Width = $primaryDisplay.Width
                Height = $primaryDisplay.Height
                Source = "Fallback - Primary Display"
                Display = $primaryDisplay
            }
        }
    }
    
    # Fallback to primary display
    $primaryDisplay = $displays | Where-Object { $_.Primary } | Select-Object -First 1
    return @{
        Width = $primaryDisplay.Width
        Height = $primaryDisplay.Height
        Source = "Primary Display (Default)"
        Display = $primaryDisplay
    }
}

function Get-SystemConfiguration {
    param(
        [switch]$InternalDisplay,
        [switch]$ExternalDisplay,
        [string]$CustomDisplay
    )
    
    Write-Info "=== System Configuration Analysis ==="
    
    $config = @{
        Hardware = @{
            IsLaptop = $null -ne (Get-CimInstance -ClassName Win32_Battery)
            CPU = (Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1).Name
            Memory = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
        }
        Display = @{
            ActualResolution = @{ Width = 1920; Height = 1200 }
            RecordingResolution = @{ Width = 1728; Height = 1080 }
            MonitorIndex = 0
            Count = 1
        }
        GPU = @{
            Type = "Intel"
            Encoder = "obs_qsv11"
            Name = "Intel QuickSync H.264"
            Bitrate = switch ($PerformanceMode) {
                "33" { 1500 }
                "50" { 2500 }
                "60" { 3000 }
                "75" { 6000 }
                "90" { 10000 }
            }
            Preset = if ([int]$PerformanceMode -le 75) { "speed" } else { "balanced" }
            SupportsHardware = $true
            PerformanceMode = $PerformanceMode
        }
        OneDrive = @{
            Available = $false
            Path = "${env:USERPROFILE}\Videos\OBS-Recordings"
            Type = "Local"
        }
    }
    
    try {
        # Detect system
        Write-Info "System: $(if($config.Hardware.IsLaptop){'Laptop'}else{'Desktop'}) - $($config.Hardware.CPU)"
        Write-Info "Memory: $($config.Hardware.Memory)GB"
        
        # Get display configuration (interactive or parameter-based)
        $displayConfig = Get-DisplayConfiguration -PrimaryDisplay:$PrimaryDisplay -InternalDisplay:$InternalDisplay -ExternalDisplay:$ExternalDisplay -CustomDisplay:$CustomDisplay -CheckOnly:$CheckOnly
        
        $config.Display.ActualResolution = @{
            Width = $displayConfig.Width
            Height = $displayConfig.Height
        }
        Write-Success "Display Resolution: $($displayConfig.Width)x$($displayConfig.Height) ($($displayConfig.Source))"
        
        # Also detect native resolution for reference
        $monitors = Get-CimInstance -ClassName Win32_DesktopMonitor
        foreach ($monitor in $monitors) {
            if ($monitor.ScreenWidth -and $monitor.ScreenHeight) {
                Write-Info "Native Hardware Resolution: $($monitor.ScreenWidth)x$($monitor.ScreenHeight)"
                break
            }
        }
        
        # Calculate recording resolution based on performance mode
        $scalingFactor = [int]$PerformanceMode / 100.0
        $config.Display.RecordingResolution = @{
            Width = [math]::Round($config.Display.ActualResolution.Width * $scalingFactor)
            Height = [math]::Round($config.Display.ActualResolution.Height * $scalingFactor)
        }
        
        $performanceDescription = switch ($PerformanceMode) {
            "33" { "Extreme performance: 33% scaling for severe encoder overload" }
            "50" { "Ultra-lightweight: 50% scaling for maximum performance" }
            "60" { "Lightweight: 60% scaling (default ultra performance)" }
            "75" { "Optimized: 75% scaling to reduce encoder load" }
            "90" { "Standard: 90% scaling (balanced quality/performance)" }
        }
        
        $exampleRes = "$([math]::Round(1920 * $scalingFactor))x$([math]::Round(1200 * $scalingFactor))"
        Write-Info "$performanceDescription (${exampleRes} from 1920x1200)"
        
        # Detect GPU
        $gpus = Get-CimInstance -ClassName Win32_VideoController | Where-Object { 
            $_.Status -eq "OK" -and $_.Name -notmatch "Microsoft Basic|Remote Desktop" 
        }
        
        foreach ($gpu in $gpus) {
            # Filter out DisplayLink USB devices (docking stations/adapters, not actual GPUs)
            if ($gpu.Name -match "DisplayLink") {
                Write-Info "USB Display Adapter: $($gpu.Name) (docking station/USB-C hub)"
                continue
            }
            
            Write-Info "GPU: $($gpu.Name)"
            
            if ($gpu.Name -match "NVIDIA|GeForce|Quadro|RTX|GTX") {
                # Configure based on performance mode
                switch ($PerformanceMode) {
                    "33" { 
                        $bitrate = 2000
                        $preset = "p1"
                        $mode = " (extreme performance - 33%)"
                    }
                    "50" { 
                        $bitrate = 3500
                        $preset = "p1"
                        $mode = " (ultra-lightweight - 50%)"
                    }
                    "60" { 
                        $bitrate = 4000
                        $preset = "p1"
                        $mode = " (lightweight - 60%)"
                    }
                    "75" { 
                        $bitrate = 8000
                        $preset = "p3"
                        $mode = " (optimized - 75%)"
                    }
                    "90" { 
                        $bitrate = 12000
                        $preset = "p4"
                        $mode = " (standard - 90%)"
                    }
                }
                
                $config.GPU = @{
                    Type = "NVIDIA"
                    Encoder = "ffmpeg_nvenc"
                    Name = "NVIDIA NVENC H.264"
                    Bitrate = $bitrate
                    Preset = $preset
                    SupportsHardware = $true
                    PerformanceMode = $PerformanceMode
                }
                Write-Success "NVIDIA GPU: Using NVENC encoding$mode"
                break
            } elseif ($gpu.Name -match "Intel.*Graphics|Intel.*Iris|Intel.*UHD|Intel.*HD") {
                # Configure based on performance mode
                switch ($PerformanceMode) {
                    "33" { 
                        $config.GPU.Bitrate = 1500
                        $config.GPU.Preset = "speed"
                        $mode = " (extreme performance - 33%)"
                    }
                    "50" { 
                        $config.GPU.Bitrate = 2500
                        $config.GPU.Preset = "speed"
                        $mode = " (ultra-lightweight - 50%)"
                    }
                    "60" { 
                        $config.GPU.Bitrate = 3000
                        $config.GPU.Preset = "speed"
                        $mode = " (lightweight - 60%)"
                    }
                    "75" { 
                        $config.GPU.Bitrate = 6000
                        $config.GPU.Preset = "speed"
                        $mode = " (optimized - 75%)"
                    }
                    "90" { 
                        $config.GPU.Bitrate = 10000
                        $config.GPU.Preset = "balanced"
                        $mode = " (standard - 90%)"
                    }
                }
                
                $config.GPU.PerformanceMode = $PerformanceMode
                Write-Success "Intel GPU: Using QuickSync encoding$mode"
            } elseif ($gpu.Name -match "AMD|Radeon|RX") {
                if (-not $config.GPU.Type -or $config.GPU.Type -eq "Intel") {
                    # Configure based on performance mode
                    switch ($PerformanceMode) {
                        "33" { 
                            $bitrate = 1800
                            $preset = "speed"
                            $mode = " (extreme performance - 33% with AMF)"
                            $bframes = 0
                        }
                        "50" { 
                            $bitrate = 2800
                            $preset = "speed"
                            $mode = " (ultra-lightweight - 50% with AMF)"
                            $bframes = 0
                        }
                        "60" { 
                            $bitrate = 3500
                            $preset = "speed"
                            $mode = " (lightweight - 60% with AMF)"
                            $bframes = 0
                        }
                        "75" { 
                            $bitrate = 6000
                            $preset = "speed"
                            $mode = " (optimized - 75%)"
                            $bframes = 2
                        }
                        "90" { 
                            $bitrate = 10000
                            $preset = "balanced"
                            $mode = " (standard - 90%)"
                            $bframes = 2
                        }
                    }
                    
                    $config.GPU = @{
                        Type = "AMD"
                        Encoder = "amd_amf_h264"
                        Name = "AMD AMF H.264"
                        Bitrate = $bitrate
                        Preset = $preset
                        SupportsHardware = $true
                        PerformanceMode = $PerformanceMode
                        AMFPreAnalysis = ([int]$PerformanceMode -le 60)  # Enable for performance modes
                        AMFBFrames = $bframes
                    }
                    Write-Success "AMD GPU: Using AMF encoding$mode"
                }
            }
        }
        
        # Detect OneDrive
        $oneDriveVars = @("OneDrive", "OneDriveCommercial", "OneDriveConsumer")
        foreach ($var in $oneDriveVars) {
            $path = [Environment]::GetEnvironmentVariable($var)
            if ($path -and (Test-Path $path)) {
                $config.OneDrive = @{
                    Available = $true
                    Path = Join-Path $path "Recordings"
                    Type = $var
                    BasePath = $path
                }
                Write-Success "OneDrive: $var detected"
                break
            }
        }
        
        # Ensure OneDrive recordings directory exists
        if (-not (Test-Path $config.OneDrive.Path)) {
            New-Item -ItemType Directory -Path $config.OneDrive.Path -Force | Out-Null
            Write-Success "Created recordings directory: $($config.OneDrive.Path)"
        }
        
        return $config
        
    } catch {
        Write-Warning "System detection failed: $($_.Exception.Message)"
        return $config
    }
}

function Install-OBSStudio {
    param([hashtable]$SystemConfig)
    
    Write-Info "=== Installing OBS Studio Portable ==="
    
    if ($WhatIfPreference) {
        Write-Info "[WHATIF] Would install OBS Studio portable"
        return $true
    }
    
    try {
        # Get latest version
        $apiUrl = "https://api.github.com/repos/obsproject/obs-studio/releases/latest"
        $headers = @{ 'User-Agent' = 'OBS-Deploy-Script/1.1'; 'Accept' = 'application/vnd.github.v3+json' }
        $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 30
        
        $latestVersion = $response.tag_name
        $windowsAsset = $response.assets | Where-Object { $_.name -like "*Windows-x64.zip" } | Select-Object -First 1
        
        Write-Success "Installing OBS Studio $latestVersion"
        
        # Download and install
        $tempZip = Join-Path ${env:TEMP} "OBS-Studio-${latestVersion}.zip"
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($windowsAsset.browser_download_url, $tempZip)
        $webClient.Dispose()
        
        $tempExtract = Join-Path ${env:TEMP} "OBS-Extract-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $tempExtract)
        
        $extractedFolders = Get-ChildItem -Path $tempExtract -Directory
        $obsSourceFolder = $extractedFolders | Where-Object { Test-Path (Join-Path $_.FullName "bin\64bit\obs64.exe") }
        
        if ($obsSourceFolder) {
            $obsSource = $obsSourceFolder[0].FullName
        } else {
            # Check if files are directly in extract path
            if (Test-Path (Join-Path $tempExtract "bin\64bit\obs64.exe")) {
                $obsSource = $tempExtract
            } else {
                throw "Could not find OBS executable in extracted files"
            }
        }
        
        if (Test-Path $InstallPath) {
            Remove-Item $InstallPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
        
        Copy-Item -Path "${obsSource}\*" -Destination $InstallPath -Recurse -Force
        New-Item -ItemType File -Path (Join-Path $InstallPath "portable_mode.txt") -Force | Out-Null
        
        # Cleanup
        Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
        
        Write-Success "OBS Studio installed successfully"
        return $true
        
    } catch {
        Write-Error "Installation failed: $($_.Exception.Message)"
        return $false
    }
}

function Start-OBSFirstTime {
    param([hashtable]$SystemConfig)
    
    Write-Info "=== OBS Studio First-Time Interactive Setup ==="
    
    if ($WhatIfPreference) {
        Write-Info "[WHATIF] Would launch OBS for interactive first-time setup"
        return $true
    }
    
    try {
        $obsExePath = Join-Path $InstallPath "bin\64bit\obs64.exe"
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "  OBS Studio First-Time Setup Required  " -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Required Steps:" -ForegroundColor Cyan
        Write-Host "1. Complete Auto-Configuration Wizard" -ForegroundColor Green
        Write-Host "   - Choose 'Optimize just for recording'" -ForegroundColor White
        Write-Host "2. Add Display Capture Source" -ForegroundColor Green
        Write-Host "   - Click '+' in Sources, add 'Display Capture'" -ForegroundColor White
        Write-Host "3. Close OBS when done" -ForegroundColor Green
        Write-Host ""
        Write-Host "Optional Enhancements:" -ForegroundColor Cyan
        Write-Host "4. Add Webcam (Optional)" -ForegroundColor Yellow
        Write-Host "   - Click '+' in Sources, add 'Video Capture Device'" -ForegroundColor White
        Write-Host "5. Configure Audio Input (Optional)" -ForegroundColor Yellow
        Write-Host "   - Click '+' in Sources, add 'Audio Input Capture'" -ForegroundColor White
        Write-Host "6. Configure Audio Output (Optional)" -ForegroundColor Yellow
        Write-Host "   - Click '+' in Sources, add 'Audio Output Capture'" -ForegroundColor White
        Write-Host ""
        Write-Host "Launching OBS Studio in 2 seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        
        Push-Location (Join-Path $InstallPath "bin\64bit")
        $obsProcess = Start-Process -FilePath ".\obs64.exe" -ArgumentList @("--portable") -PassThru
        Pop-Location
        
        Write-Success "OBS Studio launched - complete setup and close OBS to continue"
        $obsProcess.WaitForExit()
        Write-Success "OBS closed - continuing with optimization..."
        Start-Sleep -Seconds 3
        
        return $true
        
    } catch {
        Write-Error "First-time setup failed: $($_.Exception.Message)"
        return $false
    }
}

function Optimize-OBSConfiguration {
    param([hashtable]$SystemConfig)
    
    Write-Info "=== Optimizing OBS Configuration ==="
    
    if ($WhatIfPreference) {
        Write-Info "[WHATIF] Would optimize OBS configuration"
        return $true
    }
    
    try {
        $profilePath = Join-Path $InstallPath "config\obs-studio\basic\profiles\Untitled\basic.ini"
        
        if (-not (Test-Path $profilePath)) {
            Write-Warning "OBS configuration not found - please ensure you completed the setup"
            return $false
        }
        
        # Read and optimize existing configuration
        $config = Get-Content $profilePath -Raw
        
        # Apply hardware-specific encoder
        $config = $config -replace "RecEncoder=.*", "RecEncoder=$($SystemConfig.GPU.Encoder)"
        $config = $config -replace "VBitrate=.*", "VBitrate=$($SystemConfig.GPU.Bitrate)"
        
        # Set OneDrive output path
        $oneDrivePath = $SystemConfig.OneDrive.Path -replace '\\', '\\\\'
        $config = $config -replace "FilePath=.*", "FilePath=$oneDrivePath"
        $config = $config -replace "RecFilePath=.*", "RecFilePath=$oneDrivePath"
        
        # Apply optimization settings based on performance mode
        switch ($PerformanceMode) {
            "33" {
                # Extreme performance for severe encoder overload
                $config = $config -replace "ABitrate=.*", "ABitrate=64"
                $config = $config -replace "Preset=.*", "Preset=ultrafast"
                $config = $config -replace "FPSType=.*", "FPSType=0"
                $config = $config -replace "FPSCommon=.*", "FPSCommon=24"  # Lower FPS
                $config = $config -replace "ColorFormat=.*", "ColorFormat=NV12"
                
                # GPU-specific extreme optimizations
                if ($SystemConfig.GPU.Type -eq "Intel") {
                    $config += "`nQSVPreset=speed"
                    $config += "`nQSVTargetUsage=1"
                    $config += "`nQSVAsyncDepth=1"
                    $config += "`nQSVBFrames=0"
                } elseif ($SystemConfig.GPU.Type -eq "AMD") {
                    $config += "`nAMFPreAnalysis=true"
                    $config += "`nAMFBFrames=0"
                    $config += "`nAMFEnforceHRD=false"
                    $config += "`nAMFFillerData=false"
                    $config += "`nAMFVBAQ=false"
                    $config += "`nAMFLowLatency=true"
                } elseif ($SystemConfig.GPU.Type -eq "NVIDIA") {
                    $config += "`nNVENCPreset=p1"
                    $config += "`nNVENCTuning=ull"
                    $config += "`nNVENCMultipass=disabled"
                    $config += "`nNVENCBFrames=0"
                }
                Write-Info "Applied extreme performance settings (33% scaling, 24fps)"
            }
            "50" {
                # Ultra-lightweight performance
                $config = $config -replace "ABitrate=.*", "ABitrate=96"
                $config = $config -replace "Preset=.*", "Preset=ultrafast"
                $config = $config -replace "FPSType=.*", "FPSType=0"
                $config = $config -replace "FPSCommon=.*", "FPSCommon=30"
                
                # GPU-specific optimizations
                if ($SystemConfig.GPU.Type -eq "AMD") {
                    $config += "`nAMFPreAnalysis=true"
                    $config += "`nAMFBFrames=0"
                } elseif ($SystemConfig.GPU.Type -eq "Intel") {
                    $config += "`nQSVPreset=speed"
                    $config += "`nQSVTargetUsage=1"
                }
                Write-Info "Applied ultra-lightweight settings (50% scaling)"
            }
            "60" {
                # Lightweight performance (default ultra)
                $config = $config -replace "ABitrate=.*", "ABitrate=96"
                $config = $config -replace "Preset=.*", "Preset=fast"
                $config = $config -replace "FPSType=.*", "FPSType=0"
                $config = $config -replace "FPSCommon=.*", "FPSCommon=30"
                
                if ($SystemConfig.GPU.Type -eq "AMD") {
                    $config += "`nAMFPreAnalysis=true"
                    $config += "`nAMFBFrames=0"
                }
                Write-Info "Applied lightweight settings (60% scaling - default ultra)"
            }
            "75" {
                # Optimized performance
                $config = $config -replace "ABitrate=.*", "ABitrate=128"
                $config = $config -replace "Preset=.*", "Preset=fast"
                $config = $config -replace "FPSType=.*", "FPSType=0"
                $config = $config -replace "FPSCommon=.*", "FPSCommon=30"
                
                if ($SystemConfig.GPU.Type -eq "AMD") {
                    $config += "`nAMFPreAnalysis=true"
                    $config += "`nAMFBFrames=2"
                }
                Write-Info "Applied optimized settings (75% scaling)"
            }
            "90" {
                # Standard performance
                $config = $config -replace "ABitrate=.*", "ABitrate=160"
                $config = $config -replace "Preset=.*", "Preset=balanced"
                $config = $config -replace "FPSType=.*", "FPSType=0"
                $config = $config -replace "FPSCommon=.*", "FPSCommon=30"
                Write-Info "Applied standard settings (90% scaling)"
            }
        }
        
        # Apply critical resolution and encoder settings
        $baseWidth = $SystemConfig.Display.ActualResolution.Width
        $baseHeight = $SystemConfig.Display.ActualResolution.Height
        $outputWidth = $SystemConfig.Display.RecordingResolution.Width
        $outputHeight = $SystemConfig.Display.RecordingResolution.Height
        
        # Set base canvas resolution
        $config = $config -replace "BaseCX=.*", "BaseCX=$baseWidth"
        $config = $config -replace "BaseCY=.*", "BaseCY=$baseHeight"
        
        # Set output scaled resolution
        $config = $config -replace "OutputCX=.*", "OutputCX=$outputWidth"
        $config = $config -replace "OutputCY=.*", "OutputCY=$outputHeight"
        
        # Set encoder and bitrate
        $config = $config -replace "Encoder=.*", "Encoder=$($SystemConfig.GPU.Encoder)"
        $config = $config -replace "VBitrate=.*", "VBitrate=$($SystemConfig.GPU.Bitrate)"
        $config = $config -replace "bitrate=.*", "bitrate=$($SystemConfig.GPU.Bitrate)"
        
        # Set downscale filter (Bicubic for quality, Bilinear for performance)
        $downscaleFilter = if ($UltraLightweight) { "bilinear" } else { "bicubic" }
        $config = $config -replace "ScaleType=.*", "ScaleType=$downscaleFilter"
        
        # Ensure MKV format
        $config = $config -replace "RecFormat2=.*", "RecFormat2=mkv"
        
        Set-Content -Path $profilePath -Value $config -Encoding UTF8
        
        # Verify configuration was applied
        $verifyConfig = Get-Content -Path $profilePath -Raw
        $actualBaseCX = if ($verifyConfig -match "BaseCX=(\d+)") { $matches[1] } else { "Not Set" }
        $actualBaseCY = if ($verifyConfig -match "BaseCY=(\d+)") { $matches[1] } else { "Not Set" }
        $actualOutputCX = if ($verifyConfig -match "OutputCX=(\d+)") { $matches[1] } else { "Not Set" }
        $actualOutputCY = if ($verifyConfig -match "OutputCY=(\d+)") { $matches[1] } else { "Not Set" }
        $actualBitrate = if ($verifyConfig -match "VBitrate=(\d+)") { $matches[1] } else { "Not Set" }
        
        Write-Success "OBS configuration optimized!"
        Write-Info "Applied Settings:"
        Write-Info "  - Base Resolution: ${actualBaseCX}x${actualBaseCY} (configured: ${baseWidth}x${baseHeight})"
        Write-Info "  - Output Resolution: ${actualOutputCX}x${actualOutputCY} (configured: ${outputWidth}x${outputHeight})"
        Write-Info "  - Encoder: $($SystemConfig.GPU.Name)"
        Write-Info "  - Bitrate: ${actualBitrate} kbps (configured: $($SystemConfig.GPU.Bitrate) kbps)"
        Write-Info "  - Output: OneDrive\Recordings"
        Write-Info "  - Format: MKV"
        $audioBitrate = switch ($PerformanceMode) { "33" { "64" } "50" { "96" } "60" { "96" } "75" { "128" } "90" { "160" } }
        $fps = if ($PerformanceMode -eq "33") { "24" } else { "30" }
        $modeDescription = switch ($PerformanceMode) {
            "33" { "Extreme Performance (33% scaling, ${fps}fps, ${audioBitrate}kbps audio)" }
            "50" { "Ultra-Lightweight (50% scaling, ${fps}fps, ${audioBitrate}kbps audio)" }
            "60" { "Lightweight (60% scaling, ${fps}fps, ${audioBitrate}kbps audio)" }
            "75" { "Optimized (75% scaling, ${fps}fps, ${audioBitrate}kbps audio)" }
            "90" { "Standard (90% scaling, ${fps}fps, ${audioBitrate}kbps audio)" }
        }
        Write-Info "  - Mode: $modeDescription"
        
        return $true
        
    } catch {
        Write-Error "Configuration optimization failed: $($_.Exception.Message)"
        return $false
    }
}

function Install-AutoRecordingService {
    param(
        [string]$InstallPath,
        [string]$OneDrivePath
    )
    
    Write-Info "=== Installing Auto-Recording Service ==="
    
    if ($WhatIfPreference) {
        Write-Info "[WHATIF] Would install auto-recording service"
        return $true
    }
    
    try {
        # Create service script with proper working directory handling
        $serviceScript = @'
param([string]$Action = "Start")

function Write-ServiceLog {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logPath = "${env:TEMP}\OBSAutoRecord.log"
    Add-Content -Path $logPath -Value "[$timestamp] $Message" -ErrorAction SilentlyContinue
}

function Stop-OBSRecordingSafely {
    Write-ServiceLog "Stopping OBS recording safely..."
    $obsProcesses = Get-Process -Name "obs64" -ErrorAction SilentlyContinue
    
    if ($obsProcesses) {
        foreach ($proc in $obsProcesses) {
            try {
                Write-ServiceLog "Attempting graceful shutdown of OBS process $($proc.Id)"
                $proc.CloseMainWindow()
                
                if (-not $proc.WaitForExit(20000)) {
                    Write-ServiceLog "Graceful shutdown failed, forcing termination"
                    $proc.Kill()
                    $proc.WaitForExit(5000)
                }
                Write-ServiceLog "OBS process terminated successfully"
            } catch {
                Write-ServiceLog "Error stopping OBS: $($_.Exception.Message)"
            }
        }
    } else {
        Write-ServiceLog "No OBS processes found"
    }
}

function Start-RecordingWithAutoStop {
    param([string]$OBSPath, [string]$OutputPath)
    
    Write-ServiceLog "Starting OBS recording with auto-stop"
    
    # Start OBS from the correct working directory (same level as exe)
    $obsExeDir = Join-Path $OBSPath "bin\64bit"
    $obsExe = Join-Path $obsExeDir "obs64.exe"
    
    if (Test-Path $obsExe) {
        try {
            # Change to the executable directory (critical for OBS to work properly)
            Push-Location $obsExeDir
            $args = @("--portable", "--startrecording", "--minimize-to-tray")
            Start-Process -FilePath ".\obs64.exe" -ArgumentList $args -WorkingDirectory $obsExeDir -WindowStyle Minimized
            Write-ServiceLog "OBS started successfully from working directory: $obsExeDir"
            
            # Start background auto-stop timer (no scheduled task needed)
            Start-Job -ScriptBlock {
                param($ServiceScriptPath, $LogPath)
                Start-Sleep -Seconds (2 * 60 * 60)  # 2 hours
                Add-Content -Path $LogPath -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Auto-stop timer triggered after 2 hours"
                & $ServiceScriptPath -Action AutoStop
            } -ArgumentList $PSCommandPath, "${env:TEMP}\OBSAutoRecord.log" | Out-Null
            
            Write-ServiceLog "Auto-stop timer started for 2 hours (background job)"
        } finally {
            Pop-Location
        }
    } else {
        Write-ServiceLog "OBS executable not found at $obsExe"
    }
}

function Show-ServiceNotification {
    param([string]$Message, [string]$Type = "Info")
    
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $notification = New-Object System.Windows.Forms.NotifyIcon
        $notification.Icon = [System.Drawing.SystemIcons]::Information
        $notification.BalloonTipIcon = $Type
        $notification.BalloonTipText = $Message
        $notification.BalloonTipTitle = "OBS Recording"
        $notification.Visible = $true
        $notification.ShowBalloonTip(5000)
        
        Start-Sleep -Seconds 1
        $notification.Dispose()
    } catch {
        # Fallback to popup
        try {
            (New-Object -ComObject WScript.Shell).Popup($Message, 3, "OBS Recording", 64) | Out-Null
        } catch {
            Write-ServiceLog "Failed to show notification: $Message"
        }
    }
}

# Main service logic
switch ($Action) {
    "Start" {
        Write-ServiceLog "=== Starting Auto-Recording Service ==="
        Start-RecordingWithAutoStop -OBSPath "INSTALL_PATH_PLACEHOLDER" -OutputPath "ONEDRIVE_PATH_PLACEHOLDER"
        Show-ServiceNotification -Message "Recording started automatically" -Type "Info"
    }
    "Stop" {
        Write-ServiceLog "=== Stopping Auto-Recording Service ==="
        Stop-OBSRecordingSafely
        Show-ServiceNotification -Message "Recording stopped" -Type "Info"
        # Clean up any background auto-stop jobs
        Get-Job | Where-Object { $_.State -eq "Running" } | Stop-Job -ErrorAction SilentlyContinue
        Get-Job | Remove-Job -ErrorAction SilentlyContinue
    }
    "Shutdown" {
        Write-ServiceLog "=== System Shutdown - Emergency Stop ==="
        Stop-OBSRecordingSafely
        Show-ServiceNotification -Message "Recording stopped for shutdown" -Type "Warning"
    }
    "AutoStop" {
        Write-ServiceLog "=== Auto-Stop Triggered (2h limit) ==="
        Stop-OBSRecordingSafely
        Show-ServiceNotification -Message "Recording auto-stopped (2h limit)" -Type "Warning"
    }
}
'@
        
        # Replace placeholders
        $serviceScript = $serviceScript.Replace("INSTALL_PATH_PLACEHOLDER", $InstallPath)
        $serviceScript = $serviceScript.Replace("ONEDRIVE_PATH_PLACEHOLDER", $OneDrivePath)
        
        $serviceScriptPath = Join-Path $InstallPath "OBSAutoRecord.ps1"
        Set-Content -Path $serviceScriptPath -Value $serviceScript -Encoding UTF8
        
        # Create OBS folder in Task Scheduler
        $taskService = New-Object -ComObject Schedule.Service
        $taskService.Connect()
        $rootFolder = $taskService.GetFolder("\")
        
        try {
            $obsFolder = $rootFolder.GetFolder("OBS")
        } catch {
            $obsFolder = $rootFolder.CreateFolder("OBS")
        }
        
        # Create essential scheduled tasks only
        $obsExeDir = Join-Path $InstallPath "bin\64bit"
        $tasks = @(
            @{
                Name = "AutoRecord-Start"
                Description = "Start OBS recording on user login"
                Trigger = New-ScheduledTaskTrigger -AtLogon
                Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$serviceScriptPath`" -Action Start" -WorkingDirectory $obsExeDir
            }
        )
        
        foreach ($task in $tasks) {
            $fullTaskName = "OBS\$($task.Name)"
            Register-ScheduledTask -TaskName $fullTaskName -Description $task.Description -Trigger $task.Trigger -Action $task.Action -RunLevel Highest -Force | Out-Null
        }
        
        # Create a shutdown handler script
        $shutdownHandler = @"
# OBS Shutdown Handler - Registers for system shutdown events
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    & "$serviceScriptPath" -Action Shutdown
} | Out-Null

# Keep the script running to monitor for shutdown
try {
    while (`$true) {
        Start-Sleep -Seconds 60
        # Check if OBS is still running, if not, exit the monitor
        if (-not (Get-Process -Name "obs64" -ErrorAction SilentlyContinue)) {
            Start-Sleep -Seconds 300  # Wait 5 minutes before checking again
        }
    }
} catch {
    # If interrupted, ensure OBS is stopped
    & "$serviceScriptPath" -Action Shutdown
}
"@
        
        $shutdownHandlerPath = Join-Path $InstallPath "OBSShutdownHandler.ps1"
        Set-Content -Path $shutdownHandlerPath -Value $shutdownHandler -Encoding UTF8
        
        # Add shutdown handler to startup tasks
        $shutdownTask = @{
            Name = "AutoRecord-ShutdownHandler"
            Description = "Monitor for system shutdown and stop OBS recording safely"
            Trigger = New-ScheduledTaskTrigger -AtLogon
            Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$shutdownHandlerPath`"" -WorkingDirectory $obsExeDir
        }
        
        $fullTaskName = "OBS\$($shutdownTask.Name)"
        Register-ScheduledTask -TaskName $fullTaskName -Description $shutdownTask.Description -Trigger $shutdownTask.Trigger -Action $shutdownTask.Action -RunLevel Highest -Force | Out-Null
        
        Write-Success "Auto-recording service installed successfully"
        Write-Info "Scheduled tasks created in 'OBS' folder:"
        Write-Info "  - AutoRecord-Start: Auto-start recording on login"
        Write-Info "  - AutoRecord-ShutdownHandler: Monitor for shutdown events"
        Write-Info "Protection features:"
        Write-Info "  - Graceful OBS process termination (20-second timeout)"
        Write-Info "  - Auto-stop after 2 hours (background timer, no admin required)"
        Write-Info "  - Shutdown monitoring to prevent video corruption"
        
        return $true
        
    } catch {
        Write-Error "Service installation failed: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
try {
    Write-Host ""
    Write-Host "OBS Studio Infrastructure Deployment" -ForegroundColor Magenta
    Write-Host "=====================================" -ForegroundColor Magenta
    Write-Host ""
    
    # Handle special operations first
    if ($Cleanup) {
        Write-Info "=== Cleaning Up OBS Deployment ==="
        $cleanupItems = @()
        
        # Stop OBS processes and background jobs
        $obsProcesses = Get-Process -Name "obs64" -ErrorAction SilentlyContinue
        if ($obsProcesses) {
            Write-Info "Stopping OBS processes..."
            $obsProcesses | Stop-Process -Force
            Start-Sleep -Seconds 2
            $cleanupItems += "Stopped $($obsProcesses.Count) OBS process(es)"
        }
        
        # Clean up any background auto-stop jobs
        $backgroundJobs = Get-Job -ErrorAction SilentlyContinue
        if ($backgroundJobs) {
            Write-Info "Cleaning up background jobs..."
            $backgroundJobs | Stop-Job -ErrorAction SilentlyContinue
            $backgroundJobs | Remove-Job -ErrorAction SilentlyContinue
            $cleanupItems += "Cleaned up $($backgroundJobs.Count) background job(s)"
        }
        
        # Remove scheduled tasks
        Write-Info "Removing scheduled tasks..."
        $obsTaskNames = @(
            "OBS\AutoRecord-Start",
            "OBS\AutoRecord-ShutdownHandler"
        )
        
        $removedTasks = 0
        foreach ($taskName in $obsTaskNames) {
            try {
                $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
                if ($task) {
                    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
                    Write-Success "  - Removed task: $taskName"
                    $removedTasks++
                }
            } catch {
                Write-Warning "  - Failed to remove task: $taskName"
            }
        }
        
        # Try to remove OBS folder from Task Scheduler
        try {
            $taskService = New-Object -ComObject Schedule.Service
            $taskService.Connect()
            $rootFolder = $taskService.GetFolder("\")
            
            try {
                $obsFolder = $rootFolder.GetFolder("OBS")
                if ($obsFolder) {
                    # Remove any remaining tasks in the OBS folder
                    $remainingTasks = $obsFolder.GetTasks(0)
                    $taskList = @()
                    foreach ($task in $remainingTasks) {
                        $taskList += $task.Name
                    }
                    
                    foreach ($taskName in $taskList) {
                        try {
                            $obsFolder.DeleteTask($taskName, 0)
                            Write-Success "  - Removed remaining task: OBS\$taskName"
                            $removedTasks++
                        } catch {
                            Write-Warning "  - Failed to remove remaining task: $taskName"
                        }
                    }
                    
                    # Remove the OBS folder
                    try {
                        $rootFolder.DeleteFolder("OBS", 0)
                        Write-Success "  - Removed OBS task folder"
                        $cleanupItems += "Removed OBS task folder and $removedTasks task(s)"
                    } catch {
                        Write-Warning "  - Failed to remove OBS task folder (may contain remaining tasks)"
                        if ($removedTasks -gt 0) {
                            $cleanupItems += "Removed $removedTasks scheduled task(s)"
                        }
                    }
                }
            } catch {
                if ($removedTasks -gt 0) {
                    $cleanupItems += "Removed $removedTasks scheduled task(s)"
                }
            }
        } catch {
            Write-Warning "  - Could not access Task Scheduler COM interface"
            if ($removedTasks -gt 0) {
                $cleanupItems += "Removed $removedTasks scheduled task(s)"
            }
        }
        
        # Fallback: Use schtasks command for any remaining OBS tasks
        try {
            $remainingOBSTasks = schtasks /query /fo csv 2>$null | ConvertFrom-Csv | Where-Object { $_.TaskName -like "*OBS*" -or $_.TaskName -like "*AutoRecord*" }
            foreach ($task in $remainingOBSTasks) {
                try {
                    schtasks /delete /tn $task.TaskName /f 2>$null | Out-Null
                    Write-Success "  - Removed task via schtasks: $($task.TaskName)"
                    $removedTasks++
                } catch {
                    Write-Warning "  - Failed to remove task via schtasks: $($task.TaskName)"
                }
            }
            
            if ($remainingOBSTasks.Count -gt 0) {
                $cleanupItems += "Removed $($remainingOBSTasks.Count) additional task(s) via schtasks"
            }
        } catch {
            # schtasks fallback failed, but that's okay
        }
        
        # Remove OBS installation
        if (Test-Path $InstallPath) {
            Write-Info "Removing OBS installation..."
            try {
                $installSize = (Get-ChildItem -Path $InstallPath -Recurse -File | Measure-Object -Property Length -Sum).Sum
                $installSizeMB = [math]::Round($installSize / 1MB, 2)
                
                Remove-Item $InstallPath -Recurse -Force -ErrorAction Stop
                Write-Success "  - Removed OBS installation ($installSizeMB MB)"
                $cleanupItems += "Removed OBS installation ($installSizeMB MB)"
            } catch {
                Write-Warning "  - Failed to remove OBS installation: $($_.Exception.Message)"
            }
        } else {
            Write-Info "  - OBS installation not found"
        }
        
        # Remove service logs
        $logFiles = @(
            "${env:TEMP}\OBSAutoRecord.log",
            "${env:TEMP}\OBS-Complete-Setup-*.log"
        )
        
        $removedLogs = 0
        foreach ($logPattern in $logFiles) {
            $logs = Get-ChildItem -Path $logPattern -ErrorAction SilentlyContinue
            foreach ($log in $logs) {
                try {
                    Remove-Item $log.FullName -Force -ErrorAction Stop
                    $removedLogs++
                } catch {
                    Write-Warning "  - Failed to remove log: $($log.Name)"
                }
            }
        }
        
        if ($removedLogs -gt 0) {
            Write-Success "  - Removed $removedLogs log file(s)"
            $cleanupItems += "Removed $removedLogs log file(s)"
        }
        
        # Summary
        Write-Success ""
        Write-Success "=== Cleanup Summary ==="
        if ($cleanupItems.Count -gt 0) {
            foreach ($item in $cleanupItems) {
                Write-Info "  + $item"
            }
        } else {
            Write-Info "  No items found to clean up"
        }
        
        Write-Success ""
        Write-Success "Cleanup completed successfully!"
        return
    }
    
    if ($TestNotifications) {
        Write-Info "Testing balloon notifications..."
        Show-BalloonNotification -Message "Test notification 1" -Type "Info"
        Start-Sleep -Seconds 3
        Show-BalloonNotification -Message "Test notification 2" -Type "Warning"
        Write-Success "Notification test completed"
        return
    }
    
    # Step 1: System configuration
    $systemConfig = Get-SystemConfiguration -InternalDisplay:$InternalDisplay -ExternalDisplay:$ExternalDisplay -CustomDisplay:$CustomDisplay
    
    if ($CheckOnly) {
        Write-Success ""
        Write-Success "=== Configuration Preview ==="
        Write-Info "Planned OBS Configuration Changes:"
        Write-Info "  Base Resolution: $($systemConfig.Display.ActualResolution.Width)x$($systemConfig.Display.ActualResolution.Height)"
        Write-Info "  Output Resolution: $($systemConfig.Display.RecordingResolution.Width)x$($systemConfig.Display.RecordingResolution.Height)"
        Write-Info "  Encoder: $($systemConfig.GPU.Name)"
        Write-Info "  Bitrate: $($systemConfig.GPU.Bitrate) kbps"
        $audioBitrate = switch ($PerformanceMode) { "33" { "64" } "50" { "96" } "60" { "96" } "75" { "128" } "90" { "160" } }
        $fps = if ($PerformanceMode -eq "33") { "24" } else { "30" }
        Write-Info "  Audio Bitrate: $audioBitrate kbps"
        Write-Info "  FPS: $fps"
        Write-Info "  Format: MKV"
        Write-Info "  Output Path: $($systemConfig.OneDrive.Path)"
        $modeDescription = switch ($PerformanceMode) {
            "33" { "Extreme Performance (33% scaling, $($systemConfig.GPU.Bitrate) kbps, ${fps}fps, ${audioBitrate}kbps audio)" }
            "50" { "Ultra-Lightweight (50% scaling, $($systemConfig.GPU.Bitrate) kbps, ${fps}fps, ${audioBitrate}kbps audio)" }
            "60" { "Lightweight (60% scaling, $($systemConfig.GPU.Bitrate) kbps, ${fps}fps, ${audioBitrate}kbps audio)" }
            "75" { "Optimized (75% scaling, $($systemConfig.GPU.Bitrate) kbps, ${fps}fps, ${audioBitrate}kbps audio)" }
            "90" { "Standard (90% scaling, $($systemConfig.GPU.Bitrate) kbps, ${fps}fps, ${audioBitrate}kbps audio)" }
        }
        Write-Info "  Performance Mode: $modeDescription"
        Write-Success "Environment check complete - system ready"
        return
    }
    
    # Step 2: Install OBS Studio
    $installSuccess = Install-OBSStudio -SystemConfig $systemConfig
    
    if ($installSuccess) {
        # Step 3: Interactive first-time setup
        $firstTimeSuccess = Start-OBSFirstTime -SystemConfig $systemConfig
        
        if ($firstTimeSuccess) {
            # Step 4: Optimize configuration
            $optimizeSuccess = Optimize-OBSConfiguration -SystemConfig $systemConfig
            
            if ($optimizeSuccess) {
                # Step 5: Install scheduled tasks if requested
                if ($InstallScheduledTasks) {
                    if (-not (Test-AdminRights)) {
                        # Build the current command with admin-required parameter
                        $currentParams = @()
                        if ($Force) { $currentParams += "-Force" }
                        if ($EnableNotifications) { $currentParams += "-EnableNotifications" }
                        if ($VerboseLogging) { $currentParams += "-VerboseLogging" }
                        if ($OptimizedCompression) { $currentParams += "-OptimizedCompression" }
                        if ($InternalDisplay) { $currentParams += "-InternalDisplay" }
                        if ($ExternalDisplay) { $currentParams += "-ExternalDisplay" }
                        if ($CustomDisplay) { $currentParams += "-CustomDisplay `"$CustomDisplay`"" }
                        $currentParams += "-InstallScheduledTasks"
                        
                        $adminCommand = ".\Deploy-OBSStudio.ps1 $($currentParams -join ' ')"
                        Show-AdminCommand -CurrentCommand $adminCommand
                        
                        Write-Info "OBS Studio has been installed and configured successfully."
                        Write-Info "Run the admin command above to complete scheduled task installation."
                        $serviceInstalled = $false
                    } else {
                        $serviceInstalled = Install-AutoRecordingService -InstallPath $InstallPath -OneDrivePath $systemConfig.OneDrive.Path
                    }
                } else {
                    $serviceInstalled = $false
                }
                
                # Step 6: Show completion
                Show-BalloonNotification -Message "OBS deployment completed successfully!" -Type "Info"
                
                Write-Success ""
                Write-Success "=== Deployment Complete! ==="
                Write-Info "OBS Studio is ready for recording"
                Write-Info "Hardware: $($systemConfig.GPU.Name)"
                Write-Info "Output: $($systemConfig.OneDrive.Path)"
                $modeMessage = switch ($PerformanceMode) {
                    "33" { "Extreme performance mode: Severe encoder overload prevention enabled" }
                    "50" { "Ultra-lightweight mode: Maximum performance enabled" }
                    "60" { "Lightweight mode: Enhanced performance enabled (default ultra)" }
                    "75" { "Optimized mode: Encoder overflow prevention enabled" }
                    "90" { "Standard mode: Balanced quality and performance" }
                }
                Write-Success $modeMessage
            }
        }
    }
    
} catch {
    Write-Error "Deployment failed: $($_.Exception.Message)"
    exit 1
}
