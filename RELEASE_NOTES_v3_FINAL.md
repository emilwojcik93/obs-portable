# OBS Studio Infrastructure as Code v3.0

## Complete Enterprise-Ready Deployment Solution

### TLDR - Perfect One Command Setup

```powershell
# Complete zero-touch enterprise setup (run in Terminal as Admin)
&([ScriptBlock]::Create((irm https://github.com/emilwojcik93/obs-portable/releases/latest/download/Deploy-OBSStudio.ps1))) -VerboseLogging -Force -InternalDisplay -PerformanceMode 50 -SilentDeployment -InstallAutoRecording -CreateDesktopShortcuts
```

### What This Command Does

- **Downloads and installs** OBS Studio portable (latest version)
- **Installs plugins automatically** (Input Overlay + OpenVINO on Intel hardware)
- **Detects hardware** and configures optimal settings (50% scaling)
- **Silent deployment** - no user interaction required
- **Auto-recording service** with notifications and protection
- **Desktop shortcuts** with balloon notifications for start/stop
- **WebSocket API** enabled for graceful recording control
- **Prevents Safe Mode** prompts with --disable-shutdown-check
- **Native resolution** detection (handles Windows scaling)
- **Complete setup** in ~3 minutes with zero user interaction

### Major Improvements in v3.0

#### 🐛 **Fixed Critical Issues**
- **Safe Mode Popup**: Added --disable-shutdown-check to all OBS launches
- **Function Order**: Fixed Get-ScriptTemplate declaration order for remote execution
- **Process Cleanup**: Complete OBS termination prevents background processes
- **Template System**: All scripts externalized to template files

#### 🚀 **Enhanced User Experience**
- **Default Plugin Installation**: Input Overlay and OpenVINO install automatically
- **Desktop Integration**: Shortcuts with balloon notifications
- **System Tray**: OBS minimizes to tray by default
- **Fast Shutdown**: Optimized stop shortcut (3-5 seconds)

#### 🏗️ **Enterprise Features**
- **Template-Based Architecture**: Maintainable and version-controlled
- **Dynamic Versioning**: Automatic version management in CI/CD
- **WebSocket Support**: Enabled by default with restricted network support
- **Parameter Consolidation**: Simplified deployment commands

### Key Features

- **Zero-Configuration Display Capture** with automatic setup
- **5-Tier Performance System** (33%, 50%, 60%, 75%, 90% scaling)
- **Advanced Hardware Detection** (NVENC → QuickSync → AMF → x264)
- **Microsoft Cloud Integration** (OneDrive/SharePoint optimized)
- **Enterprise Protection** (graceful shutdown, auto-stop timer)
- **Template System** for all scripts and configurations
- **WebSocket API** for graceful recording control
- **Desktop Shortcuts** with professional notifications

### For Restricted Networks

```powershell
# Enterprise setup without WebSocket (for restricted corporate networks)
&([ScriptBlock]::Create((irm https://github.com/emilwojcik93/obs-portable/releases/latest/download/Deploy-OBSStudio.ps1))) -Force -SilentDeployment -InstallAutoRecording -CreateDesktopShortcuts -DisableWebSocket
```

### Plugin Control

```powershell
# Skip plugins if not needed (minimal installation)
&([ScriptBlock]::Create((irm https://github.com/emilwojcik93/obs-portable/releases/latest/download/Deploy-OBSStudio.ps1))) -Force -SilentDeployment -SkipInputOverlay -SkipOpenVINO
```

### Encoder Overload Prevention

```powershell
# For severe encoder overload (33% scaling)
&([ScriptBlock]::Create((irm https://github.com/emilwojcik93/obs-portable/releases/latest/download/Deploy-OBSStudio.ps1))) -Force -PerformanceMode 33 -SilentDeployment
```

## Perfect for Enterprise Deployment

This Infrastructure as Code solution provides complete OBS Studio automation with:
- **Zero user interaction** required
- **Professional out-of-box** experience
- **Enterprise-grade** protection and monitoring
- **Template-based** maintainable architecture
- **Dynamic versioning** and CI/CD integration

Ready for immediate deployment in any enterprise environment! 🚀
