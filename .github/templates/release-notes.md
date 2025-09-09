# OBS Studio Infrastructure as Code v{VERSION}

## Complete IaC Solution for OBS Studio Deployment

### Key Features
- **5-Tier Performance System**: 33%, 50%, 60%, 75%, 90% scaling modes
- **Advanced Hardware Detection**: Real monitor names (Philips PHL 499P9, etc.)
- **Encoder Overload Prevention**: Extreme performance mode for problematic hardware
- **Microsoft Cloud Integration**: OneDrive/SharePoint optimized settings
- **Enterprise Deployment**: Scheduled tasks, notifications, protection systems
- **Interactive Setup**: Respects OBS wizard while automating optimization

### Performance Modes
| Mode | Scaling | Use Case | Command |
|------|---------|----------|---------|
| **33** | 33% (634x396) | Extreme encoder overload | `-PerformanceMode 33` |
| **50** | 50% (960x600) | Severe encoder overload | `-PerformanceMode 50` |
| **60** | 60% (1152x720) | **Default optimal** | Default or `-PerformanceMode 60` |
| **75** | 75% (1440x900) | Lower-end hardware | `-PerformanceMode 75` |
| **90** | 90% (1728x1080) | Modern hardware | `-PerformanceMode 90` |

### Quick Start

#### Remote Execution (Recommended)
```powershell
# Default lightweight deployment (60% scaling)
&([ScriptBlock]::Create((irm https://github.com/emilwojcik93/obs-studio-iac/releases/latest/download/Deploy-OBSStudio.ps1))) -Force -EnableNotifications

# Encoder overload prevention (33% scaling)
&([ScriptBlock]::Create((irm https://github.com/emilwojcik93/obs-studio-iac/releases/latest/download/Deploy-OBSStudio.ps1))) -Force -PerformanceMode 33 -EnableNotifications

# Enterprise deployment with scheduled tasks (requires admin)
&([ScriptBlock]::Create((irm https://github.com/emilwojcik93/obs-studio-iac/releases/latest/download/Deploy-OBSStudio.ps1))) -Force -InstallScheduledTasks -EnableNotifications
```

#### Local Execution
```powershell
# Download and run locally
Invoke-WebRequest -Uri "https://github.com/emilwojcik93/obs-studio-iac/releases/latest/download/Deploy-OBSStudio.ps1" -OutFile "Deploy-OBSStudio.ps1"
.\Deploy-OBSStudio.ps1 -Force -EnableNotifications

# Check configuration without making changes
.\Deploy-OBSStudio.ps1 -CheckOnly -PerformanceMode 50
```

### Hardware Support
- **Intel QuickSync**: Optimized presets and target usage
- **NVIDIA NVENC**: P1-P4 presets with ultra-low latency
- **AMD AMF**: Advanced Media Framework with pre-analysis
- **Display Detection**: Real monitor manufacturer and model detection
- **USB Adapter Filtering**: Correctly identifies DisplayLink docking stations

### Protection Features
- **20-second graceful shutdown**: Prevents video corruption
- **2-hour auto-stop timer**: Background job protection
- **System event monitoring**: Sleep/hibernate/shutdown detection
- **Configuration verification**: Confirms settings were applied

### Verified Performance Results
- **Encoder Overload Prevention**: Tested on Intel UHD Graphics with severe overload
- **Resolution Accuracy**: Correctly detects current vs native display resolution
- **Configuration Application**: Verified settings actually applied to OBS
- **Enterprise Deployment**: Scheduled tasks, notifications, OneDrive integration

Perfect for enterprise deployment, content creation, and automated recording infrastructure!
