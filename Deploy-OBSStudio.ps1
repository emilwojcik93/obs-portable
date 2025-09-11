#Requires -Version 5.0
<#
.SYNOPSIS
OBS Studio Infrastructure as Code Deployment Script

.DESCRIPTION
Complete IaC solution for OBS Studio portable deployment with:
    - 5-tier performance optimization system (33%, 50%, 60%, 75%, 90% scaling)
    - Advanced hardware detection with intelligent display selection
    - Auto-configured Display Capture sources with proper monitor IDs
    - Interactive first-time setup with post-configuration automation
    - Enterprise scheduled tasks and protection systems
    - Microsoft OneDrive/SharePoint integration
    - Comprehensive encoder validation and overload prevention
    - Template-based configuration system for maintainability
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
.PARAMETER InstallInputOverlay
    Install Input Overlay plugin with presets for keyboard/mouse/gamepad visualization
.PARAMETER InstallOpenVINO
    Install OpenVINO plugins for Intel hardware acceleration (webcam effects)
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
.EXAMPLE
    .\Deploy-OBSStudio.ps1 -Force -InstallInputOverlay -InstallOpenVINO
    Install OBS Studio with Input Overlay and OpenVINO plugins for enhanced functionality
.EXAMPLE
    .\Deploy-OBSStudio.ps1 -Force -InstallInputOverlay -PerformanceMode 50
    Ultra-lightweight setup with Input Overlay for keyboard/mouse visualization
.EXAMPLE
    .\Deploy-OBSStudio.ps1 -Cleanup -InstallPath "D:\CustomOBS"
    Clean up OBS installation from custom directory
.EXAMPLE
    Test-OBSConfiguration -InstallPath "C:\CustomOBS" -ExpectedConfig @{VBitrate=5000; ABitrate=128}
    Standalone validation of OBS configuration in custom directory
.NOTES
    Author: OBS IaC Team
    Version: 2.0 - Unified Performance System
    Requires: PowerShell 5.0+, Windows 10/11
    GitHub: https://github.com/emilwojcik93/obs-portable
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(HelpMessage = 'Directory where OBS Studio will be installed')]
    [ValidateNotNullOrEmpty()]
    [string]$InstallPath = "${env:USERPROFILE}\OBS-Studio-Portable",

    [Parameter(HelpMessage = 'Enable verbose logging output')]
    [switch]$VerboseLogging,

    [Parameter(HelpMessage = 'Only check environment and hardware')]
    [switch]$CheckOnly,

    [Parameter(HelpMessage = 'Log output to file for testing')]
    [string]$LogToFile,

    [Parameter(HelpMessage = 'Force reinstallation')]
    [switch]$Force,

    [Parameter(HelpMessage = 'Install scheduled tasks for auto-recording (requires admin)')]
    [switch]$InstallScheduledTasks,

    [Parameter(HelpMessage = 'Enable Windows balloon notifications')]
    [switch]$EnableNotifications,

    [Parameter(HelpMessage = 'Remove existing installation and tasks')]
    [switch]$Cleanup,

    [Parameter(HelpMessage = 'Performance optimization level: 33, 50, 60, 75, 90 (% of display resolution)')]
    [ValidateSet('33', '50', '60', '75', '90')]
    [string]$PerformanceMode = '60',

    [Parameter(HelpMessage = 'Test balloon notifications (shows demo)')]
    [switch]$TestNotifications,

    [Parameter(HelpMessage = 'Use primary/main display for recording')]
    [switch]$PrimaryDisplay,

    [Parameter(HelpMessage = 'Use internal display for recording (requires dual display setup)')]
    [switch]$InternalDisplay,

    [Parameter(HelpMessage = 'Use external display for recording (requires dual display setup)')]
    [switch]$ExternalDisplay,

    [Parameter(HelpMessage = 'Use custom resolution for recording (format: 1920x1080)')]
    [ValidatePattern('^\d+x\d+$')]
    [string]$CustomDisplay,

    [Parameter(HelpMessage = 'Install Input Overlay plugin with presets')]
    [switch]$InstallInputOverlay,

    [Parameter(HelpMessage = 'Install OpenVINO plugins for Intel hardware acceleration (webcam effects)')]
    [switch]$InstallOpenVINO,

    [Parameter(HelpMessage = 'Validate OBS configuration after deployment (default: true)')]
    [bool]$ValidateConfiguration = $true,

    [Parameter(HelpMessage = 'Update OBS configuration only without reinstallation')]
    [switch]$ConfigurationOnly,

    [Parameter(HelpMessage = 'Test all display parameter cases for debugging')]
    [switch]$TestDisplayParameters,

    [Parameter(HelpMessage = 'Test display detection methods only')]
    [switch]$TestDisplayMethods,

    [Parameter(HelpMessage = 'Deploy OBS silently without Auto-Configuration Wizard (fully unattended)')]
    [switch]$SilentDeployment
)

$ErrorActionPreference = 'Stop'

# Initialize logging to file by default
if (-not $LogToFile) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $LogToFile = "${env:TEMP}\OBS-Deploy-Log-${timestamp}.log"
}
$script:LogToFile = $LogToFile

# Detect if running in elevated session (to prevent window closure)
$script:IsElevatedSession = $false
$script:RequiresElevation = $InstallScheduledTasks -or $InstallInputOverlay -or $InstallOpenVINO

# Auto-elevation for admin required operations (inspired by winutil)
if ($script:RequiresElevation) {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host 'Admin rights required for requested operations. Attempting to relaunch with elevation...' -ForegroundColor Yellow

        # Build argument list preserving all parameters
        $argList = @()
        $PSBoundParameters.GetEnumerator() | ForEach-Object {
            $argList += if ($_.Value -is [switch] -and $_.Value) {
                "-$($_.Key)"
            } elseif ($_.Value -is [array]) {
                "-$($_.Key) $($_.Value -join ',')"
            } elseif ($_.Value) {
                "-$($_.Key) '$($_.Value)'"
            }
        }

        # Pass log file parameter to elevated session
        $argList += "-LogToFile `"$LogToFile`""

        # Create temporary wrapper script to avoid command parsing issues
        $wrapperScript = "${env:TEMP}\OBS-Elevated-Wrapper-$(Get-Date -Format 'yyyyMMdd-HHmmss').ps1"

        $wrapperContent = if ($PSCommandPath) {
            # Local execution
            @"
try {
    Set-Location '$PWD'
    & '$($PSCommandPath)' $($argList -join ' ')
    `$exitCode = `$LASTEXITCODE
} catch {
    Write-Error `$_.Exception.Message
    `$exitCode = 1
}
Write-Host ''
Write-Host '=== Elevated Session Complete ===' -ForegroundColor Green
if (`$exitCode -eq 0) {
    Write-Host 'Deployment completed successfully!' -ForegroundColor Green
} else {
    Write-Host 'Deployment completed with errors.' -ForegroundColor Yellow
}
Write-Host ''
Write-Host 'Press Enter to close this elevated window...' -ForegroundColor Yellow
`$null = Read-Host
Remove-Item '$wrapperScript' -Force -ErrorAction SilentlyContinue
"@
        } else {
            # Remote execution
            @"
try {
    Set-Location '$PWD'
    &([ScriptBlock]::Create((irm https://github.com/emilwojcik93/obs-portable/releases/latest/download/Deploy-OBSStudio.ps1))) $($argList -join ' ')
    `$exitCode = `$LASTEXITCODE
} catch {
    Write-Error `$_.Exception.Message
    `$exitCode = 1
}
Write-Host ''
Write-Host '=== Elevated Session Complete ===' -ForegroundColor Green
if (`$exitCode -eq 0) {
    Write-Host 'Deployment completed successfully!' -ForegroundColor Green
} else {
    Write-Host 'Deployment completed with errors.' -ForegroundColor Yellow
}
Write-Host ''
Write-Host 'Press Enter to close this elevated window...' -ForegroundColor Yellow
`$null = Read-Host
Remove-Item '$wrapperScript' -Force -ErrorAction SilentlyContinue
"@
        }

        # Write wrapper script and ensure it exists
        try {
            $wrapperContent | Out-File -FilePath $wrapperScript -Encoding UTF8 -Force
            Start-Sleep -Milliseconds 500  # Give filesystem time to sync

            if (-not (Test-Path $wrapperScript)) {
                throw 'Wrapper script was not created successfully'
            }

            Write-Host "Wrapper script created: $wrapperScript" -ForegroundColor Cyan
        } catch {
            Write-Error "Failed to create wrapper script: $($_.Exception.Message)"
            return
        }

        # Choose best terminal (Windows Terminal > PowerShell 7 > Windows PowerShell)
        $powershellCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
        $processCmd = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { 'wt.exe' } else { "$powershellCmd" }

        try {
            if ($processCmd -eq 'wt.exe') {
                Start-Process $processCmd -ArgumentList "$powershellCmd -ExecutionPolicy Bypass -NoProfile -File `"$wrapperScript`"" -Verb RunAs
            } else {
                Start-Process $processCmd -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$wrapperScript`"" -Verb RunAs
            }

            Write-Host 'Launched elevated session. Please check the new window.' -ForegroundColor Green
            return
        } catch {
            Write-Error "Failed to launch elevated session: $($_.Exception.Message)"
            Write-Warning 'Please run the script manually as Administrator for full functionality'
            return
        }
    } else {
        Write-Host 'Running with administrator privileges' -ForegroundColor Green

        # Detect if launched from elevation (based on parent process)
        try {
            $parentProcess = Get-Process -Id (Get-WmiObject -Class Win32_Process -Filter "ProcessId=$PID").ParentProcessId -ErrorAction SilentlyContinue
            if ($parentProcess -and ($parentProcess.ProcessName -match '^(explorer|winlogon|services)$' -or $parentProcess.MainWindowTitle -like '*Administrator*')) {
                $script:IsElevatedSession = $true
                Write-Host 'Detected elevated session - will pause at completion for review' -ForegroundColor Cyan
            }
        } catch {
            # Ignore errors in parent process detection
        }
    }
}

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-AdminCommand {
    param([string]$CurrentCommand)

    Write-Host ''
    Write-Warning 'Administrator rights are required for scheduled task installation.'
    Write-Host ''
    Write-Host 'Please run the following command from an elevated PowerShell window:' -ForegroundColor Yellow
    Write-Host ''
    Write-Host $CurrentCommand -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'To open elevated PowerShell:' -ForegroundColor Gray
    Write-Host '1. Press Win+X' -ForegroundColor Gray
    Write-Host "2. Select 'Windows PowerShell (Admin)' or 'Terminal (Admin)'" -ForegroundColor Gray
    Write-Host "3. Navigate to: $PWD" -ForegroundColor Gray
    Write-Host '4. Run the command above' -ForegroundColor Gray
    Write-Host ''
}

function Write-Info {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
    if ($script:LogToFile) { Add-Content -Path $script:LogToFile -Value $Message }
}
function Write-Success {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Green
    if ($script:LogToFile) { Add-Content -Path $script:LogToFile -Value $Message }
}
function Write-Warning {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Yellow
    if ($script:LogToFile) { Add-Content -Path $script:LogToFile -Value $Message }
}
function Write-Error {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    if ($script:LogToFile) { Add-Content -Path $script:LogToFile -Value $Message }
}

function Invoke-RobustDownload {
    param(
        [string]$Uri,
        [string]$OutFile,
        [string]$Description = 'file',
        [bool]$ShowProgress = $true
    )

    Write-Info "Downloading $Description..."
    $success = $false
    $lastError = $null

    # Method 1: Start-BitsTransfer (Primary - most reliable for large files)
    try {
        if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
            Write-Verbose 'Attempting download with BITS transfer service...'

            if ($ShowProgress) {
                Start-BitsTransfer -Source $Uri -Destination $OutFile -DisplayName "Downloading $Description" -Description 'OBS Studio deployment'
            } else {
                Start-BitsTransfer -Source $Uri -Destination $OutFile
            }

            if (Test-Path $OutFile) {
                Write-Success "Successfully downloaded $Description using BITS"
                return $true
            }
        }
    } catch {
        $lastError = $_.Exception.Message
        Write-Verbose "BITS transfer failed: $lastError"
        Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
    }

    # Method 2: Invoke-WebRequest (Fallback)
    try {
        Write-Verbose 'Attempting download with Invoke-WebRequest...'

        $progressPreference = if ($ShowProgress) { 'Continue' } else { 'SilentlyContinue' }
        $originalPreference = $ProgressPreference
        $ProgressPreference = $progressPreference

        Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
        $ProgressPreference = $originalPreference

        if (Test-Path $OutFile) {
            Write-Success "Successfully downloaded $Description using Invoke-WebRequest"
            return $true
        }
    } catch {
        $lastError = $_.Exception.Message
        Write-Verbose "Invoke-WebRequest failed: $lastError"
        Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
        $ProgressPreference = $originalPreference
    }

    # Method 3: System.Net.WebClient (Fallback for older systems)
    try {
        Write-Verbose 'Attempting download with WebClient...'

        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add('User-Agent', 'OBS-Deploy-Script/2.0')

        if ($ShowProgress) {
            Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -Action {
                $percent = $Event.SourceEventArgs.ProgressPercentage
                Write-Progress -Activity "Downloading $Description" -Status "$percent% Complete" -PercentComplete $percent
            } | Out-Null
        }

        $webClient.DownloadFile($Uri, $OutFile)
        $webClient.Dispose()

        if ($ShowProgress) {
            Write-Progress -Activity "Downloading $Description" -Completed
        }

        if (Test-Path $OutFile) {
            Write-Success "Successfully downloaded $Description using WebClient"
            return $true
        }
    } catch {
        $lastError = $_.Exception.Message
        Write-Verbose "WebClient failed: $lastError"
        Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
        if ($ShowProgress) {
            Write-Progress -Activity "Downloading $Description" -Completed
        }
    }

    # All methods failed
    throw "Failed to download $Description from $Uri. Last error: $lastError"
}

function Show-BalloonNotification {
    param(
        [string]$Title = 'OBS Studio',
        [string]$Message,
        [string]$Type = 'Info',
        [int]$Duration = 5000
    )

    if (-not $EnableNotifications -and -not $TestNotifications) { return }

    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $balloon = New-Object System.Windows.Forms.NotifyIcon

        switch ($Type) {
            'Warning' {
                $balloon.Icon = [System.Drawing.SystemIcons]::Warning
                $balloon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning
            }
            'Error' {
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

function Test-DisplayMethods {
    Write-Host ''
    Write-Host '=== Testing All Display Detection Methods ===' -ForegroundColor Yellow
    Write-Host ''

    # Test 1: Windows Forms Screen Detection
    Write-Host '1. Windows Forms Screen Detection:' -ForegroundColor Cyan
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $screens = [System.Windows.Forms.Screen]::AllScreens
        foreach ($screen in $screens) {
            Write-Host "  - Screen: $($screen.DeviceName) | Bounds: $($screen.Bounds.Width)x$($screen.Bounds.Height) | Primary: $($screen.Primary) | WorkingArea: $($screen.WorkingArea.Width)x$($screen.WorkingArea.Height)" -ForegroundColor White
        }
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ''

    # Test 2: WMI Video Controller Detection
    Write-Host '2. WMI Video Controller Detection:' -ForegroundColor Cyan
    try {
        $videoControllers = Get-CimInstance -ClassName Win32_VideoController | Where-Object { $_.CurrentHorizontalResolution -and $_.CurrentVerticalResolution }
        foreach ($controller in $videoControllers) {
            Write-Host "  - Controller: $($controller.Name) | Resolution: $($controller.CurrentHorizontalResolution)x$($controller.CurrentVerticalResolution)" -ForegroundColor White
        }
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ''

    # Test 3: WMI Monitor Detection
    Write-Host '3. WMI Monitor Detection:' -ForegroundColor Cyan
    try {
        $wmiMonitors = Get-WmiObject -Namespace 'root\WMI' -Class 'WMIMonitorID' -ErrorAction SilentlyContinue
        foreach ($monitor in $wmiMonitors) {
            $monModel = 'Unknown'
            $monManufacturer = 'Unknown'
            $monManufacturerCode = 'UNK'

            try {
                if ($monitor.UserFriendlyName) {
                    $monModel = ($monitor.UserFriendlyName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }) -join ''
                }
                if ($monitor.ManufacturerName) {
                    $monManufacturer = ($monitor.ManufacturerName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }) -join ''
                }
                if ($monitor.ManufacturerName -and $monitor.ManufacturerName.Count -ge 3) {
                    $monManufacturerCode = ($monitor.ManufacturerName[0..2] | ForEach-Object { [char]$_ }) -join ''
                }
            } catch { }

            Write-Host "  - Monitor: $monModel | Manufacturer: $monManufacturer ($monManufacturerCode) | InstanceName: $($monitor.InstanceName)" -ForegroundColor White
        }
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ''

    # Test 4: Desktop Monitor Detection
    Write-Host '4. Win32_DesktopMonitor Detection:' -ForegroundColor Cyan
    try {
        $desktopMonitors = Get-CimInstance -ClassName Win32_DesktopMonitor
        foreach ($monitor in $desktopMonitors) {
            $resolutionText = if ($monitor.ScreenWidth -and $monitor.ScreenHeight) {
                "$($monitor.ScreenWidth)x$($monitor.ScreenHeight)"
            } else {
                'Unknown (no resolution data)'
            }
            $monitorName = if ($monitor.Name) { $monitor.Name } else { 'Unknown Monitor' }
            Write-Host "  - Desktop Monitor: $monitorName | Resolution: $resolutionText" -ForegroundColor White

            # Show additional properties for debugging
            Write-Host "    Properties: DeviceID=$($monitor.DeviceID), PNPDeviceID=$($monitor.PNPDeviceID)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ''

    # Test 5: Additional Monitor Properties from WMI
    Write-Host '5. Additional Monitor Properties:' -ForegroundColor Cyan
    try {
        $wmiMonitors = Get-WmiObject -Namespace 'root\WMI' -Class 'WMIMonitorID' -ErrorAction SilentlyContinue
        foreach ($monitor in $wmiMonitors) {
            $monModel = 'Unknown'
            $monManufacturer = 'Unknown'
            $monSerial = 'Unknown'

            try {
                if ($monitor.UserFriendlyName) {
                    $monModel = ($monitor.UserFriendlyName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }) -join ''
                }
                if ($monitor.ManufacturerName) {
                    $monManufacturer = ($monitor.ManufacturerName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }) -join ''
                    $monManufacturerCode = ($monitor.ManufacturerName[0..2] | ForEach-Object { [char]$_ }) -join ''
                }
                if ($monitor.SerialNumberID) {
                    $monSerial = ($monitor.SerialNumberID | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }) -join ''
                }
            } catch { }

            Write-Host "  - Monitor: $monModel" -ForegroundColor White
            Write-Host "    Manufacturer: $monManufacturer" -ForegroundColor Gray
            Write-Host "    Serial: $monSerial" -ForegroundColor Gray
            Write-Host "    Instance: $($monitor.InstanceName)" -ForegroundColor Gray
            Write-Host "    Active: $($monitor.Active)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ''


    Write-Host '=== Display Method Testing Complete ===' -ForegroundColor Yellow
    Write-Host ''
}

function Test-DisplayParameters {
    Write-Host ''
    Write-Host '=== Testing All Display Parameter Cases ===' -ForegroundColor Yellow
    Write-Host ''

    # First, run the method testing
    Test-DisplayMethods

    $testCases = @(
        @{ Name = 'Primary Display'; Params = @{ PrimaryDisplay = $true } }
        @{ Name = 'Internal Display'; Params = @{ InternalDisplay = $true } }
        @{ Name = 'External Display'; Params = @{ ExternalDisplay = $true } }
        @{ Name = 'Custom Display (1280x720)'; Params = @{ CustomDisplay = '1280x720' } }
    )

    foreach ($testCase in $testCases) {
        Write-Host "Testing: $($testCase.Name)" -ForegroundColor Cyan
        try {
            $params = $testCase.Params
            $result = Get-DisplayConfiguration @params
            Write-Host "  Result: $($result.Width)x$($result.Height) - $($result.Source)" -ForegroundColor Green
            Write-Host "  MonitorId: $($result.MonitorId)" -ForegroundColor Gray
        } catch {
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        Write-Host ''
    }

    # Test additional custom display case
    try {
        Write-Host 'Testing: Custom Display (5120x1440)' -ForegroundColor Cyan
        $customResult = Get-DisplayConfiguration -CustomDisplay '5120x1440'
        Write-Host "  Result: $($customResult.Width)x$($customResult.Height) - $($customResult.Source)" -ForegroundColor Green
        Write-Host "  MonitorId: $($customResult.MonitorId)" -ForegroundColor Gray
    } catch {
        Write-Host "  Custom Display Test Error: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host '=== Display Parameter Testing Complete ===' -ForegroundColor Yellow
    Write-Host ''
}

function Get-DisplayConfiguration {
    param(
        [switch]$PrimaryDisplay,
        [switch]$InternalDisplay,
        [switch]$ExternalDisplay,
        [string]$CustomDisplay,
        [switch]$CheckOnly
    )

    # If CheckOnly mode, auto-select primary display immediately without interactive prompts
    if ($CheckOnly) {
        Add-Type -AssemblyName System.Windows.Forms
        $screens = [System.Windows.Forms.Screen]::AllScreens
        $primaryScreen = $screens | Where-Object { $_.Primary } | Select-Object -First 1
        if (-not $primaryScreen) { $primaryScreen = $screens[0] }

        return @{
            Width     = $primaryScreen.Bounds.Width
            Height    = $primaryScreen.Bounds.Height
            Source    = 'CheckOnly - Primary Display'
            Display   = $null
            MonitorId = $null
        }
    }

    # Get all available displays with both Forms and WMI data
    Add-Type -AssemblyName System.Windows.Forms
    $screens = [System.Windows.Forms.Screen]::AllScreens

    # Get actual display resolutions from WMI (not DPI-scaled)
    $wmiDisplays = @()
    try {
        $videoControllers = Get-CimInstance -ClassName Win32_VideoController | Where-Object { $_.CurrentHorizontalResolution -and $_.CurrentVerticalResolution }
        Write-Verbose 'WMI Video Controllers detected:'
        foreach ($controller in $videoControllers) {
            Write-Verbose "  - $($controller.Name): $($controller.CurrentHorizontalResolution)x$($controller.CurrentVerticalResolution)"
            $wmiDisplays += @{
                Width  = $controller.CurrentHorizontalResolution
                Height = $controller.CurrentVerticalResolution
                Name   = $controller.Name
            }
        }
    } catch {
        Write-Verbose "Failed to get WMI display data: $($_.Exception.Message)"
        $wmiDisplays = @()
    }

    # Get detailed monitor information from WMI using proven Get-Monitor.ps1 logic
    function Get-MonitorInfo {
        try {
            # Manufacturer hash table from Get-Monitor.ps1 for friendly names
            $ManufacturerHash = @{
                'AAC' = 'AcerView'; 'ACR' = 'Acer'; 'AOC' = 'AOC'; 'AIC' = 'AG Neovo';
                'APP' = 'Apple Computer'; 'AST' = 'AST Research'; 'AUO' = 'Asus'; 'BNQ' = 'BenQ';
                'CMO' = 'Acer'; 'CPL' = 'Compal'; 'CPQ' = 'Compaq'; 'CPT' = 'Chunghwa Picture Tubes, Ltd.';
                'CTX' = 'CTX'; 'DEC' = 'DEC'; 'DEL' = 'Dell'; 'DPC' = 'Delta'; 'DWE' = 'Daewoo';
                'EIZ' = 'EIZO'; 'ELS' = 'ELSA'; 'ENC' = 'EIZO'; 'EPI' = 'Envision'; 'FCM' = 'Funai';
                'FUJ' = 'Fujitsu'; 'FUS' = 'Fujitsu-Siemens'; 'GSM' = 'LG Electronics'; 'GWY' = 'Gateway 2000';
                'HEI' = 'Hyundai'; 'HIT' = 'Hyundai'; 'HSL' = 'Hansol'; 'HTC' = 'Hitachi/Nissei';
                'HWP' = 'HP'; 'IBM' = 'IBM'; 'ICL' = 'Fujitsu ICL'; 'IVM' = 'Iiyama';
                'KDS' = 'Korea Data Systems'; 'LEN' = 'Lenovo'; 'LGD' = 'Asus'; 'LPL' = 'Fujitsu';
                'MAX' = 'Belinea'; 'MEI' = 'Panasonic'; 'MEL' = 'Mitsubishi Electronics'; 'MS_' = 'Panasonic';
                'NAN' = 'Nanao'; 'NEC' = 'NEC'; 'NOK' = 'Nokia Data'; 'NVD' = 'Fujitsu';
                'OPT' = 'Optoma'; 'PHL' = 'Philips'; 'REL' = 'Relisys'; 'SAN' = 'Samsung';
                'SAM' = 'Samsung'; 'SBI' = 'Smarttech'; 'SGI' = 'SGI'; 'SNY' = 'Sony';
                'SRC' = 'Shamrock'; 'SUN' = 'Sun Microsystems'; 'SEC' = 'Hewlett-Packard';
                'TAT' = 'Tatung'; 'TOS' = 'Toshiba'; 'TSB' = 'Toshiba'; 'VSC' = 'ViewSonic';
                'ZCM' = 'Zenith'; 'UNK' = 'Unknown'; '_YV' = 'Fujitsu'
            }

            $monitors = @()

            # Use the exact working method from Get-Monitor.ps1
            $wmiMonitors = Get-WmiObject -Namespace 'root\WMI' -Class 'WMIMonitorID' -ErrorAction SilentlyContinue

            foreach ($monitor in $wmiMonitors) {
                # Extract and clean monitor data using Get-Monitor.ps1 logic with error handling
                $monModel = $null
                $monSerialNumber = 'Unknown'
                $monManufacturer = 'UNK'

                try {
                    if ($monitor.UserFriendlyName -and $monitor.UserFriendlyName.Length -gt 0) {
                        $monModel = ([System.Text.Encoding]::ASCII.GetString($monitor.UserFriendlyName)).Replace("$([char]0x0000)", '')
                    }
                } catch { }

                try {
                    if ($monitor.SerialNumberID -and $monitor.SerialNumberID.Length -gt 0) {
                        $monSerialNumber = ([System.Text.Encoding]::ASCII.GetString($monitor.SerialNumberID)).Replace("$([char]0x0000)", '')
                    }
                } catch { }

                try {
                    if ($monitor.ManufacturerName -and $monitor.ManufacturerName.Length -gt 0) {
                        $monManufacturer = ([System.Text.Encoding]::ASCII.GetString($monitor.ManufacturerName)).Replace("$([char]0x0000)", '')
                    }
                } catch { }

                # Only skip if we have absolutely no useful data
                if (-not $monModel -and $monManufacturer -eq 'UNK') { continue }

                # Get friendly manufacturer name from hash table
                $monManufacturerFriendly = $ManufacturerHash.$monManufacturer
                if ($monManufacturerFriendly -eq $null) {
                    $monManufacturerFriendly = $monManufacturer
                }

                # Use a generic name if model is not available but manufacturer is
                if (-not $monModel -and $monManufacturer -ne 'UNK') {
                    $monModel = "$monManufacturerFriendly Monitor"
                }

                $monitors += @{
                    Manufacturer     = $monManufacturerFriendly
                    ManufacturerCode = $monManufacturer
                    Name             = $monModel
                    SerialNumber     = $monSerialNumber
                    InstanceName     = $monitor.InstanceName
                }
            }

            # If no WMI data found, try fallback method
            if ($monitors.Count -eq 0) {
                try {
                    $desktopMonitors = Get-CimInstance -ClassName Win32_DesktopMonitor | Where-Object { $_.ScreenWidth -and $_.ScreenHeight }
                    foreach ($desktopMonitor in $desktopMonitors) {
                        $monitors += @{
                            Manufacturer     = if ($desktopMonitor.MonitorManufacturer) { $desktopMonitor.MonitorManufacturer } else { 'Unknown' }
                            ManufacturerCode = 'UNK'
                            Name             = if ($desktopMonitor.Name) { $desktopMonitor.Name } else { 'Generic Monitor' }
                            SerialNumber     = 'Unknown'
                            InstanceName     = $desktopMonitor.DeviceID
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
            # For secondary (non-primary) screens, try to find matching WMI data
            # First try exact match
            $matchingWMI = $wmiDisplays | Where-Object {
                $_.Width -eq $actualWidth -and $_.Height -eq $actualHeight
            } | Select-Object -First 1

            # If no exact match, try aspect ratio matching but exclude controllers that are already used by primary display
            if (-not $matchingWMI -and $actualWidth -gt 0 -and $actualHeight -gt 0) {
                # Check if we have a primary display with much larger resolution
                $primaryScreen = $screens | Where-Object { $_.Primary }
                $excludeControllers = @()

                if ($primaryScreen) {
                    # Find controllers that likely belong to primary display (much larger resolution)
                    $excludeControllers = $wmiDisplays | Where-Object {
                        ($_.Width * $_.Height) -gt ($actualWidth * $actualHeight * 2)  # At least 2x larger
                    }
                    Write-Verbose "Excluding controllers for secondary display matching: $($excludeControllers | ForEach-Object { "$($_.Name) ($($_.Width)x$($_.Height))" })"
                }

                $availableControllers = $wmiDisplays | Where-Object { $_ -notin $excludeControllers }

                if ($availableControllers) {
                    $targetAspectRatio = $actualWidth / $actualHeight
                    $matchingWMI = $availableControllers | ForEach-Object {
                        $wmiAspectRatio = $_.Width / $_.Height
                        $aspectDifference = [math]::Abs($targetAspectRatio - $wmiAspectRatio)
                        [PSCustomObject]@{
                            Display          = $_
                            AspectDifference = $aspectDifference
                        }
                    } | Sort-Object AspectDifference | Select-Object -First 1 | Select-Object -ExpandProperty Display
                }
            }

            if ($matchingWMI) {
                Write-Verbose "Found WMI match for secondary display: $($matchingWMI.Width)x$($matchingWMI.Height) (from $($matchingWMI.Name))"
                $actualWidth = $matchingWMI.Width
                $actualHeight = $matchingWMI.Height
            } else {
                Write-Verbose "No WMI match found for secondary display, using Forms data: ${actualWidth}x${actualHeight}"
            }
        }
        # For primary screen, use WMI data if available to get actual current resolution
        if ($screen.Primary -and $wmiDisplays.Count -gt 0) {
            # Try to find matching WMI display data using AND logic for better accuracy
            $primaryWMI = $wmiDisplays | Where-Object {
                $_.Width -eq $actualWidth -and $_.Height -eq $actualHeight
            } | Select-Object -First 1

            # If exact match not found, try to find the best match by aspect ratio similarity
            if (-not $primaryWMI) {
                $targetAspectRatio = $actualWidth / $actualHeight
                $primaryWMI = $wmiDisplays | ForEach-Object {
                    $wmiAspectRatio = $_.Width / $_.Height
                    $aspectDifference = [math]::Abs($targetAspectRatio - $wmiAspectRatio)
                    [PSCustomObject]@{
                        Display          = $_
                        AspectDifference = $aspectDifference
                    }
                } | Sort-Object AspectDifference | Select-Object -First 1 | Select-Object -ExpandProperty Display
            }

            if ($primaryWMI) {
                # Use WMI resolution as it reflects current display settings
                $actualWidth = $primaryWMI.Width
                $actualHeight = $primaryWMI.Height
                Write-Verbose "Using WMI resolution for primary display: ${actualWidth}x${actualHeight} (from $($primaryWMI.Name))"
            } else {
                # Fallback: Only apply DPI scaling correction if resolution looks unusually small
                # and we can't find matching WMI data (this preserves intentional low resolutions)
                if ($actualWidth -lt 1280 -and $actualHeight -lt 720) {
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
                            Write-Verbose "Applied DPI scaling correction: ${actualWidth}x${actualHeight}"
                            break
                        }
                    }
                }
            }
        }

        $displayInfo = @{
            Index       = $displayIndex
            Width       = $actualWidth
            Height      = $actualHeight
            X           = $screen.Bounds.X
            Y           = $screen.Bounds.Y
            Primary     = $screen.Primary
            DeviceName  = $screen.DeviceName
            WorkingArea = "$($screen.WorkingArea.Width)x$($screen.WorkingArea.Height)"
            MonitorId   = $null  # Will be set below if monitor info is available
        }

        # Try to match with WMI monitor info
        $monitor = $null
        if ($monitorInfo.Count -gt 0) {
            Write-Verbose "Matching display $displayIndex (${actualWidth}x${actualHeight}, Primary: $($screen.Primary)) with available monitors:"
            foreach ($mon in $monitorInfo) {
                Write-Verbose "  - Available: $($mon.Name) ($($mon.ManufacturerCode)) - InstanceName: $($mon.InstanceName)"
            }

            # Try to intelligently match displays with monitors based on characteristics
            $availableMonitors = if ($script:usedMonitors) {
                $monitorInfo | Where-Object {
                    $_.Name -and $_.Name -ne '' -and $_.Manufacturer -and $_.Manufacturer -ne '' -and
                    $script:usedMonitors -notcontains $_
                }
            } else {
                $monitorInfo | Where-Object { $_.Name -and $_.Name -ne '' -and $_.Manufacturer -and $_.Manufacturer -ne '' }
            }

            if ($availableMonitors) {
                # Method 1: Try to match displays based on resolution similarity
                # Primary display (1280x720) should match with similar resolution monitor
                # Non-primary display (5120x1440) should match with similar resolution monitor

                if ($actualWidth -eq 1280 -and $actualHeight -eq 720) {
                    # This is the 1280x720 display, should get TMX internal monitor
                    $monitor = $availableMonitors | Where-Object { $_.ManufacturerCode -eq 'TMX' } | Select-Object -First 1
                    if ($monitor) {
                        Write-Verbose "Matched 1280x720 display with TMX internal monitor: $($monitor.Name)"
                    }
                } elseif ($actualWidth -eq 5120 -and $actualHeight -eq 1440) {
                    # This is the 5120x1440 display, should get PHL external monitor
                    $monitor = $availableMonitors | Where-Object { $_.ManufacturerCode -eq 'PHL' } | Select-Object -First 1
                    if ($monitor) {
                        Write-Verbose "Matched 5120x1440 display with PHL external monitor: $($monitor.Name)"
                    }
                }

                # Method 2: Fallback - For primary display, prefer internal manufacturers (TMX for laptops)
                if (-not $monitor -and $screen.Primary) {
                    $internalManufacturers = @('TMX', 'LGD', 'AUO', 'BOE', 'CMN', 'CSO', 'INL', 'SDC', 'SHP')
                    $monitor = $availableMonitors | Where-Object { $_.ManufacturerCode -in $internalManufacturers } | Select-Object -First 1
                    if ($monitor) {
                        Write-Verbose "Matched primary display with internal monitor: $($monitor.Name) ($($monitor.ManufacturerCode))"
                    }
                }

                # Method 3: For non-primary display, prefer external manufacturers
                if (-not $monitor -and -not $screen.Primary) {
                    $externalManufacturers = @('PHL', 'DEL', 'SAM', 'AOC', 'BNQ', 'ASU', 'MSI', 'HWP')
                    $monitor = $availableMonitors | Where-Object { $_.ManufacturerCode -in $externalManufacturers } | Select-Object -First 1
                    if ($monitor) {
                        Write-Verbose "Matched non-primary display with external monitor: $($monitor.Name) ($($monitor.ManufacturerCode))"
                    }
                }

                # Method 3: Fallback - use first available monitor
                if (-not $monitor) {
                    $monitor = $availableMonitors | Select-Object -First 1
                    Write-Verbose "Fallback: Assigned first available monitor to display $displayIndex`: $($monitor.Name) ($($monitor.ManufacturerCode))"
                }

                # Track used monitors
                if ($monitor) {
                    if (-not $script:usedMonitors) { $script:usedMonitors = @() }
                    $script:usedMonitors += $monitor
                }
            } else {
                Write-Verbose "No available monitors for display $displayIndex"
            }
        }

        if ($monitor -and $monitor.Name) {
            $displayInfo.Name = $monitor.Name
            $displayInfo.Manufacturer = $monitor.Manufacturer
            $displayInfo.ManufacturerCode = $monitor.ManufacturerCode
            $displayInfo.Model = $monitor.Name
            $displayInfo.SerialNumber = $monitor.SerialNumber

            # Convert WMI InstanceName to OBS monitor ID format
            if ($monitor.InstanceName) {
                # OBS uses a specific format: \\?\DISPLAY#...#{GUID}
                # The InstanceName from WMI is in format: DISPLAY\Manufacturer\ID_Instance
                # We need to convert it to: \\?\DISPLAY#Manufacturer#ID#{GUID}
                $instanceParts = $monitor.InstanceName -split '\\'
                if ($instanceParts.Count -ge 3) {
                    # Remove _0 suffix from UID part to match OBS format
                    $devicePart = $instanceParts[2] -replace '_0$', ''
                    $displayInfo.MonitorId = "\\?\DISPLAY#$($instanceParts[1])#$devicePart#{e6f07b5f-ee97-4a90-b076-33f57bf4eaa7}"
                } else {
                    # Fallback format
                    $displayInfo.MonitorId = $monitor.InstanceName -replace '^DISPLAY\\', '\\?\DISPLAY#' -replace '\\', '#'
                    # Remove _0 suffix from UID part to match OBS format
                    $displayInfo.MonitorId = $displayInfo.MonitorId -replace '_0#', '#'
                    if ($displayInfo.MonitorId -notmatch '\{[a-f0-9\-]+\}$') {
                        $displayInfo.MonitorId += '#{e6f07b5f-ee97-4a90-b076-33f57bf4eaa7}'
                    }
                }
                Write-Verbose "Monitor ID for $($monitor.Name): $($displayInfo.MonitorId) (from InstanceName: $($monitor.InstanceName))"
            }

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
                $displayInfo.Name = 'Primary Display'
            } else {
                $displayInfo.Name = "Display $displayIndex"
            }
            $displayInfo.Manufacturer = 'Unknown'
            $displayInfo.ManufacturerCode = 'UNK'
            $displayInfo.Model = 'Generic Monitor'
            $displayInfo.SerialNumber = 'Unknown'
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
                Width     = $customWidth
                Height    = $customHeight
                Source    = "Custom ($CustomDisplay)"
                Display   = $matchingDisplay
                MonitorId = $matchingDisplay.MonitorId
            }
        }
    }

    # Handle primary display selection
    if ($PrimaryDisplay) {
        $selectedDisplay = $displays | Where-Object { $_.Primary } | Select-Object -First 1
        if (-not $selectedDisplay) { $selectedDisplay = $displays[0] }

        $displayName = if ($selectedDisplay.Name) { $selectedDisplay.Name } else { 'Primary Display' }
        return @{
            Width     = $selectedDisplay.Width
            Height    = $selectedDisplay.Height
            Source    = "Primary Display - $displayName"
            Display   = $selectedDisplay
            MonitorId = $selectedDisplay.MonitorId
        }
    }

    # Handle internal/external display selection
    if ($InternalDisplay -or $ExternalDisplay) {
        if ($displays.Count -lt 2) {
            Write-Error "Internal/External display selection requires dual display setup. Only $($displays.Count) display(s) detected."
            exit 1
        }

        if ($InternalDisplay) {
            # For internal display, use multiple detection methods with priority order
            Write-Verbose 'Available displays for internal selection:'
            foreach ($disp in $displays) {
                Write-Verbose "  - $($disp.Name): $($disp.Width)x$($disp.Height) (Primary: $($disp.Primary)) - MonitorId: $($disp.MonitorId)"
            }

            $selectedDisplay = $null

            # Method 1: Look for TMX (internal laptop display) manufacturer code
            $selectedDisplay = $displays | Where-Object { $_.MonitorId -like '*TMX*' } | Select-Object -First 1
            if ($selectedDisplay) {
                Write-Verbose "Found internal display by TMX manufacturer code: $($selectedDisplay.Name)"
            }

            # Method 2: Look for common internal display manufacturer codes (LGD, AUO, BOE, etc.)
            if (-not $selectedDisplay) {
                $internalManufacturers = @('LGD', 'AUO', 'BOE', 'CMN', 'CSO', 'INL', 'LEN', 'SDC', 'SHP')
                foreach ($manufacturer in $internalManufacturers) {
                    $selectedDisplay = $displays | Where-Object { $_.MonitorId -like "*$manufacturer*" } | Select-Object -First 1
                    if ($selectedDisplay) {
                        Write-Verbose "Found internal display by manufacturer code '$manufacturer': $($selectedDisplay.Name)"
                        break
                    }
                }
            }

            # Method 3: If laptop (detected by battery), prefer the display with TMX monitor or smaller resolution
            if (-not $selectedDisplay) {
                $isLaptop = $null -ne (Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue)
                if ($isLaptop) {
                    # First try to find display with TMX monitor ID
                    $selectedDisplay = $displays | Where-Object { $_.MonitorId -like '*TMX*' } | Select-Object -First 1
                    if ($selectedDisplay) {
                        Write-Verbose "Selected display with TMX monitor on laptop: $($selectedDisplay.Name)"
                    } else {
                        # Fallback: prefer smaller display (likely internal)
                        $selectedDisplay = $displays | Sort-Object { $_.Width * $_.Height } | Select-Object -First 1
                        if ($selectedDisplay) {
                            Write-Verbose "Selected smallest display on laptop as internal: $($selectedDisplay.Name)"
                        }
                    }
                }
            }

            # Method 4: Fallback to smaller display (by resolution)
            if (-not $selectedDisplay) {
                $selectedDisplay = $displays | Sort-Object { $_.Width * $_.Height } | Select-Object -First 1
                if ($selectedDisplay) {
                    Write-Verbose "Selected smallest display as internal fallback: $($selectedDisplay.Name)"
                }
            }

            # Method 5: Final fallback
            if (-not $selectedDisplay) {
                $selectedDisplay = $displays[0]
                Write-Verbose "Using first display as final fallback: $($selectedDisplay.Name)"
            }

            Write-Success "Selected internal display: $($selectedDisplay.Name) ($($selectedDisplay.Width)x$($selectedDisplay.Height))"
            return @{
                Width     = $selectedDisplay.Width
                Height    = $selectedDisplay.Height
                Source    = 'Internal Display'
                Display   = $selectedDisplay
                MonitorId = $selectedDisplay.MonitorId
            }
        }

        if ($ExternalDisplay) {
            # For external display, use multiple detection methods with priority order
            Write-Verbose 'Available displays for external selection:'
            foreach ($disp in $displays) {
                Write-Verbose "  - $($disp.Name): $($disp.Width)x$($disp.Height) (Primary: $($disp.Primary)) - MonitorId: $($disp.MonitorId)"
            }

            $selectedDisplay = $null

            # Method 1: Look for non-internal manufacturer codes (exclude common internal display manufacturers)
            $internalManufacturers = @('TMX', 'LGD', 'AUO', 'BOE', 'CMN', 'CSO', 'INL', 'SDC', 'SHP')
            $selectedDisplay = $displays | Where-Object {
                $display = $_
                -not ($internalManufacturers | Where-Object { $display.MonitorId -like "*$_*" })
            } | Select-Object -First 1

            if ($selectedDisplay) {
                Write-Verbose "Found external display by excluding internal manufacturers: $($selectedDisplay.Name)"
            }

            # Method 2: Look for larger display (external monitors are typically larger)
            if (-not $selectedDisplay) {
                $selectedDisplay = $displays | Sort-Object { $_.Width * $_.Height } -Descending | Select-Object -First 1
                if ($selectedDisplay) {
                    Write-Verbose "Selected largest display as external: $($selectedDisplay.Name)"
                }
            }

            # Method 3: Use non-primary display
            if (-not $selectedDisplay) {
                $selectedDisplay = $displays | Where-Object { -not $_.Primary } | Select-Object -First 1
                if ($selectedDisplay) {
                    Write-Verbose "Selected non-primary display as external: $($selectedDisplay.Name)"
                }
            }

            # Method 4: Final fallback - use second display
            if (-not $selectedDisplay -and $displays.Count -gt 1) {
                $selectedDisplay = $displays[1]
                Write-Verbose "Using second display as external fallback: $($selectedDisplay.Name)"
            }

            # Method 5: Ultimate fallback - use first display
            if (-not $selectedDisplay) {
                $selectedDisplay = $displays[0]
                Write-Verbose "Using first display as ultimate external fallback: $($selectedDisplay.Name)"
            }

            Write-Success "Selected external display: $($selectedDisplay.Name) ($($selectedDisplay.Width)x$($selectedDisplay.Height))"
            return @{
                Width     = $selectedDisplay.Width
                Height    = $selectedDisplay.Height
                Source    = 'External Display'
                Display   = $selectedDisplay
                MonitorId = $selectedDisplay.MonitorId
            }
        }
    }

    # Interactive display selection if no parameters provided
    if (-not ($PrimaryDisplay -or $InternalDisplay -or $ExternalDisplay -or $CustomDisplay)) {
        # If only one display, use it automatically
        if ($displays.Count -eq 1) {
            $selectedDisplay = $displays[0]
            $displayName = if ($selectedDisplay.Name) { $selectedDisplay.Name } else { 'Primary Display' }
            $manufacturerText = if ($selectedDisplay.Manufacturer -and $selectedDisplay.Manufacturer -ne 'Unknown') {
                " - $($selectedDisplay.Manufacturer)"
            } else {
                ''
            }
            Write-Success "Single display detected: $displayName ($($selectedDisplay.Width)x$($selectedDisplay.Height))$manufacturerText"
            return @{
                Width     = $selectedDisplay.Width
                Height    = $selectedDisplay.Height
                Source    = "Single Display - $displayName"
                Display   = $selectedDisplay
                MonitorId = $selectedDisplay.MonitorId
            }
        }

        # If in CheckOnly mode, auto-select primary display without prompting
        if ($CheckOnly) {
            $primaryDisplay = $displays | Where-Object { $_.Primary } | Select-Object -First 1
            if (-not $primaryDisplay) { $primaryDisplay = $displays[0] }

            $displayName = if ($primaryDisplay.Name) { $primaryDisplay.Name } else { 'Primary Display' }
            Write-Success "CheckOnly mode: Auto-selected primary display - $displayName ($($primaryDisplay.Width)x$($primaryDisplay.Height))"
            return @{
                Width     = $primaryDisplay.Width
                Height    = $primaryDisplay.Height
                Source    = 'CheckOnly - Primary Display'
                Display   = $primaryDisplay
                MonitorId = $primaryDisplay.MonitorId
            }
        }

        # Multiple displays - check for same resolution
        $uniqueResolutions = $displays | Group-Object { "$($_.Width)x$($_.Height)" }
        if ($uniqueResolutions.Count -eq 1) {
            # All displays have same resolution - need user selection
            Write-Host ''
            Write-Host '=== Display Selection ===' -ForegroundColor Yellow
            Write-Host "Detected $($displays.Count) displays with same resolution:" -ForegroundColor Cyan
            Write-Host ''
        } else {
            # Different resolutions - show selection
            Write-Host ''
            Write-Host '=== Display Selection ===' -ForegroundColor Yellow
            Write-Host "Detected $($displays.Count) display(s):" -ForegroundColor Cyan
            Write-Host ''
        }

        foreach ($displayItem in $displays) {
            $primaryText = if ($displayItem.Primary) { ' (Primary)' } else { '' }
            $positionText = "Position: ($($displayItem.X), $($displayItem.Y))"
            $sizeText = if ($displayItem.PhysicalSize) { ", Size: $($displayItem.PhysicalSize)" } else { '' }

            Write-Host "$($displayItem.Index). $($displayItem.Name)$primaryText" -ForegroundColor Green
            Write-Host "   Resolution: $($displayItem.Width)x$($displayItem.Height)" -ForegroundColor White
            Write-Host "   $positionText$sizeText" -ForegroundColor Gray
            Write-Host "   Manufacturer: $($displayItem.Manufacturer) ($($displayItem.ManufacturerCode))" -ForegroundColor Gray
            Write-Host "   Serial: $($displayItem.SerialNumber), Device: $($displayItem.DeviceName)" -ForegroundColor Gray
            Write-Host ''
        }

        # Interactive selection with 10-second timeout (skip in CheckOnly mode)
        if ($CheckOnly) {
            Write-Host 'CheckOnly mode: Auto-selecting primary display...' -ForegroundColor Yellow
            $selection = $null  # Will auto-select primary display below
        } else {
            Write-Host 'Auto-selecting primary display in 10 seconds if no selection made...' -ForegroundColor Yellow

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
        }

        if (-not $selection) {
            # Timeout - auto-select primary display
            Write-Host ''
            $primaryDisplay = $displays | Where-Object { $_.Primary } | Select-Object -First 1
            if (-not $primaryDisplay) { $primaryDisplay = $displays[0] }

            $displayName = if ($primaryDisplay.Name) { $primaryDisplay.Name } else { 'Primary Display' }
            Write-Success "Timeout - Auto-selected primary display: $displayName ($($primaryDisplay.Width)x$($primaryDisplay.Height))"
            return @{
                Width     = $primaryDisplay.Width
                Height    = $primaryDisplay.Height
                Source    = 'Timeout - Primary Display'
                Display   = $primaryDisplay
                MonitorId = $primaryDisplay.MonitorId
            }
        }

        # Process user selection
        $selectedIndex = $null
        if ([int]::TryParse($selection, [ref]$selectedIndex) -and $selectedIndex -ge 1 -and $selectedIndex -le $displays.Count) {
            $selectedDisplay = $displays[$selectedIndex - 1]
            Write-Success "Selected: $($selectedDisplay.Name) ($($selectedDisplay.Width)x$($selectedDisplay.Height))"
            return @{
                Width     = $selectedDisplay.Width
                Height    = $selectedDisplay.Height
                Source    = "Interactive Selection - $($selectedDisplay.Name)"
                Display   = $selectedDisplay
                MonitorId = $selectedDisplay.MonitorId
            }
        } else {
            Write-Warning 'Invalid selection. Auto-selecting primary display.'
            $primaryDisplay = $displays | Where-Object { $_.Primary } | Select-Object -First 1
            if (-not $primaryDisplay) { $primaryDisplay = $displays[0] }

            return @{
                Width     = $primaryDisplay.Width
                Height    = $primaryDisplay.Height
                Source    = 'Fallback - Primary Display'
                Display   = $primaryDisplay
                MonitorId = $primaryDisplay.MonitorId
            }
        }
    }

    # Fallback to primary display
    $primaryDisplay = $displays | Where-Object { $_.Primary } | Select-Object -First 1
    return @{
        Width     = $primaryDisplay.Width
        Height    = $primaryDisplay.Height
        Source    = 'Primary Display (Default)'
        Display   = $primaryDisplay
        MonitorId = $primaryDisplay.MonitorId
    }
}

function Get-DynamicBitrate {
    param(
        [int]$Width,
        [int]$Height,
        [int]$PerformanceMode,
        [string]$EncoderType = 'H.264'
    )

    # Calculate total pixels in the recording resolution
    $totalPixels = $Width * $Height

    # Reference standards from YouTube/Teams/Streaming platforms for H.264
    # Based on YouTube recommendations: https://support.google.com/youtube/answer/2853702
    # Optimized for cloud storage (OneDrive/SharePoint/MS Stream)
    $referenceStandards = @{
        # Resolution -> Pixels -> Recommended Bitrate (kbps) for cloud storage
        '240p'  = @{ Pixels = 320 * 240; Bitrate = 400 }    # 76,800 pixels
        '360p'  = @{ Pixels = 640 * 360; Bitrate = 800 }    # 230,400 pixels
        '480p'  = @{ Pixels = 854 * 480; Bitrate = 1200 }   # 409,920 pixels
        '720p'  = @{ Pixels = 1280 * 720; Bitrate = 2500 }   # 921,600 pixels
        '1080p' = @{ Pixels = 1920 * 1080; Bitrate = 5000 }   # 2,073,600 pixels
        '1440p' = @{ Pixels = 2560 * 1440; Bitrate = 10000 }  # 3,686,400 pixels
        '2160p' = @{ Pixels = 3840 * 2160; Bitrate = 20000 }  # 8,294,400 pixels
    }

    # Calculate pixels-per-bit ratio from 1080p standard (optimal for cloud storage)
    $reference1080p = $referenceStandards['1080p']
    $pixelsPerBit = $reference1080p.Pixels / $reference1080p.Bitrate

    # Calculate base bitrate for current resolution
    $baseBitrate = [math]::Round($totalPixels / $pixelsPerBit)

    # Apply PerformanceMode scaling factor for encoder efficiency
    # Lower PerformanceMode = more aggressive compression needed
    $performanceScaling = switch ($PerformanceMode) {
        '33' { 0.6 }   # Extreme performance - aggressive compression
        '50' { 0.75 }  # Ultra-lightweight - reduced bitrate
        '60' { 0.85 }  # Lightweight - slight reduction
        '75' { 0.95 }  # Optimized - minimal reduction
        '90' { 1.0 }   # Standard - full quality
        default { 0.85 }
    }

    # Apply performance scaling
    $scaledBitrate = [math]::Round($baseBitrate * $performanceScaling)

    # Add 15% safety margin for cloud storage and network fluctuations
    $finalBitrate = [math]::Round($scaledBitrate * 1.15)

    # Enforce minimum and maximum limits for stability
    $minBitrate = 500   # Minimum for any usable quality
    $maxBitrate = 25000 # Maximum for cloud storage efficiency

    $finalBitrate = [math]::Max($minBitrate, [math]::Min($maxBitrate, $finalBitrate))

    Write-Verbose 'Dynamic Bitrate Calculation:'
    Write-Verbose "  Resolution: ${Width}x${Height} (${totalPixels} pixels)"
    Write-Verbose "  Base Bitrate: ${baseBitrate} kbps"
    Write-Verbose "  Performance Scaling (${PerformanceMode}%): ${performanceScaling}"
    Write-Verbose "  Scaled Bitrate: ${scaledBitrate} kbps"
    Write-Verbose "  Final Bitrate (with 15% safety): ${finalBitrate} kbps"

    return $finalBitrate
}

function Get-SystemConfiguration {
    param(
        [switch]$InternalDisplay,
        [switch]$ExternalDisplay,
        [string]$CustomDisplay
    )

    Write-Info '=== System Configuration Analysis ==='

    $config = @{
        Hardware = @{
            IsLaptop = $null -ne (Get-CimInstance -ClassName Win32_Battery)
            CPU      = (Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1).Name
            Memory   = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
        }
        Display  = @{
            ActualResolution    = @{ Width = 1920; Height = 1200 }
            RecordingResolution = @{ Width = 1728; Height = 1080 }
            MonitorIndex        = 0
            Count               = 1
        }
        GPU      = @{
            Type             = 'Intel'
            Encoder          = 'obs_qsv11'
            SimpleEncoder    = 'obs_qsv11'  # Simple Output mode encoder identifier
            Name             = 'Intel QuickSync H.264'
            Bitrate          = $dynamicBitrate  # Will be calculated dynamically based on resolution
            AudioBitrate     = switch ($PerformanceMode) { '33' { 64 } '50' { 96 } '60' { 96 } '75' { 128 } '90' { 160 } default { 96 } }
            Preset           = if ([int]$PerformanceMode -le 75) { 'speed' } else { 'balanced' }
            SupportsHardware = $true
            PerformanceMode  = $PerformanceMode
            AMFPreAnalysis   = $false
            AMFBFrames       = 0
        }
        OneDrive = @{
            Available = $false
            Path      = "${env:USERPROFILE}\Videos\OBS-Recordings"
            Type      = 'Local'
        }
    }

    try {
        # Detect system
        Write-Info "System: $(if($config.Hardware.IsLaptop){'Laptop'}else{'Desktop'}) - $($config.Hardware.CPU)"
        Write-Info "Memory: $($config.Hardware.Memory)GB"

        # Get display configuration (interactive or parameter-based)
        $displayConfig = Get-DisplayConfiguration -PrimaryDisplay:$PrimaryDisplay -InternalDisplay:$InternalDisplay -ExternalDisplay:$ExternalDisplay -CustomDisplay:$CustomDisplay -CheckOnly:$CheckOnly

        $config.Display.ActualResolution = @{
            Width  = $displayConfig.Width
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
            Width  = [math]::Round($config.Display.ActualResolution.Width * $scalingFactor)
            Height = [math]::Round($config.Display.ActualResolution.Height * $scalingFactor)
        }

        # Add FPS and MonitorId for silent deployment
        $config.Display.FPS = if ($PerformanceMode -eq '33') { 24 } else { 30 }
        $config.Display.MonitorId = $displayConfig.MonitorId
        Write-Verbose "System MonitorId: $($config.Display.MonitorId)"

        # Calculate dynamic bitrate based on actual recording resolution
        $dynamicBitrate = Get-DynamicBitrate -Width $config.Display.RecordingResolution.Width -Height $config.Display.RecordingResolution.Height -PerformanceMode $PerformanceMode

        Write-Info "Dynamic Bitrate: $dynamicBitrate kbps (calculated for $($config.Display.RecordingResolution.Width)x$($config.Display.RecordingResolution.Height) at ${PerformanceMode}% performance)"

        $performanceDescription = switch ($PerformanceMode) {
            '33' { 'Extreme performance: 33% scaling for severe encoder overload' }
            '50' { 'Ultra-lightweight: 50% scaling for maximum performance' }
            '60' { 'Lightweight: 60% scaling (default ultra performance)' }
            '75' { 'Optimized: 75% scaling to reduce encoder load' }
            '90' { 'Standard: 90% scaling (balanced quality/performance)' }
        }

        $exampleRes = "$([math]::Round(1920 * $scalingFactor))x$([math]::Round(1200 * $scalingFactor))"
        Write-Info "$performanceDescription (${exampleRes} from 1920x1200)"

        # Detect GPU
        $gpus = Get-CimInstance -ClassName Win32_VideoController | Where-Object {
            $_.Status -eq 'OK' -and $_.Name -notmatch 'Microsoft Basic|Remote Desktop'
        }

        foreach ($gpu in $gpus) {
            # Filter out DisplayLink USB devices (docking stations/adapters, not actual GPUs)
            if ($gpu.Name -match 'DisplayLink') {
                Write-Info "USB Display Adapter: $($gpu.Name) (docking station/USB-C hub)"
                continue
            }

            Write-Info "GPU: $($gpu.Name)"

            if ($gpu.Name -match 'NVIDIA|GeForce|Quadro|RTX|GTX') {
                # Configure preset based on performance mode
                switch ($PerformanceMode) {
                    '33' {
                        $preset = 'p1'
                        $mode = ' (extreme performance - 33%)'
                    }
                    '50' {
                        $preset = 'p1'
                        $mode = ' (ultra-lightweight - 50%)'
                    }
                    '60' {
                        $preset = 'p1'
                        $mode = ' (lightweight - 60%)'
                    }
                    '75' {
                        $preset = 'p3'
                        $mode = ' (optimized - 75%)'
                    }
                    '90' {
                        $preset = 'p4'
                        $mode = ' (standard - 90%)'
                    }
                }

                $config.GPU = @{
                    Type             = 'NVIDIA'
                    Encoder          = 'ffmpeg_nvenc'
                    SimpleEncoder    = 'nvenc_h264'  # Simple Output mode encoder identifier
                    Name             = 'NVIDIA NVENC H.264'
                    Bitrate          = $dynamicBitrate  # Use dynamic calculation
                    AudioBitrate     = switch ($PerformanceMode) { '33' { 64 } '50' { 96 } '60' { 96 } '75' { 128 } '90' { 160 } default { 96 } }
                    Preset           = $preset
                    SupportsHardware = $true
                    PerformanceMode  = $PerformanceMode
                    AMFPreAnalysis   = $false
                    AMFBFrames       = 0
                }
                Write-Success "NVIDIA GPU: Using NVENC encoding$mode"
                break
            } elseif ($gpu.Name -match 'Intel.*Graphics|Intel.*Iris|Intel.*UHD|Intel.*HD') {
                # Configure preset based on performance mode, use dynamic bitrate
                switch ($PerformanceMode) {
                    '33' {
                        $config.GPU.Bitrate = $dynamicBitrate
                        $config.GPU.Preset = 'speed'
                        $mode = ' (extreme performance - 33%)'
                    }
                    '50' {
                        $config.GPU.Bitrate = $dynamicBitrate
                        $config.GPU.Preset = 'speed'
                        $mode = ' (ultra-lightweight - 50%)'
                    }
                    '60' {
                        $config.GPU.Bitrate = $dynamicBitrate
                        $config.GPU.Preset = 'speed'
                        $mode = ' (lightweight - 60%)'
                    }
                    '75' {
                        $config.GPU.Bitrate = $dynamicBitrate
                        $config.GPU.Preset = 'speed'
                        $mode = ' (optimized - 75%)'
                    }
                    '90' {
                        $config.GPU.Bitrate = $dynamicBitrate
                        $config.GPU.Preset = 'balanced'
                        $mode = ' (standard - 90%)'
                    }
                }

                $config.GPU.PerformanceMode = $PerformanceMode
                Write-Success "Intel GPU: Using QuickSync encoding$mode"
            } elseif ($gpu.Name -match 'AMD|Radeon|RX') {
                if (-not $config.GPU.Type -or $config.GPU.Type -eq 'Intel') {
                    # Configure based on performance mode
                    switch ($PerformanceMode) {
                        '33' {
                            $preset = 'speed'
                            $mode = ' (extreme performance - 33% with AMF)'
                            $bframes = 0
                        }
                        '50' {
                            $preset = 'speed'
                            $mode = ' (ultra-lightweight - 50% with AMF)'
                            $bframes = 0
                        }
                        '60' {
                            $preset = 'speed'
                            $mode = ' (lightweight - 60% with AMF)'
                            $bframes = 0
                        }
                        '75' {
                            $preset = 'speed'
                            $mode = ' (optimized - 75%)'
                            $bframes = 2
                        }
                        '90' {
                            $preset = 'balanced'
                            $mode = ' (standard - 90%)'
                            $bframes = 2
                        }
                    }

                    $config.GPU = @{
                        Type             = 'AMD'
                        Encoder          = 'amd_amf_h264'
                        SimpleEncoder    = 'amd'  # Simple Output mode encoder identifier
                        Name             = 'AMD AMF H.264'
                        Bitrate          = $dynamicBitrate  # Use dynamic calculation
                        AudioBitrate     = switch ($PerformanceMode) { '33' { 64 } '50' { 96 } '60' { 96 } '75' { 128 } '90' { 160 } default { 96 } }
                        Preset           = $preset
                        SupportsHardware = $true
                        PerformanceMode  = $PerformanceMode
                        AMFPreAnalysis   = ([int]$PerformanceMode -le 60)  # Enable for performance modes
                        AMFBFrames       = $bframes
                    }
                    Write-Success "AMD GPU: Using AMF encoding$mode"
                }
            }
        }

        # Detect OneDrive
        $oneDriveVars = @('OneDrive', 'OneDriveCommercial', 'OneDriveConsumer')
        foreach ($var in $oneDriveVars) {
            $path = [Environment]::GetEnvironmentVariable($var)
            if ($path -and (Test-Path $path)) {
                $config.OneDrive = @{
                    Available = $true
                    Path      = Join-Path $path 'Recordings'
                    Type      = $var
                    BasePath  = $path
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

    Write-Info '=== Installing OBS Studio Portable ==='

    if ($WhatIfPreference) {
        Write-Info '[WHATIF] Would install OBS Studio portable'
        return $true
    }

    try {
        # Get latest version
        $apiUrl = 'https://api.github.com/repos/obsproject/obs-studio/releases/latest'
        $headers = @{ 'User-Agent' = 'OBS-Deploy-Script/1.1'; 'Accept' = 'application/vnd.github.v3+json' }
        $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 30

        $latestVersion = $response.tag_name
        $windowsAsset = $response.assets | Where-Object { $_.name -like '*Windows-x64.zip' } | Select-Object -First 1

        Write-Success "Installing OBS Studio $latestVersion"

        # Download and install
        $tempZip = Join-Path ${env:TEMP} "OBS-Studio-${latestVersion}.zip"
        Invoke-RobustDownload -Uri $windowsAsset.browser_download_url -OutFile $tempZip -Description "OBS Studio $latestVersion" -ShowProgress $true

        $tempExtract = Join-Path ${env:TEMP} "OBS-Extract-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $tempExtract)

        $extractedFolders = Get-ChildItem -Path $tempExtract -Directory
        $obsSourceFolder = $extractedFolders | Where-Object { Test-Path (Join-Path $_.FullName 'bin\64bit\obs64.exe') }

        if ($obsSourceFolder) {
            $obsSource = $obsSourceFolder[0].FullName
        } else {
            # Check if files are directly in extract path
            if (Test-Path (Join-Path $tempExtract 'bin\64bit\obs64.exe')) {
                $obsSource = $tempExtract
            } else {
                throw 'Could not find OBS executable in extracted files'
            }
        }

        if (Test-Path $InstallPath) {
            Remove-Item $InstallPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null

        Copy-Item -Path "${obsSource}\*" -Destination $InstallPath -Recurse -Force
        New-Item -ItemType File -Path (Join-Path $InstallPath 'portable_mode.txt') -Force | Out-Null

        # Cleanup
        Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

        Write-Success 'OBS Studio installed successfully'
        Write-Info "Installation Path: $InstallPath"
        Write-Info "Executable: $InstallPath\bin\64bit\obs64.exe"
        return $true

    } catch {
        Write-Error "Installation failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-VCRedistInstalled {
    <#
    .SYNOPSIS
    Tests if Visual C++ Redistributables are installed

    .DESCRIPTION
    Checks for installed Visual C++ Redistributables (2015-2022) that are required for OBS plugins
    #>

    try {
        # Check for VC++ 2015-2022 Redistributable (x64) - covers most modern requirements
        $vcRedistKeys = @(
            'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',  # 2015-2022
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
            'HKLM:\SOFTWARE\Classes\Installer\Dependencies\Microsoft.VS.VC_RuntimeMinimumVSU_amd64,v14',
            'HKLM:\SOFTWARE\Classes\Installer\Dependencies\{36F68A90-239C-34DF-B58C-64B30153CE35}' # 2015-2022 x64
        )

        foreach ($key in $vcRedistKeys) {
            if (Test-Path $key) {
                $version = Get-ItemProperty -Path $key -Name 'Version' -ErrorAction SilentlyContinue
                if ($version -and $version.Version) {
                    Write-Verbose "Found VC++ Redistributable: $($version.Version)"
                    return $true
                }
            }
        }

        # Alternative check using Get-WmiObject for installed programs
        $vcRedist = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like '*Visual C++*Redistributable*' -and $_.Name -like '*x64*' }

        if ($vcRedist) {
            Write-Verbose "Found VC++ Redistributable via WMI: $($vcRedist.Name)"
            return $true
        }

        # Check using registry uninstall keys (faster method)
        $uninstallKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )

        foreach ($keyPath in $uninstallKeys) {
            $programs = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like '*Visual C++*Redistributable*x64*' -or
                    $_.DisplayName -like '*Microsoft Visual C++*Runtime*' }
            if ($programs) {
                Write-Verbose 'Found VC++ Redistributable in uninstall registry'
                return $true
            }
        }

        return $false

    } catch {
        Write-Verbose "Error checking VC++ Redistributable: $($_.Exception.Message)"
        return $false  # Assume not installed if we can't check
    }
}

function Test-IntelCPUCompatibility {
    <#
    .SYNOPSIS
    Tests if the Intel CPU is compatible with OpenVINO

    .DESCRIPTION
    Checks if the Intel CPU generation is supported by OpenVINO plugins
    Supported: Intel Core 6th-14th generation, Xeon 1st-5th gen Scalable, Atom with SSE4.2
    #>

    try {
        $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
        $cpuName = $cpu.Name

        # Intel Core Ultra series (14th gen)
        if ($cpuName -match 'Intel.*Core.*Ultra') {
            return $true
        }

        # Intel Core i-series (check generation)
        if ($cpuName -match 'Intel.*Core.*i[3579]-(\d+)') {
            $generation = [int]($matches[1] -replace '\D.*$')
            if ($generation -ge 6000) {
                # 6th gen and newer
                return $true
            }
        }

        # Intel Xeon processors
        if ($cpuName -match 'Intel.*Xeon') {
            return $true  # Most Xeon processors support OpenVINO
        }

        # Intel Atom with SSE4.2 (assume modern Atom processors have it)
        if ($cpuName -match 'Intel.*Atom') {
            return $true
        }

        return $false

    } catch {
        Write-Warning "Could not determine CPU compatibility: $($_.Exception.Message)"
        return $false
    }
}

function Test-OBSTemplates {
    param(
        [string]$TemplatePath
    )

    <#
    .SYNOPSIS
    Validates OBS configuration templates for completeness and syntax

    .DESCRIPTION
    Checks that all required template files exist and contain valid syntax.
    Useful for verifying template integrity before deployment.
    #>

    Write-Info '=== Validating OBS Configuration Templates ==='

    $requiredTemplates = @(
        'basic.ini.template',
        'user.ini.template',
        'global.ini.template',
        'scene.json.template'
    )

    $validationResults = @()

    foreach ($template in $requiredTemplates) {
        $templateFile = Join-Path $TemplatePath $template
        $result = @{
            Template = $template
            Exists   = Test-Path $templateFile
            Valid    = $false
            Issues   = @()
        }

        if ($result.Exists) {
            try {
                $content = Get-Content -Path $templateFile -Raw

                # Basic validation checks
                if ($template -eq 'scene.json.template') {
                    # For JSON templates with parameters, skip JSON validation
                    # (will be valid after parameter replacement)
                    if ($content -match '\{\{[^}]+\}\}') {
                        $result.Valid = $true
                        $result.Issues += 'Contains parameters - JSON validation skipped'
                    } else {
                        # Validate JSON syntax if no parameters
                        try {
                            $null = $content | ConvertFrom-Json
                            $result.Valid = $true
                        } catch {
                            $result.Issues += "JSON syntax error: $($_.Exception.Message)"
                        }
                    }
                } else {
                    # Validate INI syntax (basic check for section headers)
                    if ($content -match '\[.+\]') {
                        $result.Valid = $true
                    } else {
                        $result.Issues += 'No INI section headers found'
                    }
                }

                # Check for unmatched parameters (should all be {{PARAM}} format)
                $unmatchedParams = [regex]::Matches($content, '\{\{[^}]+\}\}') | ForEach-Object { $_.Value } | Sort-Object -Unique
                if ($unmatchedParams.Count -gt 0) {
                    Write-Verbose "Template $template contains parameters: $($unmatchedParams -join ', ')"
                }

            } catch {
                $result.Valid = $false
                $result.Issues += "Syntax error: $($_.Exception.Message)"
            }
        } else {
            $result.Issues += 'Template file not found'
        }

        $validationResults += $result
    }

    # Report results
    $allValid = $true
    foreach ($result in $validationResults) {
        if ($result.Exists -and $result.Valid) {
            Write-Success "[OK] $($result.Template) - Valid"
        } else {
            Write-Warning "[FAIL] $($result.Template) - Issues: $($result.Issues -join ', ')"
            $allValid = $false
        }
    }

    if ($allValid) {
        Write-Success 'All OBS configuration templates are valid and ready for use'
    } else {
        Write-Warning 'Some templates have issues - silent deployment may fail'
    }

    return $allValid
}

function New-OBSConfigurationTemplate {
    param(
        [hashtable]$SystemConfig,
        [string]$InstallPath
    )

    <#
    .SYNOPSIS
    Creates complete OBS configuration from external templates for silent deployment

    .DESCRIPTION
    Uses external template files with parameter replacement to generate OBS configuration
    files (basic.ini, scenes, user.ini, global.ini) based on detected hardware and
    system configuration, eliminating the need for Auto-Configuration Wizard.
    #>

    Write-Info '=== Creating OBS Configuration from Templates ==='

    try {
        # Get script directory for template path
        $scriptPath = if ($MyInvocation.ScriptName) {
            Split-Path -Parent $MyInvocation.ScriptName
        } else {
            $PWD.Path
        }
        $templatePath = Join-Path $scriptPath 'templates\obs-config'

        # Verify and validate templates
        if (-not (Test-Path $templatePath)) {
            throw "Template directory not found: $templatePath"
        }

        # Validate template integrity
        $templatesValid = Test-OBSTemplates -TemplatePath $templatePath
        if (-not $templatesValid) {
            throw 'Template validation failed - cannot proceed with silent deployment'
        }

        # Create configuration directories
        $configPath = Join-Path $InstallPath 'config\obs-studio'
        $profilePath = Join-Path $configPath 'basic\profiles\Untitled'
        $scenePath = Join-Path $configPath 'basic\scenes'

        New-Item -Path $profilePath -ItemType Directory -Force | Out-Null
        New-Item -Path $scenePath -ItemType Directory -Force | Out-Null

        # Define parameter replacement values
        $parameters = @{
            'ONEDRIVE_PATH'       = $SystemConfig.OneDrive.Path -replace '\\', '\\\\'
            'VIDEO_BITRATE'       = $SystemConfig.GPU.Bitrate
            'AUDIO_BITRATE'       = $SystemConfig.GPU.AudioBitrate
            'GPU_PRESET'          = $SystemConfig.GPU.Preset
            'STREAM_ENCODER'      = $SystemConfig.GPU.SimpleEncoder
            'REC_ENCODER'         = $SystemConfig.GPU.SimpleEncoder
            'GPU_ENCODER'         = $SystemConfig.GPU.Encoder
            'BASE_WIDTH'          = $SystemConfig.Display.ActualResolution.Width
            'BASE_HEIGHT'         = $SystemConfig.Display.ActualResolution.Height
            'OUTPUT_WIDTH'        = $SystemConfig.Display.RecordingResolution.Width
            'OUTPUT_HEIGHT'       = $SystemConfig.Display.RecordingResolution.Height
            'FPS'                 = $SystemConfig.Display.FPS
            'COOKIE_ID'           = [System.Guid]::NewGuid().ToString('N').Substring(0, 16).ToUpper()
            'AMF_PREANALYSIS'     = $SystemConfig.GPU.AMFPreAnalysis
            'AMF_BFRAMES'         = $SystemConfig.GPU.AMFBFrames
            'INSTALL_GUID'        = [System.Guid]::NewGuid().ToString('N')
            'MONITOR_ID'          = $SystemConfig.Display.MonitorId -replace '\\', '\\\\'
            'DESKTOP_AUDIO_UUID'  = [System.Guid]::NewGuid()
            'MIC_AUDIO_UUID'      = [System.Guid]::NewGuid()
            'SCENE_UUID'          = [System.Guid]::NewGuid()
            'DISPLAY_SOURCE_UUID' = [System.Guid]::NewGuid()
        }

        # Process basic.ini template
        $basicTemplate = Join-Path $templatePath 'basic.ini.template'
        if (Test-Path $basicTemplate) {
            $basicContent = Get-Content -Path $basicTemplate -Raw
            foreach ($param in $parameters.GetEnumerator()) {
                $basicContent = $basicContent -replace "\{\{$($param.Key)\}\}", $param.Value
            }
            Set-Content -Path (Join-Path $profilePath 'basic.ini') -Value $basicContent -Encoding UTF8
            Write-Info '  - Created: basic.ini from template'
        } else {
            throw "Template not found: $basicTemplate"
        }

        # Process user.ini template (no parameters needed, but consistent approach)
        $userTemplate = Join-Path $templatePath 'user.ini.template'
        if (Test-Path $userTemplate) {
            $userContent = Get-Content -Path $userTemplate -Raw
            Set-Content -Path (Join-Path $configPath 'user.ini') -Value $userContent -Encoding UTF8
            Write-Info '  - Created: user.ini from template (FirstRun=false)'
        } else {
            throw "Template not found: $userTemplate"
        }

        # Process global.ini template
        $globalTemplate = Join-Path $templatePath 'global.ini.template'
        if (Test-Path $globalTemplate) {
            $globalContent = Get-Content -Path $globalTemplate -Raw
            foreach ($param in $parameters.GetEnumerator()) {
                $globalContent = $globalContent -replace "\{\{$($param.Key)\}\}", $param.Value
            }
            Set-Content -Path (Join-Path $configPath 'global.ini') -Value $globalContent -Encoding UTF8
            Write-Info '  - Created: global.ini from template'
        } else {
            throw "Template not found: $globalTemplate"
        }

        # Process scene.json template
        $sceneTemplate = Join-Path $templatePath 'scene.json.template'
        if (Test-Path $sceneTemplate) {
            $sceneContent = Get-Content -Path $sceneTemplate -Raw
            foreach ($param in $parameters.GetEnumerator()) {
                $sceneContent = $sceneContent -replace "\{\{$($param.Key)\}\}", $param.Value
            }
            Set-Content -Path (Join-Path $scenePath 'Untitled.json') -Value $sceneContent -Encoding UTF8
            Write-Info '  - Created: Untitled.json from template (Display Capture auto-configured)'
        } else {
            throw "Template not found: $sceneTemplate"
        }

        Write-Success 'OBS configuration created successfully from external templates'
        Write-Info "  - Templates used from: $templatePath"
        Write-Info "  - Configuration created in: $configPath"
        Write-Info "  - Hardware-specific parameters applied: $($parameters.Count) replacements"

        return $true

    } catch {
        Write-Error "Failed to create OBS configuration from templates: $($_.Exception.Message)"
        return $false
    }
}

function Test-OBSConfiguration {
    param(
        [string]$InstallPath = "${env:USERPROFILE}\OBS-Studio-Portable",
        [hashtable]$ExpectedConfig
    )

    <#
    .SYNOPSIS
    Validates actual OBS configuration against expected settings

    .DESCRIPTION
    Reads OBS configuration files and compares with expected values
    Reports discrepancies between script configuration and actual OBS settings
    #>

    Write-Info '=== Validating OBS Configuration ==='

    $profilePath = Join-Path $InstallPath 'config\obs-studio\basic\profiles\Untitled\basic.ini'

    if (-not (Test-Path $profilePath)) {
        Write-Warning "OBS configuration file not found: $profilePath"
        return $false
    }

    try {
        $config = Get-Content -Path $profilePath -Raw
        $validationResults = @{
            Success        = $true
            Issues         = @()
            ActualValues   = @{}
            ExpectedValues = @{}
        }

        # Extract actual values from OBS config
        # Use more specific regex patterns to extract from correct sections
        $actualValues = @{
            BaseCX             = if ($config -match 'BaseCX=(\d+)') { [int]$matches[1] } else { $null }
            BaseCY             = if ($config -match 'BaseCY=(\d+)') { [int]$matches[1] } else { $null }
            OutputCX           = if ($config -match 'OutputCX=(\d+)') { [int]$matches[1] } else { $null }
            OutputCY           = if ($config -match 'OutputCY=(\d+)') { [int]$matches[1] } else { $null }
            VBitrate           = if ($config -match '(?m)^VBitrate=(\d+)') { [int]$matches[1] } else { $null }
            ABitrate           = if ($config -match '(?mi)^A[Bb]itrate=(\d+)') { [int]$matches[1] } else { $null }
            # Extract Simple Output encoders (these should match our expected values)
            RecEncoder         = if ($config -match '\[SimpleOutput\][\s\S]*?RecEncoder=([^\r\n]+)') { $matches[1].Trim() } else { $null }
            StreamEncoder      = if ($config -match '\[SimpleOutput\][\s\S]*?StreamEncoder=([^\r\n]+)') { $matches[1].Trim() } else { $null }
            # Extract Advanced Output encoder (for informational purposes)
            AdvancedEncoder    = if ($config -match '\[AdvOutput\][\s\S]*?Encoder=([^\r\n]+)') { $matches[1].Trim() } else { $null }
            RecAudioEncoder    = if ($config -match 'RecAudioEncoder=([^\r\n]+)') { $matches[1].Trim() } else { $null }
            StreamAudioEncoder = if ($config -match 'StreamAudioEncoder=([^\r\n]+)') { $matches[1].Trim() } else { $null }
            FPSCommon          = if ($config -match 'FPSCommon=(\d+)') { [int]$matches[1] } else { $null }
            RecFormat2         = if ($config -match 'RecFormat2=([^\r\n]+)') { $matches[1].Trim() } else { $null }
        }

        $validationResults.ActualValues = $actualValues
        $validationResults.ExpectedValues = $ExpectedConfig

        # Debug: Show what was extracted for encoder validation
        Write-Verbose 'Encoder Extraction Debug:'
        Write-Verbose "  - Simple RecEncoder: '$($actualValues.RecEncoder)'"
        Write-Verbose "  - Simple StreamEncoder: '$($actualValues.StreamEncoder)'"
        Write-Verbose "  - Advanced Encoder: '$($actualValues.AdvancedEncoder)'"
        Write-Verbose "  - Expected Encoder: '$($ExpectedConfig.Encoder)'"

        # Validate each setting
        if ($ExpectedConfig.BaseCX -and $actualValues.BaseCX -ne $ExpectedConfig.BaseCX) {
            $validationResults.Issues += "Base Width: Expected $($ExpectedConfig.BaseCX), Actual $($actualValues.BaseCX)"
            $validationResults.Success = $false
        }

        if ($ExpectedConfig.BaseCY -and $actualValues.BaseCY -ne $ExpectedConfig.BaseCY) {
            $validationResults.Issues += "Base Height: Expected $($ExpectedConfig.BaseCY), Actual $($actualValues.BaseCY)"
            $validationResults.Success = $false
        }

        if ($ExpectedConfig.OutputCX -and $actualValues.OutputCX -ne $ExpectedConfig.OutputCX) {
            $validationResults.Issues += "Output Width: Expected $($ExpectedConfig.OutputCX), Actual $($actualValues.OutputCX)"
            $validationResults.Success = $false
        }

        if ($ExpectedConfig.OutputCY -and $actualValues.OutputCY -ne $ExpectedConfig.OutputCY) {
            $validationResults.Issues += "Output Height: Expected $($ExpectedConfig.OutputCY), Actual $($actualValues.OutputCY)"
            $validationResults.Success = $false
        }

        if ($ExpectedConfig.VBitrate -and $actualValues.VBitrate -ne $ExpectedConfig.VBitrate) {
            $validationResults.Issues += "Video Bitrate: Expected $($ExpectedConfig.VBitrate) kbps, Actual $($actualValues.VBitrate) kbps"
            $validationResults.Success = $false
        }

        if ($ExpectedConfig.ABitrate -and $actualValues.ABitrate -ne $ExpectedConfig.ABitrate) {
            $validationResults.Issues += "Audio Bitrate: Expected $($ExpectedConfig.ABitrate) kbps, Actual $($actualValues.ABitrate) kbps"
            $validationResults.Success = $false
        }

        # Validate encoders with improved logic to handle both Simple and Advanced encoder names
        if ($ExpectedConfig.Encoder) {
            # Create mapping of Simple Output encoder names to their Advanced Output equivalents
            $encoderMapping = @{
                'amd'        = @('amd', 'amd_amf_h264')
                'nvenc_h264' = @('nvenc_h264', 'ffmpeg_nvenc')
                'obs_qsv11'  = @('obs_qsv11', 'obs_qsv11')
                'x264'       = @('x264', 'obs_x264')
            }

            $expectedEncoders = $encoderMapping[$ExpectedConfig.Encoder]
            if (-not $expectedEncoders) {
                $expectedEncoders = @($ExpectedConfig.Encoder)  # Fallback to exact match
            }

            # Check Recording Encoder (with fallback to Advanced encoder if Simple not found)
            $actualRecEncoder = if ($actualValues.RecEncoder) { $actualValues.RecEncoder } else { $actualValues.AdvancedEncoder }
            if ($actualRecEncoder -and $actualRecEncoder -notin $expectedEncoders) {
                $encoderSource = if ($actualValues.RecEncoder) { 'Simple Output' } else { 'Advanced Output (fallback)' }
                $validationResults.Issues += "Recording Encoder ($encoderSource): Expected one of [$($expectedEncoders -join ', ')], Actual '$actualRecEncoder'"
                $validationResults.Success = $false
            }

            # Check Streaming Encoder (with fallback to Advanced encoder if Simple not found)
            $actualStreamEncoder = if ($actualValues.StreamEncoder) { $actualValues.StreamEncoder } else { $actualValues.AdvancedEncoder }
            if ($actualStreamEncoder -and $actualStreamEncoder -notin $expectedEncoders) {
                $encoderSource = if ($actualValues.StreamEncoder) { 'Simple Output' } else { 'Advanced Output (fallback)' }
                $validationResults.Issues += "Streaming Encoder ($encoderSource): Expected one of [$($expectedEncoders -join ', ')], Actual '$actualStreamEncoder'"
                $validationResults.Success = $false
            }
        }

        if ($actualValues.RecAudioEncoder -ne 'aac') {
            $validationResults.Issues += "Recording Audio Encoder: Expected 'aac', Actual '$($actualValues.RecAudioEncoder)'"
            $validationResults.Success = $false
        }

        if ($actualValues.StreamAudioEncoder -ne 'aac') {
            $validationResults.Issues += "Streaming Audio Encoder: Expected 'aac', Actual '$($actualValues.StreamAudioEncoder)'"
            $validationResults.Success = $false
        }

        if ($ExpectedConfig.FPS -and $actualValues.FPSCommon -ne $ExpectedConfig.FPS) {
            $validationResults.Issues += "FPS: Expected $($ExpectedConfig.FPS), Actual $($actualValues.FPSCommon)"
            $validationResults.Success = $false
        }

        # Report results
        if ($validationResults.Success) {
            Write-Success 'Configuration validation PASSED - All settings match expected values'
        } else {
            Write-Warning 'Configuration validation FAILED - Found discrepancies:'
            foreach ($issue in $validationResults.Issues) {
                Write-Warning "  [X] $issue"
            }
        }

        # Always show actual values for transparency
        Write-Info 'Actual OBS Configuration:'
        Write-Info "  - Base Resolution: $($actualValues.BaseCX)x$($actualValues.BaseCY)"
        Write-Info "  - Output Resolution: $($actualValues.OutputCX)x$($actualValues.OutputCY)"
        Write-Info "  - Video Bitrate: $($actualValues.VBitrate) kbps"
        Write-Info "  - Audio Bitrate: $($actualValues.ABitrate) kbps"
        Write-Info "  - Recording Encoder (Simple): $($actualValues.RecEncoder)"
        Write-Info "  - Streaming Encoder (Simple): $($actualValues.StreamEncoder)"
        Write-Info "  - Advanced Encoder: $($actualValues.AdvancedEncoder)"

        # Show which encoders were used for validation
        if ($ExpectedConfig.Encoder) {
            $actualRecForValidation = if ($actualValues.RecEncoder) { $actualValues.RecEncoder } else { $actualValues.AdvancedEncoder }
            $actualStreamForValidation = if ($actualValues.StreamEncoder) { $actualValues.StreamEncoder } else { $actualValues.AdvancedEncoder }
            Write-Info "  - Validation Used - Rec: '$actualRecForValidation', Stream: '$actualStreamForValidation'"
        }
        Write-Info "  - Recording Audio Encoder: $($actualValues.RecAudioEncoder)"
        Write-Info "  - Streaming Audio Encoder: $($actualValues.StreamAudioEncoder)"
        Write-Info "  - FPS: $($actualValues.FPSCommon)"
        Write-Info "  - Format: $($actualValues.RecFormat2)"

        return $validationResults

    } catch {
        Write-Error "Failed to validate OBS configuration: $($_.Exception.Message)"
        return $false
    }
}

function Install-VCRedist {
    <#
    .SYNOPSIS
    Installs Visual C++ Redistributable AIO for plugin dependencies
    Only installs if not already present on the system
    #>

    # Check if VCRedist is already installed
    if (Test-VCRedistInstalled) {
        Write-Success 'Visual C++ Redistributable already installed - skipping download'
        return $true
    }

    Write-Info 'Installing Visual C++ Redistributable (required for plugins)...'

    try {
        # Download VCRedist AIO from GitHub
        $vcRedistUrl = 'https://github.com/abbodi1406/vcredist/releases/latest/download/VisualCppRedist_AIO_x86_x64.exe'
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $vcRedistPath = "${env:TEMP}\VisualCppRedist_AIO_${timestamp}.exe"

        Invoke-RobustDownload -Uri $vcRedistUrl -OutFile $vcRedistPath -Description 'VCRedist AIO' -ShowProgress $true

        Write-Info 'Installing VCRedist silently...'
        # Try to install VCRedist - may require admin rights
        try {
            Start-Process -FilePath $vcRedistPath -ArgumentList '/ai' -Wait -NoNewWindow -ErrorAction Stop
        } catch {
            Write-Warning 'VCRedist installation requires administrator rights'
            Write-Info "VCRedist installer downloaded to: $vcRedistPath"
            Write-Info "Please run manually with admin rights if plugins don't work"
            return $false
        }

        Remove-Item $vcRedistPath -Force -ErrorAction SilentlyContinue
        Write-Success 'VCRedist installed successfully'
        return $true

    } catch {
        Write-Error "VCRedist installation failed: $($_.Exception.Message)"
        return $false
    }
}

function Install-InputOverlayPlugin {
    <#
    .SYNOPSIS
    Installs Input Overlay plugin with presets
    #>

    param([string]$InstallPath)

    Write-Info 'Installing Input Overlay plugin...'

    try {
        # Get latest Input Overlay release from GitHub API
        $apiUrl = 'https://api.github.com/repos/univrsal/input-overlay/releases/latest'
        $response = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop

        # Find Windows x64 asset
        $windowsAsset = $response.assets | Where-Object { $_.name -like '*windows-x64.zip' } | Select-Object -First 1
        if (-not $windowsAsset) {
            throw 'No Windows x64 asset found in latest release'
        }

        $pluginUrl = $windowsAsset.browser_download_url
        $presetsUrl = 'https://github.com/univrsal/input-overlay/releases/download/5.0.6/input-overlay-5.0.6-presets.zip'

        Write-Info "Found Input Overlay version: $($response.tag_name)"

        $pluginZip = "${env:TEMP}\input-overlay-plugin.zip"
        $presetsZip = "${env:TEMP}\input-overlay-presets.zip"
        $pluginExtract = "${env:TEMP}\input-overlay-plugin"
        $presetsExtract = "${env:TEMP}\input-overlay-presets"

        Invoke-RobustDownload -Uri $pluginUrl -OutFile $pluginZip -Description "Input Overlay plugin ($($response.tag_name))" -ShowProgress $true
        Invoke-RobustDownload -Uri $presetsUrl -OutFile $presetsZip -Description 'Input Overlay presets' -ShowProgress $true

        Write-Info 'Extracting plugin files...'
        Expand-Archive $pluginZip $pluginExtract -Force
        Expand-Archive $presetsZip $presetsExtract -Force

        # Install plugin DLLs
        $pluginDllPath = "$pluginExtract\obs-plugins\64bit"
        if (Test-Path $pluginDllPath) {
            Copy-Item "$pluginDllPath\*" "$InstallPath\obs-plugins\64bit\" -Force
            Write-Info 'Plugin DLLs installed'
        }

        # Install plugin data
        $pluginDataPath = "$pluginExtract\data"
        if (Test-Path $pluginDataPath) {
            Copy-Item "$pluginDataPath\*" "$InstallPath\data\" -Recurse -Force
            Write-Info 'Plugin data installed'
        }

        # Install presets (extract the zip contents properly)
        New-Item -Path "$InstallPath\data\input-overlay-presets" -ItemType Directory -Force | Out-Null

        # The presets download is a zip file, extract it first
        $presetsZipFile = Get-ChildItem "$presetsExtract\*.zip" | Select-Object -First 1
        if ($presetsZipFile) {
            $presetsContent = "${env:TEMP}\input-overlay-presets-content"
            Expand-Archive $presetsZipFile.FullName $presetsContent -Force
            Copy-Item "$presetsContent\*" "$InstallPath\data\input-overlay-presets\" -Recurse -Force
            Remove-Item $presetsContent -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            # Fallback: copy extracted content directly if no zip found
            if (Test-Path $presetsExtract) {
                Copy-Item "$presetsExtract\*" "$InstallPath\data\input-overlay-presets\" -Recurse -Force
            }
        }

        Write-Info "Presets installed to: $InstallPath\data\input-overlay-presets\"

        # Install custom input history template in input-history-windows folder
        try {
            # Create input-history-windows folder
            $inputHistoryPath = "$InstallPath\data\input-overlay-presets\input-history-windows"
            New-Item -Path $inputHistoryPath -ItemType Directory -Force | Out-Null

            # Copy professional custom input history template from local templates
            $scriptPath = if ($MyInvocation.ScriptName) {
                Split-Path -Parent $MyInvocation.ScriptName
            } else {
                $PWD.Path
            }
            $localTemplatePath = Join-Path $scriptPath 'templates\input-overlay\custom-input-history.html'
            $templateDestPath = "$inputHistoryPath\custom-input-history.html"

            if (Test-Path $localTemplatePath) {
                Copy-Item -Path $localTemplatePath -Destination $templateDestPath -Force
                Write-Success 'Professional input history template installed from local templates'
            } else {
                # Fallback: Download from latest release assets
                $templateUrl = 'https://github.com/emilwojcik93/obs-portable/releases/latest/download/custom-input-history.html'
                Invoke-RobustDownload -Uri $templateUrl -OutFile $templateDestPath -Description 'professional input history template' -ShowProgress $false
            }

            Write-Info "Professional input history template installed to: $inputHistoryPath\"
            Write-Info 'Setup Instructions:'
            Write-Info '  1. Tools > input-overlay-settings > WebSocket Server > Enable checkbox'
            Write-Info '  2. Add Browser Source > Local File > Browse to:'
            Write-Info "     $templateDestPath"
            Write-Info '  3. Set Width: 280, Height: 400'
        } catch {
            Write-Warning "Failed to download professional input history template: $($_.Exception.Message)"
            Write-Info 'Use standard Input Overlay presets from: $InstallPath\data\input-overlay-presets\'
            Write-Info 'Professional template available at: https://github.com/emilwojcik93/obs-portable/releases/latest/download/custom-input-history.html'
        }

        # Cleanup
        Remove-Item $pluginZip, $presetsZip -Force -ErrorAction SilentlyContinue
        Remove-Item $pluginExtract, $presetsExtract -Recurse -Force -ErrorAction SilentlyContinue

        Write-Success 'Input Overlay plugin installed successfully'
        return $true

    } catch {
        Write-Error "Input Overlay installation failed: $($_.Exception.Message)"
        return $false
    }
}

function Install-OpenVINOPlugin {
    <#
    .SYNOPSIS
    Installs OpenVINO plugins for Intel hardware acceleration
    #>

    param([string]$InstallPath)

    Write-Info 'Installing OpenVINO plugins for Intel hardware acceleration...'

    try {
        # Download OpenVINO OBS plugins
        $openvinoUrl = 'https://github.com/intel/openvino-plugins-for-obs-studio/releases/latest/download/openvino_obs_plugins_v1.1.zip'
        $openvinoZip = "${env:TEMP}\openvino-obs-plugins.zip"
        $openvinoExtract = "${env:TEMP}\openvino-obs-plugins"

        Invoke-RobustDownload -Uri $openvinoUrl -OutFile $openvinoZip -Description 'OpenVINO OBS plugins v1.1' -ShowProgress $true

        Write-Info 'Extracting OpenVINO files...'
        Expand-Archive $openvinoZip $openvinoExtract -Force

        # Install plugin DLLs
        $pluginDllPath = "$openvinoExtract\obs-plugins\64bit"
        if (Test-Path $pluginDllPath) {
            Copy-Item "$pluginDllPath\*" "$InstallPath\obs-plugins\64bit\" -Force
            Write-Info 'OpenVINO plugin DLLs installed'
        }

        # Install plugin data (models and configs)
        $pluginDataPath = "$openvinoExtract\data"
        if (Test-Path $pluginDataPath) {
            Copy-Item "$pluginDataPath\*" "$InstallPath\data\" -Recurse -Force
            Write-Info 'OpenVINO models and data installed'
        }

        # Cleanup
        Remove-Item $openvinoZip -Force -ErrorAction SilentlyContinue
        Remove-Item $openvinoExtract -Recurse -Force -ErrorAction SilentlyContinue

        Write-Success 'OpenVINO plugins installed successfully'
        Write-Info 'Available filters: Background Concealment, Face Mesh, Smart Framing'
        return $true

    } catch {
        Write-Error "OpenVINO installation failed: $($_.Exception.Message)"
        return $false
    }
}

function Start-OBSFirstTime {
    param([hashtable]$SystemConfig)

    Write-Info '=== OBS Studio First-Time Interactive Setup ==='

    if ($WhatIfPreference) {
        Write-Info '[WHATIF] Would launch OBS for interactive first-time setup'
        return $true
    }

    try {
        $obsExePath = Join-Path $InstallPath 'bin\64bit\obs64.exe'

        Write-Host ''
        Write-Host '========================================' -ForegroundColor Yellow
        Write-Host '  OBS Studio First-Time Setup Required  ' -ForegroundColor Yellow
        Write-Host '========================================' -ForegroundColor Yellow
        Write-Host ''
        Write-Host 'Required Steps:' -ForegroundColor Cyan
        Write-Host '1. Complete Auto-Configuration Wizard' -ForegroundColor Green
        Write-Host "   - Usage Information: Choose 'Optimize just for recording'" -ForegroundColor White
        Write-Host "   - Video Settings: Base Resolution '$($SystemConfig.Display.ActualResolution.Width)x$($SystemConfig.Display.ActualResolution.Height)'" -ForegroundColor White
        Write-Host "   - Video Settings: FPS 'Either 60 or 30, but prefer 60 when possible'" -ForegroundColor White
        Write-Host '   - Click Next > Next > Apply Settings' -ForegroundColor White
        Write-Host '2. Add Display Capture Source' -ForegroundColor Green
        Write-Host "   - Click '+' in Sources panel, select 'Display Capture'" -ForegroundColor White
        Write-Host "   - Create new: 'Display Capture', click OK" -ForegroundColor White
        Write-Host '   - Display: Select your primary monitor' -ForegroundColor White
        Write-Host "   - Capture Method: 'Automatic', click OK" -ForegroundColor White
        Write-Host '3. Close OBS when setup is complete' -ForegroundColor Green
        Write-Host ''
        Write-Host 'Optional Enhancements:' -ForegroundColor Cyan
        Write-Host '4. Add Webcam (Optional)' -ForegroundColor Yellow
        Write-Host "   - Click '+' in Sources, add 'Video Capture Device'" -ForegroundColor White
        Write-Host '5. Configure Audio Input (Optional)' -ForegroundColor Yellow
        Write-Host "   - Click '+' in Sources, add 'Audio Input Capture'" -ForegroundColor White
        Write-Host '6. Configure Audio Output (Optional)' -ForegroundColor Yellow
        Write-Host "   - Click '+' in Sources, add 'Audio Output Capture'" -ForegroundColor White

        # Show plugin setup instructions if plugins are being installed
        if ($InstallInputOverlay -or $InstallOpenVINO) {
            Write-Host ''
            Write-Host 'Plugin Setup (After Auto-Configuration):' -ForegroundColor Magenta

            if ($InstallInputOverlay) {
                Write-Host '7. Setup Input Overlay (Keyboard/Mouse Visualization)' -ForegroundColor Yellow
                Write-Host '   - Tools > input-overlay-settings > WebSocket Server > Enable checkbox' -ForegroundColor White
                Write-Host '   - Add Browser Source > Local File > Browse to:' -ForegroundColor White
                Write-Host "     $InstallPath\data\input-overlay-presets\input-history-windows\custom-input-history.html" -ForegroundColor Gray
                Write-Host '   - Set Width: 280, Height: 400' -ForegroundColor White
            }

            if ($InstallOpenVINO) {
                Write-Host '8. Setup OpenVINO Webcam Effects (Intel Hardware)' -ForegroundColor Yellow
                Write-Host '   - Add Source > Video Capture Device > Choose camera > OK' -ForegroundColor White
                Write-Host '   - Right-click webcam source > Filters > Add > OpenVINO Background Concealment' -ForegroundColor White
                Write-Host '   - Configure: Threshold 0.5, Contour Filter 0.05, Smooth Contour 0.5' -ForegroundColor White
            }
        }

        Write-Host ''
        Write-Host 'Launching OBS Studio in 2 seconds...' -ForegroundColor Yellow
        Start-Sleep -Seconds 2

        Push-Location (Join-Path $InstallPath 'bin\64bit')
        $obsProcess = Start-Process -FilePath '.\obs64.exe' -ArgumentList @('--portable') -PassThru
        Pop-Location

        Write-Success 'OBS Studio launched - complete setup and close OBS to continue'
        $obsProcess.WaitForExit()
        Write-Success 'OBS closed - continuing with optimization...'
        Start-Sleep -Seconds 3

        return $true

    } catch {
        Write-Error "First-time setup failed: $($_.Exception.Message)"
        return $false
    }
}

function Optimize-OBSConfiguration {
    param([hashtable]$SystemConfig)

    Write-Info '=== Optimizing OBS Configuration ==='

    if ($WhatIfPreference) {
        Write-Info '[WHATIF] Would optimize OBS configuration'
        return $true
    }

    try {
        $profilePath = Join-Path $InstallPath 'config\obs-studio\basic\profiles\Untitled\basic.ini'

        if (-not (Test-Path $profilePath)) {
            Write-Warning 'OBS configuration not found - please ensure you completed the setup'
            return $false
        }

        # Read and optimize existing configuration
        $config = Get-Content $profilePath -Raw

        # Apply hardware-specific encoders for both streaming and recording
        # Simple Output mode uses different encoder identifiers than Advanced mode
        $simpleEncoder = switch ($SystemConfig.GPU.Type) {
            'AMD' { 'amd' }           # Simple mode: AMD hardware encoding (confirmed working)
            'NVIDIA' { 'nvenc_h264' }    # Simple mode uses 'nvenc_h264' for NVIDIA NVENC
            'Intel' { 'obs_qsv11' }     # Simple mode uses 'obs_qsv11' for Intel QuickSync
            default { 'x264' }          # Fallback to software encoding
        }

        Write-Verbose "Using Simple Output encoder: $simpleEncoder (GPU Type: $($SystemConfig.GPU.Type))"
        $config = $config -replace 'RecEncoder=.*', "RecEncoder=$simpleEncoder"
        $config = $config -replace 'StreamEncoder=.*', "StreamEncoder=$simpleEncoder"
        # Advanced Output mode uses the full encoder name
        $config = $config -replace 'Encoder=.*', "Encoder=$($SystemConfig.GPU.Encoder)"

        # Set audio encoders properly (AAC for audio, not video encoder)
        $config = $config -replace 'RecAudioEncoder=.*', 'RecAudioEncoder=aac'
        $config = $config -replace 'StreamAudioEncoder=.*', 'StreamAudioEncoder=aac'
        $config = $config -replace 'AudioEncoder=.*', 'AudioEncoder=aac'

        # Set video bitrate
        $config = $config -replace 'VBitrate=.*', "VBitrate=$($SystemConfig.GPU.Bitrate)"

        # Set OneDrive output path
        $oneDrivePath = $SystemConfig.OneDrive.Path -replace '\\', '\\\\'
        $config = $config -replace 'FilePath=.*', "FilePath=$oneDrivePath"
        $config = $config -replace 'RecFilePath=.*', "RecFilePath=$oneDrivePath"

        # Apply optimization settings based on performance mode
        switch ($PerformanceMode) {
            '33' {
                # Extreme performance for severe encoder overload
                $config = $config -replace '(?i)A[Bb]itrate=.*', 'Abitrate=64'
                $config = $config -replace '(?i)FFAbitrate=.*', 'FFAbitrate=64'
                $config = $config -replace '(?i)Track([1-6])bitrate=.*', 'Track$1bitrate=64'
                $config = $config -replace 'Preset=.*', 'Preset=ultrafast'
                $config = $config -replace 'FPSType=.*', 'FPSType=0'
                $config = $config -replace 'FPSCommon=.*', 'FPSCommon=24'  # Lower FPS
                $config = $config -replace 'ColorFormat=.*', 'ColorFormat=NV12'

                # GPU-specific extreme optimizations
                if ($SystemConfig.GPU.Type -eq 'Intel') {
                    $config += "`nQSVPreset=speed"
                    $config += "`nQSVTargetUsage=1"
                    $config += "`nQSVAsyncDepth=1"
                    $config += "`nQSVBFrames=0"
                } elseif ($SystemConfig.GPU.Type -eq 'AMD') {
                    $config += "`nAMFPreAnalysis=true"
                    $config += "`nAMFBFrames=0"
                    $config += "`nAMFEnforceHRD=false"
                    $config += "`nAMFFillerData=false"
                    $config += "`nAMFVBAQ=false"
                    $config += "`nAMFLowLatency=true"
                } elseif ($SystemConfig.GPU.Type -eq 'NVIDIA') {
                    $config += "`nNVENCPreset=p1"
                    $config += "`nNVENCTuning=ull"
                    $config += "`nNVENCMultipass=disabled"
                    $config += "`nNVENCBFrames=0"
                }
                Write-Info 'Applied extreme performance settings (33% scaling, 24fps)'
            }
            '50' {
                # Ultra-lightweight performance
                $config = $config -replace '(?i)A[Bb]itrate=.*', 'Abitrate=96'
                $config = $config -replace '(?i)FFAbitrate=.*', 'FFAbitrate=96'
                $config = $config -replace '(?i)Track([1-6])bitrate=.*', 'Track$1bitrate=96'
                $config = $config -replace 'Preset=.*', 'Preset=ultrafast'
                $config = $config -replace 'FPSType=.*', 'FPSType=0'
                $config = $config -replace 'FPSCommon=.*', 'FPSCommon=30'

                # GPU-specific optimizations
                if ($SystemConfig.GPU.Type -eq 'AMD') {
                    $config += "`nAMFPreAnalysis=true"
                    $config += "`nAMFBFrames=0"
                } elseif ($SystemConfig.GPU.Type -eq 'Intel') {
                    $config += "`nQSVPreset=speed"
                    $config += "`nQSVTargetUsage=1"
                }
                Write-Info 'Applied ultra-lightweight settings (50% scaling)'
            }
            '60' {
                # Lightweight performance (default ultra)
                $config = $config -replace '(?i)A[Bb]itrate=.*', 'Abitrate=96'
                $config = $config -replace '(?i)FFAbitrate=.*', 'FFAbitrate=96'
                $config = $config -replace '(?i)Track([1-6])bitrate=.*', 'Track$1bitrate=96'
                $config = $config -replace 'Preset=.*', 'Preset=fast'
                $config = $config -replace 'FPSType=.*', 'FPSType=0'
                $config = $config -replace 'FPSCommon=.*', 'FPSCommon=30'

                if ($SystemConfig.GPU.Type -eq 'AMD') {
                    $config += "`nAMFPreAnalysis=true"
                    $config += "`nAMFBFrames=0"
                }
                Write-Info 'Applied lightweight settings (60% scaling - default ultra)'
            }
            '75' {
                # Optimized performance
                $config = $config -replace '(?i)A[Bb]itrate=.*', 'Abitrate=128'
                $config = $config -replace '(?i)FFAbitrate=.*', 'FFAbitrate=128'
                $config = $config -replace '(?i)Track([1-6])bitrate=.*', 'Track$1bitrate=128'
                $config = $config -replace 'Preset=.*', 'Preset=fast'
                $config = $config -replace 'FPSType=.*', 'FPSType=0'
                $config = $config -replace 'FPSCommon=.*', 'FPSCommon=30'

                if ($SystemConfig.GPU.Type -eq 'AMD') {
                    $config += "`nAMFPreAnalysis=true"
                    $config += "`nAMFBFrames=2"
                }
                Write-Info 'Applied optimized settings (75% scaling)'
            }
            '90' {
                # Standard performance
                $config = $config -replace '(?i)A[Bb]itrate=.*', 'Abitrate=160'
                $config = $config -replace '(?i)FFAbitrate=.*', 'FFAbitrate=160'
                $config = $config -replace '(?i)Track([1-6])bitrate=.*', 'Track$1bitrate=160'
                $config = $config -replace 'Preset=.*', 'Preset=balanced'
                $config = $config -replace 'FPSType=.*', 'FPSType=0'
                $config = $config -replace 'FPSCommon=.*', 'FPSCommon=30'
                Write-Info 'Applied standard settings (90% scaling)'
            }
        }

        # Apply critical resolution and encoder settings
        $baseWidth = $SystemConfig.Display.ActualResolution.Width
        $baseHeight = $SystemConfig.Display.ActualResolution.Height
        $outputWidth = $SystemConfig.Display.RecordingResolution.Width
        $outputHeight = $SystemConfig.Display.RecordingResolution.Height

        # Set base canvas resolution
        $config = $config -replace 'BaseCX=.*', "BaseCX=$baseWidth"
        $config = $config -replace 'BaseCY=.*', "BaseCY=$baseHeight"

        # Set output scaled resolution
        $config = $config -replace 'OutputCX=.*', "OutputCX=$outputWidth"
        $config = $config -replace 'OutputCY=.*', "OutputCY=$outputHeight"

        # Set encoders for both streaming and recording
        # Simple Output mode uses different encoder identifiers than Advanced mode
        $simpleEncoder = switch ($SystemConfig.GPU.Type) {
            'AMD' { 'amd' }           # Simple mode: AMD hardware encoding (confirmed working)
            'NVIDIA' { 'nvenc_h264' }    # Simple mode uses 'nvenc_h264' for NVIDIA NVENC
            'Intel' { 'obs_qsv11' }     # Simple mode uses 'obs_qsv11' for Intel QuickSync
            default { 'x264' }          # Fallback to software encoding
        }

        Write-Verbose "Using Simple Output encoder: $simpleEncoder (GPU Type: $($SystemConfig.GPU.Type))"
        $config = $config -replace 'RecEncoder=.*', "RecEncoder=$simpleEncoder"
        $config = $config -replace 'StreamEncoder=.*', "StreamEncoder=$simpleEncoder"
        # Advanced Output mode uses the full encoder name
        $config = $config -replace 'Encoder=.*', "Encoder=$($SystemConfig.GPU.Encoder)"

        # Set audio encoders properly (AAC for audio, not video encoder)
        $config = $config -replace 'RecAudioEncoder=.*', 'RecAudioEncoder=aac'
        $config = $config -replace 'StreamAudioEncoder=.*', 'StreamAudioEncoder=aac'
        $config = $config -replace 'AudioEncoder=.*', 'AudioEncoder=aac'

        # Set video bitrate only
        $config = $config -replace 'VBitrate=.*', "VBitrate=$($SystemConfig.GPU.Bitrate)"
        # Note: Do not replace all 'bitrate' - it affects audio settings

        # Set downscale filter (Bicubic for quality, Bilinear for performance)
        $downscaleFilter = if ($UltraLightweight) { 'bilinear' } else { 'bicubic' }
        $config = $config -replace 'ScaleType=.*', "ScaleType=$downscaleFilter"

        # Ensure MKV format
        $config = $config -replace 'RecFormat2=.*', 'RecFormat2=mkv'

        Set-Content -Path $profilePath -Value $config -Encoding UTF8

        # Update scene configuration with correct monitor ID
        $scenePath = Join-Path $InstallPath 'config\obs-studio\basic\scenes\Untitled.json'
        if (Test-Path $scenePath) {
            Write-Verbose "Updating scene configuration with monitor ID: $($SystemConfig.Display.MonitorId)"
            try {
                $sceneContent = Get-Content -Path $scenePath -Raw | ConvertFrom-Json

                # Find and update Display Capture sources
                $displaySources = $sceneContent.sources | Where-Object { $_.id -eq 'monitor_capture' }
                if ($displaySources) {
                    foreach ($source in $displaySources) {
                        $oldMonitorId = $source.settings.monitor_id
                        # Set monitor ID directly - ConvertTo-Json will handle escaping
                        $source.settings.monitor_id = $SystemConfig.Display.MonitorId
                        Write-Verbose "Updated Display Capture source '$($source.name)': $oldMonitorId -> $($SystemConfig.Display.MonitorId)"
                    }

                    # Update scale reference and positioning in scene items
                    $scene = $sceneContent.sources | Where-Object { $_.id -eq 'scene' }
                    if ($scene -and $scene.settings.items) {
                        foreach ($item in $scene.settings.items) {
                            if ($item.name -eq 'Display Capture') {
                                # Use simple "Fit to Screen" approach - equivalent to Ctrl+F in OBS
                                $item.scale_ref = @{
                                    x = [double]$SystemConfig.Display.ActualResolution.Width
                                    y = [double]$SystemConfig.Display.ActualResolution.Height
                                }
                                $item.pos = @{
                                    x = 0.0
                                    y = 0.0
                                }
                                $item.scale = @{
                                    x = 1.0
                                    y = 1.0
                                }
                                $item.bounds = @{
                                    x = [double]$SystemConfig.Display.ActualResolution.Width
                                    y = [double]$SystemConfig.Display.ActualResolution.Height
                                }
                                $item.bounds_type = 0  # No bounds scaling
                                $item.bounds_align = 0
                                $item.align = 5  # Center alignment

                                Write-Verbose 'Updated Display Capture with simple fit-to-screen:'
                                Write-Verbose "  - Resolution: $($SystemConfig.Display.ActualResolution.Width)x$($SystemConfig.Display.ActualResolution.Height)"
                                Write-Verbose '  - Position: 0,0'
                                Write-Verbose '  - Scale: 1.0'
                            }
                        }
                    }

                    # Save updated scene configuration
                    $updatedSceneContent = $sceneContent | ConvertTo-Json -Depth 10
                    Set-Content -Path $scenePath -Value $updatedSceneContent -Encoding UTF8
                    Write-Verbose 'Scene configuration updated successfully'
                } else {
                    Write-Warning 'No Display Capture sources found in scene configuration - creating one'

                    # Create a new Display Capture source
                    $newDisplaySource = @{
                        prev_ver                = 520159234
                        name                    = 'Display Capture'
                        uuid                    = [System.Guid]::NewGuid().ToString()
                        id                      = 'monitor_capture'
                        versioned_id            = 'monitor_capture'
                        settings                = @{
                            monitor_id = $SystemConfig.Display.MonitorId
                        }
                        mixers                  = 0
                        sync                    = 0
                        flags                   = 0
                        volume                  = 1.0
                        balance                 = 0.5
                        enabled                 = $true
                        muted                   = $false
                        'push-to-mute'          = $false
                        'push-to-mute-delay'    = 0
                        'push-to-talk'          = $false
                        'push-to-talk-delay'    = 0
                        hotkeys                 = @{}
                        deinterlace_mode        = 0
                        deinterlace_field_order = 0
                        monitoring_type         = 0
                        private_settings        = @{}
                    }

                    # Add the new source to the scene
                    $sceneContent.sources += $newDisplaySource

                    # Also add it to the scene items if there's a scene
                    $scene = $sceneContent.sources | Where-Object { $_.id -eq 'scene' }
                    if ($scene) {
                        # Create simple Display Capture item with basic fit-to-screen settings
                        $newItem = @{
                            name              = 'Display Capture'
                            source_uuid       = $newDisplaySource.uuid
                            visible           = $true
                            locked            = $false
                            rot               = 0.0
                            scale_ref         = @{
                                x = [double]$SystemConfig.Display.ActualResolution.Width
                                y = [double]$SystemConfig.Display.ActualResolution.Height
                            }
                            align             = 5  # Center alignment
                            bounds_type       = 0  # No bounds scaling
                            bounds_align      = 0
                            bounds_crop       = $false
                            crop_left         = 0
                            crop_top          = 0
                            crop_right        = 0
                            crop_bottom       = 0
                            id                = if ($scene.settings.items) { ($scene.settings.items | Measure-Object id -Maximum).Maximum + 1 } else { 1 }
                            group_item_backup = $false
                            pos               = @{ x = 0.0; y = 0.0 }
                            scale             = @{ x = 1.0; y = 1.0 }
                            bounds            = @{
                                x = [double]$SystemConfig.Display.ActualResolution.Width
                                y = [double]$SystemConfig.Display.ActualResolution.Height
                            }
                            scale_filter      = 'disable'
                            blend_method      = 'default'
                            blend_type        = 'normal'
                            private_settings  = @{}
                        }

                        Write-Verbose 'Created simple Display Capture item:'
                        Write-Verbose "  - Resolution: $($SystemConfig.Display.ActualResolution.Width)x$($SystemConfig.Display.ActualResolution.Height)"
                        Write-Verbose '  - Position: 0,0'
                        Write-Verbose '  - Scale: 1.0'

                        if (-not $scene.settings.items) {
                            $scene.settings.items = @()
                        }
                        $scene.settings.items += $newItem
                        $scene.settings.id_counter = $newItem.id + 1

                        Write-Verbose "Created new Display Capture source and scene item for monitor: $($SystemConfig.Display.MonitorId)"
                    }

                    # Save the updated scene configuration with new Display Capture source
                    $updatedSceneContent = $sceneContent | ConvertTo-Json -Depth 10
                    Set-Content -Path $scenePath -Value $updatedSceneContent -Encoding UTF8
                    Write-Verbose 'Scene configuration saved with new Display Capture source'
                }
            } catch {
                Write-Warning "Failed to update scene configuration: $($_.Exception.Message)"
            }
        } else {
            Write-Warning "Scene configuration file not found: $scenePath"
        }

        # Verify configuration was applied
        $verifyConfig = Get-Content -Path $profilePath -Raw
        $actualBaseCX = if ($verifyConfig -match 'BaseCX=(\d+)') { $matches[1] } else { 'Not Set' }
        $actualBaseCY = if ($verifyConfig -match 'BaseCY=(\d+)') { $matches[1] } else { 'Not Set' }
        $actualOutputCX = if ($verifyConfig -match 'OutputCX=(\d+)') { $matches[1] } else { 'Not Set' }
        $actualOutputCY = if ($verifyConfig -match 'OutputCY=(\d+)') { $matches[1] } else { 'Not Set' }
        $actualBitrate = if ($verifyConfig -match 'VBitrate=(\d+)') { $matches[1] } else { 'Not Set' }

        Write-Success 'OBS configuration optimized!'
        Write-Info 'Applied Settings:'
        Write-Info "  - Base Resolution: ${actualBaseCX}x${actualBaseCY} (configured: ${baseWidth}x${baseHeight})"
        Write-Info "  - Output Resolution: ${actualOutputCX}x${actualOutputCY} (configured: ${outputWidth}x${outputHeight})"
        Write-Info "  - Encoder: $($SystemConfig.GPU.Name)"
        Write-Info "  - Bitrate: ${actualBitrate} kbps (dynamic: $($SystemConfig.GPU.Bitrate) kbps)"
        Write-Info '  - Output: OneDrive\Recordings'
        Write-Info '  - Format: MKV'
        $audioBitrate = switch ($PerformanceMode) { '33' { '64' } '50' { '96' } '60' { '96' } '75' { '128' } '90' { '160' } }
        $fps = if ($PerformanceMode -eq '33') { '24' } else { '30' }
        $modeDescription = switch ($PerformanceMode) {
            '33' { "Extreme Performance (33% scaling, ${fps}fps, ${audioBitrate}kbps audio)" }
            '50' { "Ultra-Lightweight (50% scaling, ${fps}fps, ${audioBitrate}kbps audio)" }
            '60' { "Lightweight (60% scaling, ${fps}fps, ${audioBitrate}kbps audio)" }
            '75' { "Optimized (75% scaling, ${fps}fps, ${audioBitrate}kbps audio)" }
            '90' { "Standard (90% scaling, ${fps}fps, ${audioBitrate}kbps audio)" }
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

    Write-Info '=== Installing Auto-Recording Service ==='

    if ($WhatIfPreference) {
        Write-Info '[WHATIF] Would install auto-recording service'
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
        $serviceScript = $serviceScript.Replace('INSTALL_PATH_PLACEHOLDER', $InstallPath)
        $serviceScript = $serviceScript.Replace('ONEDRIVE_PATH_PLACEHOLDER', $OneDrivePath)

        $serviceScriptPath = Join-Path $InstallPath 'OBSAutoRecord.ps1'
        Set-Content -Path $serviceScriptPath -Value $serviceScript -Encoding UTF8

        # Create OBS folder in Task Scheduler
        $taskService = New-Object -ComObject Schedule.Service
        $taskService.Connect()
        $rootFolder = $taskService.GetFolder('\')

        try {
            $obsFolder = $rootFolder.GetFolder('OBS')
        } catch {
            $obsFolder = $rootFolder.CreateFolder('OBS')
        }

        # Create essential scheduled tasks only
        $obsExeDir = Join-Path $InstallPath 'bin\64bit'
        $tasks = @(
            @{
                Name        = 'AutoRecord-Start'
                Description = 'Start OBS recording on user login'
                Trigger     = New-ScheduledTaskTrigger -AtLogOn
                Action      = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -File `"$serviceScriptPath`" -Action Start" -WorkingDirectory $obsExeDir
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

        $shutdownHandlerPath = Join-Path $InstallPath 'OBSShutdownHandler.ps1'
        Set-Content -Path $shutdownHandlerPath -Value $shutdownHandler -Encoding UTF8

        # Add shutdown handler to startup tasks
        $shutdownTask = @{
            Name        = 'AutoRecord-ShutdownHandler'
            Description = 'Monitor for system shutdown and stop OBS recording safely'
            Trigger     = New-ScheduledTaskTrigger -AtLogOn
            Action      = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$shutdownHandlerPath`"" -WorkingDirectory $obsExeDir
        }

        $fullTaskName = "OBS\$($shutdownTask.Name)"
        Register-ScheduledTask -TaskName $fullTaskName -Description $shutdownTask.Description -Trigger $shutdownTask.Trigger -Action $shutdownTask.Action -RunLevel Highest -Force | Out-Null

        Write-Success 'Auto-recording service installed successfully'
        Write-Info "Scheduled tasks created in 'OBS' folder:"
        Write-Info '  - AutoRecord-Start: Auto-start recording on login'
        Write-Info '  - AutoRecord-ShutdownHandler: Monitor for shutdown events'
        Write-Info 'Protection features:'
        Write-Info '  - Graceful OBS process termination (20-second timeout)'
        Write-Info '  - Auto-stop after 2 hours (background timer, no admin required)'
        Write-Info '  - Shutdown monitoring to prevent video corruption'

        return $true

    } catch {
        Write-Error "Service installation failed: $($_.Exception.Message)"
        return $false
    }
}

# Initialize logging
$script:LogToFile = $LogToFile

function Write-Header {
    param([string]$Message, [string]$Color = 'Magenta')
    Write-Host $Message -ForegroundColor $Color
    if ($script:LogToFile) { Add-Content -Path $script:LogToFile -Value $Message }
}

# Main execution
try {
    Write-Header ''
    Write-Header 'OBS Studio Infrastructure Deployment'
    Write-Header '====================================='
    Write-Header ''

    # Handle special operations first
    if ($TestDisplayParameters) {
        Test-DisplayParameters
        exit 0
    }
    if ($TestDisplayMethods) {
        Test-DisplayMethods
        exit 0
    }
    if ($ConfigurationOnly) {
        Write-Info '=== Configuration Update Mode ==='
        Write-Info "Target installation: $InstallPath"

        # Verify OBS installation exists
        if (-not (Test-Path $InstallPath)) {
            Write-Error "OBS installation not found at: $InstallPath"
            Write-Error 'Use -InstallPath parameter to specify correct location'
            exit 1
        }

        $obsExe = Join-Path $InstallPath 'bin\64bit\obs64.exe'
        if (-not (Test-Path $obsExe)) {
            Write-Error "OBS executable not found at: $obsExe"
            Write-Error 'Invalid OBS installation directory'
            exit 1
        }

        Write-Success "Found OBS installation at: $InstallPath"

        # Get system configuration for optimization
        $systemConfig = Get-SystemConfiguration -InternalDisplay:$InternalDisplay -ExternalDisplay:$ExternalDisplay -CustomDisplay:$CustomDisplay

        # Apply configuration optimization
        Write-Info '=== Updating OBS Configuration ==='
        $optimizeResult = Optimize-OBSConfiguration -SystemConfig $systemConfig

        if ($optimizeResult) {
            Write-Success 'OBS configuration updated successfully!'

            # Validate configuration if requested
            if ($ValidateConfiguration) {
                # Get the correct encoder identifier for Simple Output mode
                $expectedSimpleEncoder = switch ($systemConfig.GPU.Type) {
                    'AMD' { 'amd' }           # Simple mode: AMD hardware encoding (confirmed working)
                    'NVIDIA' { 'nvenc_h264' }    # Simple mode uses 'nvenc_h264' for NVIDIA NVENC
                    'Intel' { 'obs_qsv11' }     # Simple mode uses 'obs_qsv11' for Intel QuickSync
                    default { 'x264' }          # Fallback to software encoding
                }

                $expectedConfig = @{
                    Encoder  = $expectedSimpleEncoder  # Use Simple Output encoder identifier
                    VBitrate = $systemConfig.GPU.Bitrate
                    ABitrate = $systemConfig.GPU.AudioBitrate
                    FPS      = $systemConfig.Display.FPS
                    OutputCX = $systemConfig.Display.RecordingResolution.Width
                    OutputCY = $systemConfig.Display.RecordingResolution.Height
                    BaseCX   = $systemConfig.Display.ActualResolution.Width
                    BaseCY   = $systemConfig.Display.ActualResolution.Height
                }

                Test-OBSConfiguration -InstallPath $InstallPath -ExpectedConfig $expectedConfig
            }

            Write-Success '=== Configuration Update Complete! ==='
            Write-Info 'Updated Settings:'
            Write-Info "  - Base Resolution: $($systemConfig.Display.ActualResolution.Width)x$($systemConfig.Display.ActualResolution.Height)"
            Write-Info "  - Output Resolution: $($systemConfig.Display.RecordingResolution.Width)x$($systemConfig.Display.RecordingResolution.Height)"
            Write-Info "  - Encoder: $($systemConfig.GPU.Name)"
            Write-Info "  - Bitrate: $($systemConfig.GPU.Bitrate) kbps (dynamic calculation)"
            $audioBitrate = switch ($PerformanceMode) { '33' { 64 } '50' { 96 } '60' { 96 } '75' { 128 } '90' { 160 } default { 96 } }
            $fps = if ($PerformanceMode -eq '33') { 24 } else { 30 }
            $performanceDescription = switch ($PerformanceMode) {
                '33' { 'Extreme performance (33% scaling)' }
                '50' { 'Ultra-lightweight (50% scaling)' }
                '60' { 'Lightweight (60% scaling - default ultra)' }
                '75' { 'Optimized (75% scaling)' }
                '90' { 'Standard (90% scaling)' }
                default { 'Custom performance mode' }
            }
            Write-Info "  - Audio Bitrate: $audioBitrate kbps"
            Write-Info "  - FPS: $fps"
            Write-Info "  - Performance Mode: $performanceDescription"
        } else {
            Write-Error 'Failed to update OBS configuration'
            exit 1
        }

        if ($script:LogToFile) {
            Write-Success "Log file saved to: $script:LogToFile"
        }

        exit 0
    }

    if ($Cleanup) {
        Write-Info '=== Cleaning Up OBS Deployment ==='
        Write-Info "Cleanup target: $InstallPath"
        $cleanupItems = @()

        # Stop OBS processes and background jobs
        $obsProcesses = Get-Process -Name 'obs64' -ErrorAction SilentlyContinue
        if ($obsProcesses) {
            Write-Info 'Stopping OBS processes...'
            $obsProcesses | Stop-Process -Force
            Start-Sleep -Seconds 2
            $cleanupItems += "Stopped $($obsProcesses.Count) OBS process(es)"
        }

        # Clean up any background auto-stop jobs
        $backgroundJobs = Get-Job -ErrorAction SilentlyContinue
        if ($backgroundJobs) {
            Write-Info 'Cleaning up background jobs...'
            $backgroundJobs | Stop-Job -ErrorAction SilentlyContinue
            $backgroundJobs | Remove-Job -ErrorAction SilentlyContinue
            $cleanupItems += "Cleaned up $($backgroundJobs.Count) background job(s)"
        }

        # Remove scheduled tasks
        Write-Info 'Removing scheduled tasks...'
        $obsTaskNames = @(
            'OBS\AutoRecord-Start',
            'OBS\AutoRecord-ShutdownHandler'
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
            $rootFolder = $taskService.GetFolder('\')

            try {
                $obsFolder = $rootFolder.GetFolder('OBS')
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
                        $rootFolder.DeleteFolder('OBS', 0)
                        Write-Success '  - Removed OBS task folder'
                        $cleanupItems += "Removed OBS task folder and $removedTasks task(s)"
                    } catch {
                        Write-Warning '  - Failed to remove OBS task folder (may contain remaining tasks)'
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
            Write-Warning '  - Could not access Task Scheduler COM interface'
            if ($removedTasks -gt 0) {
                $cleanupItems += "Removed $removedTasks scheduled task(s)"
            }
        }

        # Fallback: Use schtasks command for any remaining OBS tasks
        try {
            $remainingOBSTasks = schtasks /query /fo csv 2>$null | ConvertFrom-Csv | Where-Object { $_.TaskName -like '*OBS*' -or $_.TaskName -like '*AutoRecord*' }
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
            Write-Info 'Removing OBS installation...'
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
            Write-Info '  - OBS installation not found'
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
        Write-Success ''
        Write-Success '=== Cleanup Summary ==='
        if ($cleanupItems.Count -gt 0) {
            foreach ($item in $cleanupItems) {
                Write-Info "  + $item"
            }
        } else {
            Write-Info '  No items found to clean up'
        }

        Write-Success ''
        Write-Success 'Cleanup completed successfully!'
        return
    }

    if ($TestNotifications) {
        Write-Info 'Testing balloon notifications...'
        Show-BalloonNotification -Message 'Test notification 1' -Type 'Info'
        Start-Sleep -Seconds 3
        Show-BalloonNotification -Message 'Test notification 2' -Type 'Warning'
        Write-Success 'Notification test completed'
        return
    }

    # Step 1: System configuration
    $systemConfig = Get-SystemConfiguration -InternalDisplay:$InternalDisplay -ExternalDisplay:$ExternalDisplay -CustomDisplay:$CustomDisplay

    if ($CheckOnly) {
        Write-Success ''
        Write-Success '=== Configuration Preview ==='
        Write-Info 'Planned OBS Configuration Changes:'
        Write-Info "  Base Resolution: $($systemConfig.Display.ActualResolution.Width)x$($systemConfig.Display.ActualResolution.Height)"
        Write-Info "  Output Resolution: $($systemConfig.Display.RecordingResolution.Width)x$($systemConfig.Display.RecordingResolution.Height)"
        Write-Info "  Encoder: $($systemConfig.GPU.Name)"
        Write-Info "  Bitrate: $($systemConfig.GPU.Bitrate) kbps (dynamic calculation)"
        $audioBitrate = switch ($PerformanceMode) { '33' { '64' } '50' { '96' } '60' { '96' } '75' { '128' } '90' { '160' } }
        $fps = if ($PerformanceMode -eq '33') { '24' } else { '30' }
        Write-Info "  Audio Bitrate: $audioBitrate kbps"
        Write-Info "  FPS: $fps"
        Write-Info '  Format: MKV'
        Write-Info "  Output Path: $($systemConfig.OneDrive.Path)"
        $modeDescription = switch ($PerformanceMode) {
            '33' { "Extreme Performance (33% scaling, $($systemConfig.GPU.Bitrate) kbps, ${fps}fps, ${audioBitrate}kbps audio)" }
            '50' { "Ultra-Lightweight (50% scaling, $($systemConfig.GPU.Bitrate) kbps, ${fps}fps, ${audioBitrate}kbps audio)" }
            '60' { "Lightweight (60% scaling, $($systemConfig.GPU.Bitrate) kbps, ${fps}fps, ${audioBitrate}kbps audio)" }
            '75' { "Optimized (75% scaling, $($systemConfig.GPU.Bitrate) kbps, ${fps}fps, ${audioBitrate}kbps audio)" }
            '90' { "Standard (90% scaling, $($systemConfig.GPU.Bitrate) kbps, ${fps}fps, ${audioBitrate}kbps audio)" }
        }
        Write-Info "  Performance Mode: $modeDescription"
        Write-Success 'Environment check complete - system ready'
        exit 0
    }

    # Step 2: Install OBS Studio
    $installSuccess = Install-OBSStudio -SystemConfig $systemConfig

    if (-not $installSuccess) {
        Write-Error 'OBS Studio installation failed - cannot continue with plugin installation'
        Write-Error 'Please resolve the installation issue and try again'
        exit 1
    }

    # Step 2.5: Install plugins if requested (only if OBS installation succeeded)
    $pluginInstallSuccess = $true

    # Install VCRedist if any plugins are requested
    if ($InstallInputOverlay -or $InstallOpenVINO) {
        Write-Info ''
        Write-Info '=== Installing Plugin Dependencies ==='
        $vcRedistSuccess = Install-VCRedist
        if (-not $vcRedistSuccess) {
            Write-Warning 'VCRedist installation failed - plugins may not work properly'
        }
    }

    # Install Input Overlay plugin
    if ($InstallInputOverlay) {
        Write-Info ''
        Write-Info '=== Installing Input Overlay Plugin ==='
        $inputOverlaySuccess = Install-InputOverlayPlugin -InstallPath $InstallPath
        if (-not $inputOverlaySuccess) {
            $pluginInstallSuccess = $false
        }
    }

    # Install OpenVINO plugin for Intel CPUs
    if ($InstallOpenVINO) {
        Write-Info ''
        Write-Info '=== Installing OpenVINO Plugins ==='

        # Check CPU compatibility
        $isIntelCompatible = Test-IntelCPUCompatibility
        if ($isIntelCompatible) {
            Write-Info 'Intel CPU detected and compatible with OpenVINO'
            $openvinoSuccess = Install-OpenVINOPlugin -InstallPath $InstallPath
            if (-not $openvinoSuccess) {
                $pluginInstallSuccess = $false
            }
        } else {
            Write-Warning 'CPU not compatible with OpenVINO plugins (requires Intel 6th gen or newer)'
            Write-Info 'Skipping OpenVINO installation'
        }
    }

    # Step 3: Interactive first-time setup (skip in silent mode)
    if ($SilentDeployment) {
        Write-Info '=== Skipping Interactive Setup (Silent Mode) ==='
        $firstTimeSuccess = $true
    } else {
        $firstTimeSuccess = Start-OBSFirstTime -SystemConfig $systemConfig
    }

    if ($firstTimeSuccess -or $SilentDeployment) {
        # Step 4: Configure OBS (silent or interactive)
        if ($SilentDeployment) {
            Write-Info '=== Silent Deployment Mode ==='
            Write-Info 'Creating complete OBS configuration without user interaction'

            # Create complete configuration templates
            $templateSuccess = New-OBSConfigurationTemplate -SystemConfig $systemConfig -InstallPath $InstallPath

            if ($templateSuccess) {
                Write-Success 'Silent deployment configuration created successfully'
                Write-Info '  - Auto-Configuration Wizard: BYPASSED'
                Write-Info '  - Display Capture: AUTO-CONFIGURED'
                Write-Info '  - Audio Sources: AUTO-CONFIGURED'
                Write-Info '  - FirstRun: DISABLED'

                # Apply the same scene optimization logic as ConfigurationOnly mode
                $sceneOptimizeSuccess = Optimize-OBSConfiguration -SystemConfig $systemConfig
                $optimizeSuccess = $sceneOptimizeSuccess
            } else {
                Write-Error 'Failed to create silent deployment configuration'
                $optimizeSuccess = $false
            }
        } else {
            # Interactive mode - optimize existing configuration
            $optimizeSuccess = Optimize-OBSConfiguration -SystemConfig $systemConfig
        }

        if ($optimizeSuccess) {
            # Step 5: Install scheduled tasks if requested
            if ($InstallScheduledTasks) {
                if (-not (Test-AdminRights)) {
                    # Build the current command with admin-required parameter
                    $currentParams = @()
                    if ($Force) { $currentParams += '-Force' }
                    if ($EnableNotifications) { $currentParams += '-EnableNotifications' }
                    if ($VerboseLogging) { $currentParams += '-VerboseLogging' }
                    if ($OptimizedCompression) { $currentParams += '-OptimizedCompression' }
                    if ($InternalDisplay) { $currentParams += '-InternalDisplay' }
                    if ($ExternalDisplay) { $currentParams += '-ExternalDisplay' }
                    if ($CustomDisplay) { $currentParams += "-CustomDisplay `"$CustomDisplay`"" }
                    $currentParams += '-InstallScheduledTasks'

                    $adminCommand = ".\Deploy-OBSStudio.ps1 $($currentParams -join ' ')"
                    Show-AdminCommand -CurrentCommand $adminCommand

                    Write-Info 'OBS Studio has been installed and configured successfully.'
                    Write-Info 'Run the admin command above to complete scheduled task installation.'
                    $serviceInstalled = $false
                } else {
                    $serviceInstalled = Install-AutoRecordingService -InstallPath $InstallPath -OneDrivePath $systemConfig.OneDrive.Path
                }
            } else {
                $serviceInstalled = $false
            }

            # Step 6: Show completion
            Show-BalloonNotification -Message 'OBS deployment completed successfully!' -Type 'Info'

            Write-Success ''
            Write-Success '=== Deployment Complete! ==='
            Write-Info 'OBS Studio is ready for recording'
            Write-Info "Hardware: $($systemConfig.GPU.Name)"
            Write-Info "Output: $($systemConfig.OneDrive.Path)"

            # Show plugin installation status
            if ($InstallInputOverlay -or $InstallOpenVINO) {
                Write-Info ''
                Write-Info 'Installed Plugins:'
                if ($InstallInputOverlay) {
                    Write-Info '  + Input Overlay: Keyboard/mouse/gamepad visualization'
                    Write-Info "    Presets: $InstallPath\data\input-overlay-presets\"
                    Write-Info ''
                    Write-Info '  Setup Custom Input History:'
                    Write-Info '    1. Tools > input-overlay-settings > WebSocket Server > Enable checkbox'
                    Write-Info '    2. Add Browser Source > Local File > Browse to:'
                    Write-Info "       $InstallPath\data\input-overlay-presets\input-history-windows\custom-input-history.html"
                    Write-Info '    3. Set Width: 280, Height: 400'
                }
                if ($InstallOpenVINO) {
                    Write-Info '  + OpenVINO: AI-powered webcam effects (Intel hardware)'
                    Write-Info '    Filters: Background Concealment, Face Mesh, Smart Framing'
                    Write-Info ''
                    Write-Info '  Setup Transparent Background Webcam:'
                    Write-Info '    1. Add Source > Video Capture Device > Choose camera > OK'
                    Write-Info '    2. Right-click Video Capture Device > Filters'
                    Write-Info '    3. Audio/Video Filters > + > OpenVINO Background Concealment'
                    Write-Info "    4. Uncheck 'Background Blur', adjust 'Smooth silhouette' and 'Segmentation Mask Threshold'"
                    Write-Info '    5. Effect Filters > + > Chroma Key > Close'
                }
            }

            $modeMessage = switch ($PerformanceMode) {
                '33' { 'Extreme performance mode: Severe encoder overload prevention enabled' }
                '50' { 'Ultra-lightweight mode: Maximum performance enabled' }
                '60' { 'Lightweight mode: Enhanced performance enabled (default ultra)' }
                '75' { 'Optimized mode: Encoder overflow prevention enabled' }
                '90' { 'Standard mode: Balanced quality and performance' }
            }
            Write-Success $modeMessage

            # Step 7: Validate configuration if requested
            if ($ValidateConfiguration) {
                # Get the correct encoder identifier for Simple Output mode
                $expectedSimpleEncoder = switch ($systemConfig.GPU.Type) {
                    'AMD' { 'amd' }           # Simple mode uses 'amd' for AMD AMF
                    'NVIDIA' { 'nvenc_h264' }    # Simple mode uses 'nvenc_h264' for NVIDIA NVENC
                    'Intel' { 'obs_qsv11' }     # Simple mode uses 'obs_qsv11' for Intel QuickSync
                    default { 'x264' }          # Fallback to software encoding
                }

                $expectedConfig = @{
                    BaseCX   = $systemConfig.Display.ActualResolution.Width
                    BaseCY   = $systemConfig.Display.ActualResolution.Height
                    OutputCX = $systemConfig.Display.RecordingResolution.Width
                    OutputCY = $systemConfig.Display.RecordingResolution.Height
                    VBitrate = $systemConfig.GPU.Bitrate
                    ABitrate = switch ($PerformanceMode) { '33' { 64 } '50' { 96 } '60' { 96 } '75' { 128 } '90' { 160 } }
                    Encoder  = $expectedSimpleEncoder  # Use Simple Output encoder identifier
                    FPS      = if ($PerformanceMode -eq '33') { 24 } else { 30 }
                }

                Test-OBSConfiguration -InstallPath $InstallPath -ExpectedConfig $expectedConfig
            }
        }
    }

    # Completion message with log file path
    Write-Success ''
    Write-Success '=== Deployment Completed Successfully! ==='
    Write-Info "Log file saved to: $script:LogToFile"

    # Pause if elevated session for review
    if ($script:IsElevatedSession) {
        Write-Host ''
        Write-Host 'Press Enter to close this elevated window...' -ForegroundColor Yellow
        $null = Read-Host
    }

    exit 0

} catch {
    Write-Error "Deployment failed: $($_.Exception.Message)"
    Write-Info "Log file saved to: $script:LogToFile"
    exit 1
}
