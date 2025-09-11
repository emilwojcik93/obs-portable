# OBS Studio Infrastructure as Code v{{VERSION}}

## Complete Enterprise-Ready Deployment Solution

### TLDR - Perfect One Command Setup

```powershell
# Complete zero-touch enterprise setup (run in Terminal as Admin)
&([ScriptBlock]::Create((irm https://github.com/emilwojcik93/obs-portable/releases/latest/download/Deploy-OBSStudio.ps1))) -VerboseLogging -Force -InternalDisplay -PerformanceMode 50 -SilentDeployment -InstallAutoRecording -CreateDesktopShortcuts
```

### What This Command Does

- Downloads and installs OBS Studio portable (latest version)
- Installs Input Overlay + OpenVINO plugins automatically (default behavior)
- Detects hardware and configures optimal settings (50% scaling)
- Silent deployment - no user interaction required
- Installs auto-recording service with notifications
- Creates desktop shortcuts with balloon notifications
- Enables WebSocket API for graceful recording control
- Prevents Safe Mode prompts with --disable-shutdown-check
- Uses native resolution for recording (handles Windows scaling)
- Complete zero-touch enterprise setup in ~3 minutes

### Key Features

- **Zero-Configuration Display Capture** with auto-setup
- **Default Plugin Installation** (Input Overlay + OpenVINO on Intel)
- **Template-Based Script System** for maintainability
- **WebSocket API** enabled by default (optional for restricted networks)
- **Desktop Shortcuts** with balloon notifications
- **Safe Mode Prevention** with --disable-shutdown-check
- **Enterprise Auto-Recording** service with protection
- **Complete Process Cleanup** and graceful shutdown
- **5-Tier Performance System** (33%, 50%, 60%, 75%, 90%)
- **Microsoft Cloud Integration** (OneDrive/SharePoint)

### Recent Improvements

{{RECENT_COMMITS}}

### For Restricted Networks

```powershell
# Enterprise setup without WebSocket (for restricted networks)
&([ScriptBlock]::Create((irm https://github.com/emilwojcik93/obs-portable/releases/latest/download/Deploy-OBSStudio.ps1))) -Force -SilentDeployment -InstallAutoRecording -CreateDesktopShortcuts -DisableWebSocket
```

### Plugin Control

```powershell
# Skip plugins if not needed
&([ScriptBlock]::Create((irm https://github.com/emilwojcik93/obs-portable/releases/latest/download/Deploy-OBSStudio.ps1))) -Force -SilentDeployment -SkipInputOverlay -SkipOpenVINO
```

Perfect for enterprise deployment with zero user interaction required!
