# 🚀 OBS Studio Infrastructure as Code (IaC) Deployment

## Overview

This repository provides a comprehensive Infrastructure as Code solution for OBS Studio portable deployment with advanced automation, hardware optimization, and Microsoft cloud integration. The solution addresses real-world challenges in automated recording setup, video corruption prevention, and enterprise deployment scenarios.

## ✨ Core Features

### 🎯 **Complete Automation**
- ✅ **One-Script Deployment**: Single command deploys entire OBS infrastructure
- ✅ **Performance Optimization**: Unified `-PerformanceMode` parameter (33%, 50%, 60%, 75%, 90% scaling)
- ✅ **Hardware Intelligence**: Advanced GPU and display detection with real monitor names
- ✅ **SharePoint/OneDrive Optimization**: Microsoft cloud-ready settings and paths
- ✅ **Windows Integration**: Scheduled tasks, notifications, and shutdown protection
- ✅ **Interactive Setup**: Respects OBS wizard while providing post-configuration optimization

### 🔧 **Hardware Optimization**
- ✅ **GPU Detection Priority**: NVENC (NVIDIA) → QuickSync (Intel) → AMF (AMD) → x264 (Software)
- ✅ **Resolution Intelligence**: WMI-based accurate display detection (fixes common 1280x800 vs 1920x1200 issues)
- ✅ **Multi-Display Support**: Internal screen preference for laptops
- ✅ **Performance Tuning**: Hardware-specific bitrate and quality settings
- ✅ **Encoder Overflow Protection**: `-OptimizedCompression` for lower-end hardware

### 🛡️ **Video Corruption Prevention**
- ✅ **20-Second Graceful Shutdown**: Handles large/high-quality video files properly
- ✅ **2-Hour Auto-Stop Timer**: Prevents storage overflow using PowerShell background jobs
- ✅ **Power Event Monitoring**: Sleep/hibernate detection with safe recording stop
- ✅ **System Event Detection**: Shutdown/restart protection via scheduled tasks
- ✅ **Working Directory Handling**: OBS launched from correct `bin\64bit` directory to resolve dependencies

### ☁️ **Microsoft Cloud Integration**
- ✅ **OneDrive Auto-Detection**: Corporate and personal OneDrive support
- ✅ **SharePoint/Stream Optimized**: MKV format, optimal compression settings
- ✅ **Cloud-Friendly Settings**: Balanced quality and file size for upload efficiency
- ✅ **Auto-Sync Output**: Recordings saved to OneDrive for automatic synchronization

## 🚀 Quick Start

### **⚡ TLDR - One Command Setup**
```powershell
# Remote execution - Complete setup with all features (run in Terminal as Admin)
powershell.exe -ExecutionPolicy Bypass -Command "&([ScriptBlock]::Create((irm https://github.com/emilwojcik93/obs-studio-iac/releases/latest/download/Deploy-OBSStudio.ps1))) -VerboseLogging -Force -EnableNotifications -InstallScheduledTasks -PrimaryDisplay"

# What this does:
# ✅ Downloads and installs OBS Studio portable (latest version)
# ✅ Detects your hardware (GPU, display, OneDrive) with verbose output
# ✅ Configures optimal settings (60% scaling, 3000 kbps Intel QuickSync)
# ✅ Installs scheduled tasks for auto-recording on login
# ✅ Shows balloon notifications for recording status
# ✅ Uses primary display automatically
# ✅ Complete enterprise setup in ~3 minutes
```

### **🔴 Encoder Overload Prevention**
```powershell
# For severe encoder overload (33% scaling) - run in Terminal as Admin
powershell.exe -ExecutionPolicy Bypass -Command "&([ScriptBlock]::Create((irm https://github.com/emilwojcik93/obs-studio-iac/releases/latest/download/Deploy-OBSStudio.ps1))) -VerboseLogging -Force -EnableNotifications -InstallScheduledTasks -PrimaryDisplay -PerformanceMode 33"
```

### **📋 Local Installation**
```powershell
# Download script locally first, then run
Invoke-WebRequest -Uri "https://github.com/emilwojcik93/obs-studio-iac/releases/latest/download/Deploy-OBSStudio.ps1" -OutFile "Deploy-OBSStudio.ps1"
.\Deploy-OBSStudio.ps1 -Force -EnableNotifications
```

### **Performance-Optimized Deployment**
```powershell
# Default lightweight deployment (60% scaling - optimal for most systems)
.\Deploy-OBSStudio.ps1 -Force -EnableNotifications

# Encoder overload prevention (choose based on hardware capability)
.\Deploy-OBSStudio.ps1 -Force -PerformanceMode 50   # Ultra-lightweight (50% scaling)
.\Deploy-OBSStudio.ps1 -Force -PerformanceMode 33   # Extreme performance (33% scaling)

# Quality-focused deployment (modern hardware)
.\Deploy-OBSStudio.ps1 -Force -PerformanceMode 90   # Standard quality (90% scaling)
.\Deploy-OBSStudio.ps1 -Force -PerformanceMode 75   # Optimized (75% scaling)

# Test notifications
.\Deploy-OBSStudio.ps1 -TestNotifications
```

### **Environment Check**
```powershell
# Validate hardware and environment without making changes
.\Deploy-OBSStudio.ps1 -CheckOnly -VerboseLogging

# Preview deployment actions (dry-run)
.\Deploy-OBSStudio.ps1 -WhatIf -InstallScheduledTasks -EnableNotifications
```

## 📊 Hardware Detection Results

### **Example System Configuration:**
```
🖥️ Hardware Analysis:
├── 💻 System: Laptop - Intel(R) Core(TM) Ultra 5 135U
├── 🧠 Memory: 15.46GB RAM
├── 🎮 GPU: Intel(R) Graphics (QuickSync H.264 available)
├── 📺 Display: 1920x1200 (WMI-detected actual resolution)
├── 📹 Recording: 1728x1080 @ 30fps (90% scaling for performance)
└── ☁️ OneDrive: Corporate OneDrive detected

🎬 Optimal Configuration:
├── 🎮 Encoder: Intel QuickSync H.264 (hardware accelerated)
├── 💾 Bitrate: 10,000 kbps (QuickSync optimized)
├── 📁 Format: MKV (SharePoint/Stream compatible)
├── ☁️ Output: OneDrive\Recordings (auto-sync)
└── 🔧 Service: Auto-recording on login (optional)
```

## 📋 Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InstallPath` | String | `$env:USERPROFILE\OBS-Studio-Portable` | OBS installation directory |
| `VerboseLogging` | Switch | `$false` | Enable detailed logging output |
| `CheckOnly` | Switch | `$false` | Environment validation only (no changes) |
| `Force` | Switch | `$false` | Force reinstallation over existing |
| `InstallScheduledTasks` | Switch | `$false` | Install scheduled tasks for auto-recording (requires admin) |
| `EnableNotifications` | Switch | `$false` | Enable balloon notifications |
| `Cleanup` | Switch | `$false` | Remove existing installation and tasks |
| `PerformanceMode` | String | `"60"` | Performance optimization: 33, 50, 60, 75, 90 (% of display resolution) |
| `TestNotifications` | Switch | `$false` | Test balloon notifications (shows demo) |
| `PrimaryDisplay` | Switch | `$false` | Use primary/main display for recording |
| `InternalDisplay` | Switch | `$false` | Use internal display for recording (requires dual display setup) |
| `ExternalDisplay` | Switch | `$false` | Use external display for recording (requires dual display setup) |
| `CustomDisplay` | String | `""` | Use custom resolution for recording (format: 1920x1080) |

## 🎬 First-Time Setup Process

### **Interactive Setup Flow:**
1. **Hardware Detection** → Analyzes GPU, display resolution, and OneDrive configuration
2. **Display Selection** → Interactive display selection (if no display parameters provided)
3. **OBS Installation** → Downloads latest version from GitHub API
4. **Interactive First-Time Setup** → Launches OBS for user to complete wizard
5. **User Completes Setup** → User completes wizard, adds sources, then closes OBS
6. **Configuration Optimization** → Script optimizes existing configuration files
7. **Service Installation** → Sets up scheduled tasks for auto-recording (optional)
8. **Completion** → OBS ready for recording with optimized settings

### **⚠️ Important: First-Time Launch**
After installation, the script automatically launches OBS Studio. **This is required** for proper configuration:

#### **Interactive Setup Steps:**
1. **Script launches OBS** → You'll see the Auto-Configuration Wizard
2. **Complete the wizard**:
   - Choose "Optimize just for recording, I will not be streaming"
   - Let OBS run its configuration test
   - Accept the recommended settings
3. **Add Display Capture source**:
   - Click '+' in Sources panel
   - Add 'Display Capture'
   - Select your main display
   - Click OK
4. **Close OBS Studio** → Script continues automatically
5. **Script optimizes configuration** → Applies hardware-specific settings

This interactive approach ensures OBS creates proper configuration files, then the script optimizes them for your hardware and SharePoint/OneDrive use. **This step is mandatory** - OBS must be launched interactively at least once to complete its internal setup.

## 🖥️ Display Selection

### **Automatic Single Display Selection**
When only one display is detected, the script automatically uses it without prompting and shows detailed monitor information:

```
=== System Configuration Analysis ===
Single display detected: PHL 499P9 (1920x1080) - Philips
Display Resolution: 1920x1080 (Single Display - PHL 499P9)
Native Hardware Resolution: 5120x1440
```

### **Interactive Multi-Display Selection**
When multiple displays are detected and no display parameters are provided, the script will prompt you to choose:

```
=== Display Selection ===
Detected 2 display(s):

1. PHL 499P9 (Primary)
   Resolution: 1920x1080
   Position: (0, 0), Size: 119x34cm
   Manufacturer: Philips (PHL)
   Serial: AU02145001047, Device: \\.\DISPLAY1

2. Samsung Odyssey G9
   Resolution: 5120x1440
   Position: (1920, 0), Size: 120x34cm
   Manufacturer: Samsung (SAM)
   Serial: H4ZR123456, Device: \\.\DISPLAY2

Select display for recording (1-2):
```

### **Parameter-Based Display Selection**

#### **Dual Display Setup:**
```powershell
# Use internal display (usually primary for laptops)
.\Deploy-OBSStudio.ps1 -InternalDisplay -Force

# Use external display (usually secondary)
.\Deploy-OBSStudio.ps1 -ExternalDisplay -Force
```

#### **Custom Resolution:**
```powershell
# Specify exact resolution (must match detected display)
.\Deploy-OBSStudio.ps1 -CustomDisplay "1920x1080" -Force

# Error handling - invalid resolution
.\Deploy-OBSStudio.ps1 -CustomDisplay "1600x900" -Force
# Error: Custom resolution 1600x900 does not match any detected display resolution. 
# Available resolutions: 1920x1080, 5120x1440
```

### **Admin Rights Handling**
When `-InstallScheduledTasks` is requested but admin rights are not available:

```
⚠️ Administrator rights are required for scheduled task installation.

Please run the following command from an elevated PowerShell window:
.\Deploy-OBSStudio.ps1 -Force -EnableNotifications -InstallScheduledTasks

To open elevated PowerShell:
1. Press Win+X
2. Select 'Windows PowerShell (Admin)' or 'Terminal (Admin)'
3. Navigate to: C:\Users\YourName\obs_studio-portable
4. Run the command above
```

## 🔍 Advanced Monitor Detection

### **Enhanced Hardware Recognition**
The script uses advanced WMI queries based on the proven [Get-Monitor.ps1 methodology](https://raw.githubusercontent.com/MaxAnderson95/Get-Monitor-Information/refs/heads/master/Get-Monitor.ps1) to provide detailed monitor information:

- ✅ **Comprehensive Manufacturer Database**: 50+ manufacturer codes (PHL→Philips, SAM→Samsung, DEL→Dell, etc.)
- ✅ **Real Hardware Names**: Shows "PHL 499P9" instead of generic "Primary Display"
- ✅ **Detailed Information**: Model, serial number, physical dimensions, and position data
- ✅ **Multiple Fallback Methods**: Ensures compatibility across different Windows versions

### **Detection Results Example:**
```
System: Laptop - Intel(R) Core(TM) Ultra 5 135U
Single display detected: PHL 499P9 (1920x1080) - Philips
Display Resolution: 1920x1080 (Single Display - PHL 499P9)
Native Hardware Resolution: 5120x1440
```

This shows:
- **Current Resolution**: 1920x1080 (what you're actually using with scaling)
- **Native Resolution**: 5120x1440 (monitor's maximum capability)
- **Real Monitor Name**: PHL 499P9 (Philips model)
- **Manufacturer**: Philips (friendly name from PHL code)

## 🛡️ Protection System

### **Video Corruption Prevention:**
```
Protection Timeline:
├── 0 min: Recording starts automatically on login
├── 120 min: Auto-stop protection activates (2-hour limit via background job)
├── Any time: Sleep/hibernate detection stops recording safely
├── Shutdown: 20-second graceful closure for large files
└── Fallback: Force termination if graceful shutdown fails
```

### **Task Scheduler Organization:**
```
Task Scheduler > OBS\
├── AutoRecord-Start (login → start recording)
├── AutoRecord-ShutdownHandler (monitors system events)
└── Service Scripts: OBSAutoRecord.ps1, OBSShutdownHandler.ps1
```

### **Critical Working Directory Handling:**
OBS Studio **must** be launched from the `bin\64bit` directory to resolve dependencies properly:
```powershell
# Correct approach (implemented in service):
Push-Location "${OBSPath}\bin\64bit"
Start-Process -FilePath ".\obs64.exe" -ArgumentList @("--portable", "--startrecording")
Pop-Location
```

## 🔔 Notification System

### **Balloon Notifications:**
When enabled with `-EnableNotifications`, you'll receive non-interactive balloon notifications:

- 🔵 **Recording Started**: "Recording started with hardware encoding"
- 🔵 **Recording Stopped**: "Recording stopped safely - [Reason]"
- 🟡 **Auto-Stop Protection**: "Recording stopped after 2 hours (auto-protection)"
- 🔵 **OBS Launched**: "OBS Studio launched and ready for recording!"

### **Implementation Methods:**
- **Primary**: Windows Forms NotifyIcon with balloon tips
- **Fallback**: WScript popup notifications
- **Non-Interactive**: No user input required, auto-dispose after 5 seconds

## 🔧 Hardware Encoding Support

### **GPU Encoding Priority:**
| GPU Type | Encoder | Bitrate | Performance | Quality |
|----------|---------|---------|-------------|---------|
| **NVIDIA** (RTX/GTX) | NVENC H.264 | 12,000 kbps | Excellent | Best |
| **Intel** (UHD/Arc) | QuickSync H.264 | 10,000 kbps | Excellent | Very Good |
| **AMD** (Radeon/RX) | AMF H.264 | 10,000 kbps | Excellent | Very Good |
| **Software** (CPU) | x264 | 8,000 kbps | Good | Excellent |

### **Display Configuration:**
- **Laptop Multi-Display**: Internal screen preferred (primary display)
- **Resolution Detection**: Uses WMI for accurate hardware resolution (fixes common detection issues)
- **Recording Optimization**: 90% scaling for performance and cloud upload efficiency
- **SharePoint/Stream Ready**: Optimal resolution and compression settings

## 🏗️ Infrastructure Components

### **1. OBS Studio Portable**
- Latest version automatically downloaded from GitHub API
- Portable mode enabled with `portable_mode.txt`
- Hardware-optimized configuration applied post-wizard
- Working directory properly configured for dependency resolution

### **2. Configuration Management**
- **Profile**: "Untitled" (OBS standard, avoids custom profile loading issues)
- **Scene Collection**: "Untitled" with Display Capture source
- **Hardware-aware encoder selection** based on detected GPU
- **SharePoint/OneDrive optimized settings** for cloud compatibility

### **3. Windows Integration**
- **Scheduled tasks** in dedicated "OBS" folder for organization
- **Toast notifications** for recording status updates
- **OneDrive integration** with automatic path detection
- **Proper shutdown handling** with graceful timeouts

### **4. Protection & Monitoring**
- **20-second graceful shutdown timeout** for large file closure
- **2-hour recording limit protection** via PowerShell background jobs
- **Power management event monitoring** for sleep/hibernate events
- **Comprehensive logging system** with timestamps and error tracking

## 🧪 Usage Examples

### **Complete Enterprise Deployment:**
```powershell
# Full infrastructure with scheduled tasks and notifications
.\Deploy-OBSStudio.ps1 -Force -InstallScheduledTasks -EnableNotifications -VerboseLogging
```

### **Developer/Content Creator Setup:**
```powershell
# Basic setup with notifications (no admin required)
.\Deploy-OBSStudio.ps1 -Force -EnableNotifications -VerboseLogging
```

### **Environment Validation:**
```powershell
# Check hardware compatibility and dependencies
.\Deploy-OBSStudio.ps1 -CheckOnly -VerboseLogging
```

### **Display Selection Examples:**
```powershell
# Automatic single display (no prompting)
.\Deploy-OBSStudio.ps1 -CheckOnly
# Output: Single display detected: Primary Display (1920x1080)

# Use primary/main display (works with single or dual displays)
.\Deploy-OBSStudio.ps1 -PrimaryDisplay -Force

# Use internal display for laptops with dual monitors
.\Deploy-OBSStudio.ps1 -InternalDisplay -Force

# Use external display for laptops with dual monitors  
.\Deploy-OBSStudio.ps1 -ExternalDisplay -Force

# Force specific resolution (must match detected display)
.\Deploy-OBSStudio.ps1 -CustomDisplay "1920x1080" -Force

# Invalid resolution handling
.\Deploy-OBSStudio.ps1 -CustomDisplay "1600x900" -CheckOnly
# Error: Custom resolution 1600x900 does not match any detected display resolution.
# Available resolutions: 1920x1080
```

### **Clean Deployment:**
```powershell
# Remove existing installation and redeploy
.\Deploy-OBSStudio.ps1 -Cleanup
.\Deploy-OBSStudio.ps1 -Force -InstallScheduledTasks -EnableNotifications
```

### **Dry-Run Preview:**
```powershell
# See what would be deployed without making changes
.\Deploy-OBSStudio.ps1 -WhatIf -InstallScheduledTasks -EnableNotifications
```

## 🎯 SharePoint/Stream Optimization

### **Standard Recording Settings:**
- **Format**: MKV (best web compatibility)
- **Resolution**: Hardware-detected with 90% scaling (e.g., 1920x1200 → 1728x1080)
- **Bitrate**: GPU-optimized (10,000 kbps for QuickSync)
- **Audio**: 48kHz Stereo, 160kbps AAC
- **FPS**: 30fps (smooth, cloud-friendly)
- **Output**: OneDrive\Recordings (automatic sync)

### **Encoder Overflow Prevention:**
If you experience encoder overflow warnings, use the `-OptimizedCompression` parameter:

## 🎛️ Performance Mode Configuration

### **Unified Performance Parameter**
The script uses a single `-PerformanceMode` parameter with intuitive scaling percentages:

| Mode | Scaling | Resolution Example | Bitrate | Audio | FPS | Use Case |
|------|---------|-------------------|---------|-------|-----|----------|
| **33** | 33% | 1920x1200 → 634x396 | 1,500 kbps | 64 kbps | 24fps | **Extreme encoder overload** |
| **50** | 50% | 1920x1200 → 960x600 | 2,500 kbps | 96 kbps | 30fps | **Severe encoder overload** |
| **60** | 60% | 1920x1200 → 1152x720 | 3,000 kbps | 96 kbps | 30fps | **Default (optimal for most)** |
| **75** | 75% | 1920x1200 → 1440x900 | 6,000 kbps | 128 kbps | 30fps | **Lower-end hardware** |
| **90** | 90% | 1920x1200 → 1728x1080 | 10,000 kbps | 160 kbps | 30fps | **Modern hardware** |

### **Usage Examples:**
```powershell
# Default deployment (60% scaling - good for most systems)
.\Deploy-OBSStudio.ps1 -Force

# Encoder overload prevention
.\Deploy-OBSStudio.ps1 -Force -PerformanceMode 50   # Ultra-lightweight
.\Deploy-OBSStudio.ps1 -Force -PerformanceMode 33   # Extreme performance

# Quality-focused (modern hardware)
.\Deploy-OBSStudio.ps1 -Force -PerformanceMode 90   # Standard quality
```

### **When to Use Each Performance Mode:**

**🔴 Mode 33 (Extreme Performance):**
- **Critical Encoder Overload**: Persistent warnings despite all optimizations
- **Very Old Hardware**: Ancient integrated graphics or severely constrained systems
- **Emergency Recording**: When any recording is better than no recording
- **Minimal File Sizes**: Critical storage or network limitations

**🟠 Mode 50 (Ultra-Lightweight):**
- **Severe Encoder Overload**: Hardware struggling with higher resolutions
- **Low-End Hardware**: Older integrated graphics or budget systems
- **Battery Conservation**: Extended mobile recording sessions
- **Performance Priority**: Speed over quality requirements

**🟡 Mode 60 (Default Lightweight):**
- **Balanced Performance**: Good quality with encoder overload prevention
- **Most Systems**: Optimal default for majority of hardware configurations
- **Moderate Hardware**: Modern integrated graphics or entry-level dedicated GPUs

**🟢 Mode 75 (Optimized):**
- **Quality Focus**: Better quality with some performance optimization
- **Decent Hardware**: Mid-range systems with adequate GPU performance
- **Balanced Approach**: Good compromise between quality and performance

**🔵 Mode 90 (Standard):**
- **High Quality**: Maximum quality with minimal performance optimization
- **Modern Hardware**: Dedicated GPUs with excellent performance
- **Quality Priority**: When system resources are abundant

## 🔄 Maintenance

### **Update OBS:**
```powershell
# Download and install latest version
.\Deploy-OBSStudio.ps1 -Force
```

### **Reinstall Service:**
  ```powershell
# Reinstall scheduled tasks and service scripts
.\Deploy-OBSStudio.ps1 -Force -InstallScheduledTasks
```

### **Complete Cleanup:**
```powershell
# Remove all components (installation, tasks, scripts)
.\Deploy-OBSStudio.ps1 -Cleanup
```

## ⚠️ Known Issues and Limitations

### **Dependencies:**
- **PowerShell 5.0+**: Required for advanced features and cmdlets
- **Windows 10/11**: Required for modern notification system
- **Internet Connection**: Required for GitHub API and OBS download
- **Admin Rights**: Required only for `-InstallScheduledTasks` parameter

### **Limitations:**
- **First-Time Interactive Setup**: OBS wizard must be completed manually once
- **Working Directory Critical**: OBS must launch from `bin\64bit` for proper operation
- **GPU Detection**: May not detect all GPU types, falls back to software encoding
- **OneDrive Detection**: Corporate OneDrive paths may vary by organization

### **Common Issues:**
1. **OBS Won't Start from Scheduled Task**: 
   - **Cause**: Incorrect working directory
   - **Solution**: Script now uses `Push-Location` to `bin\64bit` directory

2. **Encoder Overflow Warnings**:
   - **Cause**: Hardware insufficient for selected settings
   - **Solution**: Use `-OptimizedCompression` parameter

3. **Configuration Wizard Still Appears**:
   - **Cause**: OBS requires interactive first-time setup
   - **Solution**: Complete wizard manually, script optimizes afterward

4. **Scheduled Tasks Not Working**:
   - **Cause**: Service scripts need correct OBS working directory
   - **Solution**: Updated service implementation with proper path handling

## 📝 Development Notes

### **Architecture Decisions:**
- **Interactive First-Time Setup**: Respects OBS's internal configuration mechanisms
- **Background Jobs vs Scheduled Tasks**: Uses background jobs for auto-stop to avoid permission issues
- **Working Directory Handling**: Critical for OBS dependency resolution
- **Notification System**: Non-interactive design for automated environments

### **Code Quality Standards:**
- **ASCII/UTF-8 Only**: No Unicode characters in PowerShell code
- **Variable Bracketing**: `${var}%` instead of `$var%` for special characters
- **Error Handling**: Comprehensive try-catch blocks with logging
- **IaC Principles**: Idempotent, declarative, version-controlled

## 🎬 Ready for Production

This IaC solution provides enterprise-grade OBS Studio automation with:
- **Zero-touch deployment** for consistent configurations across organizations
- **Hardware-aware optimization** for best performance on diverse hardware
- **Microsoft cloud integration** for seamless SharePoint/Stream workflow
- **Comprehensive protection** against video corruption and system events
- **Professional notification system** for user awareness without interaction

Perfect for enterprise deployment, content creation workflows, and automated recording infrastructure! 🎉

## ⚡ Advanced Media Framework (AMF) Optimizations

### **Enhanced Encoder Performance**
Based on the [AMF Options documentation](https://raw.githubusercontent.com/Matishzz/OBS-Studio/refs/heads/main/AMF%20Options.md), the script implements advanced encoding optimizations to prevent encoder overload:

#### **Performance Comparison:**

| Mode | Resolution Scaling | Bitrate | Audio | Use Case |
|------|-------------------|---------|-------|----------|
| **Standard** (`-PerformanceMode 90`) | 90% (1728x1080) | 10,000 kbps | 160 kbps | Modern hardware |
| **Optimized** (`-PerformanceMode 75`) | 75% (1440x900) | 6,000 kbps | 128 kbps | Lower-end hardware |
| **Lightweight** (`-PerformanceMode 60`) | 60% (1152x720) | 3,000 kbps | 96 kbps | **Default ultra performance** |
| **Ultra-Lightweight** (`-PerformanceMode 50`) | 50% (960x600) | 2,500 kbps | 96 kbps | Severe encoder overload |
| **Extreme Performance** (`-PerformanceMode 33`) | 33% (634x396) | 1,500 kbps | 64 kbps | Critical encoder overload |

#### **Encoder-Specific Optimizations:**

**🟢 NVIDIA NVENC (Ultra-Lightweight):**
- **P1 Preset**: Fastest encoding preset
- **Ultra-Low Latency**: Minimizes encoding delay  
- **Multipass**: Disabled for maximum performance

**🔵 Intel QuickSync (Ultra-Lightweight):**
- **Speed Preset**: Maximum performance priority
- **Target Usage 1**: Fastest encoding mode
- **Reduced Bitrate**: 3,000 kbps for minimal load

**🔴 AMD AMF (Ultra-Lightweight):**
- **Pre-Analysis**: Enabled for intelligent content optimization
- **B-Frames**: Disabled (0) for maximum performance
- **HRD Enforcement**: Disabled to reduce overhead
- **VBAQ**: Disabled for speed priority
- **Reduced Bitrate**: 3,500 kbps optimized for AMF

### **Usage Examples:**
```powershell
# Ultra-lightweight for severe encoder overload
.\Deploy-OBSStudio.ps1 -UltraLightweight -Force

# Ultra-lightweight with specific display
.\Deploy-OBSStudio.ps1 -UltraLightweight -InternalDisplay -Force

# Check ultra-lightweight settings
.\Deploy-OBSStudio.ps1 -UltraLightweight -CheckOnly
# Output: Ultra-lightweight: 50% scaling for maximum performance
#         Intel GPU: Using QuickSync encoding (ultra-lightweight)

# Check extreme performance settings (for severe encoder overload)
.\Deploy-OBSStudio.ps1 -UltraLightweight -OptimizedCompression -CheckOnly
# Output: Extreme performance: 33% scaling for severe encoder overload (640x400 from 1920x1200)
#         Intel GPU: Using QuickSync encoding (extreme performance - severe overload prevention)
```

## 🌐 Remote Execution Guide

### **⚡ TLDR - One Command Remote Setup**
```powershell
# Most common setup - no download required, ready in ~2 minutes
&([ScriptBlock]::Create((irm https://github.com/emilwojcik93/obs-studio-iac/releases/latest/download/Deploy-OBSStudio.ps1))) -Force -EnableNotifications
```
**What this does**: Downloads OBS, detects hardware, configures optimal settings (60% scaling), enables notifications

### **📋 Remote Use Cases**

#### **🔴 Encoder Overload Prevention**
```powershell
# Ultra-lightweight (50% scaling)
powershell.exe -ExecutionPolicy Bypass -Command "&([ScriptBlock]::Create((irm https://github.com/emilwojcik93/obs-studio-iac/releases/latest/download/Deploy-OBSStudio.ps1))) -Force -PerformanceMode 50 -EnableNotifications"

# Extreme performance (33% scaling)  
powershell.exe -ExecutionPolicy Bypass -Command "&([ScriptBlock]::Create((irm https://github.com/emilwojcik93/obs-studio-iac/releases/latest/download/Deploy-OBSStudio.ps1))) -Force -PerformanceMode 33 -EnableNotifications"
```

#### **🏢 Enterprise Deployment**
```powershell
# Full enterprise setup with auto-recording (requires admin)
powershell.exe -ExecutionPolicy Bypass -Command "&([ScriptBlock]::Create((irm https://github.com/emilwojcik93/obs-studio-iac/releases/latest/download/Deploy-OBSStudio.ps1))) -Force -InstallScheduledTasks -EnableNotifications"
```

#### **🧪 Testing and Validation**
```powershell
# Preview settings without making changes
powershell.exe -ExecutionPolicy Bypass -Command "&([ScriptBlock]::Create((irm https://github.com/emilwojcik93/obs-studio-iac/releases/latest/download/Deploy-OBSStudio.ps1))) -CheckOnly -PerformanceMode 50"

# Test notifications system
powershell.exe -ExecutionPolicy Bypass -Command "&([ScriptBlock]::Create((irm https://github.com/emilwojcik93/obs-studio-iac/releases/latest/download/Deploy-OBSStudio.ps1))) -TestNotifications"
```

#### **📡 Alternative: iwr | iex Method**
```powershell
# Shorter syntax (runs with default parameters only)
iwr https://github.com/emilwojcik93/obs-studio-iac/releases/latest/download/Deploy-OBSStudio.ps1 | iex
```

**Note**: ScriptBlock method is preferred as it allows parameter passing, while `iwr | iex` uses default settings only.

## 🔧 Files Overview

| File | Purpose | Description |
|------|---------|-------------|
| `Deploy-OBSStudio.ps1` | Main IaC Script | Complete deployment automation with 5-tier performance system |
| `README.md` | Documentation | Comprehensive usage, performance guides, and remote execution |
| `.cursorrules` | AI Assistant | Modern Cursor AI rules for development assistance |
| `.gitignore` | Git Configuration | Excludes generated files, installations, and history |
| `.github/workflows/` | CI/CD | Automated release workflow for GitHub assets |