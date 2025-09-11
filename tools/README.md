# 🛠️ OBS Studio Deployment Tools

This directory contains utility scripts and testing tools for the OBS Studio Infrastructure as Code deployment.

## 📁 Directory Structure

```
tools/
└── Test-DisplayConfigurations.ps1  # Generic display configuration testing tool
```

## 🧪 Testing Tools

### **Test-DisplayConfigurations.ps1**

Generic display configuration testing tool that validates all display parameter combinations.

#### **Features**
- ✅ **Auto-Detection**: Automatically detects available displays and OBS installation
- ✅ **Comprehensive Testing**: Tests all display modes (Primary, Internal, External)
- ✅ **Configuration Verification**: Validates scene files and monitor IDs
- ✅ **Interactive Validation**: Launches OBS for manual verification (optional)
- ✅ **CI/CD Ready**: Supports automated testing with `-SkipOBSLaunch`

#### **Usage**

```powershell
# Basic usage - auto-detects OBS installation
.\Test-DisplayConfigurations.ps1

# Custom OBS installation path
.\Test-DisplayConfigurations.ps1 -InstallPath "C:\Custom\OBS-Path"

# Custom script path
.\Test-DisplayConfigurations.ps1 -ScriptPath "C:\Scripts\Deploy-OBSStudio.ps1"

# Automated testing (no OBS launch)
.\Test-DisplayConfigurations.ps1 -SkipOBSLaunch
```

#### **Test Cases**

| Test Case | Description | Validates |
|-----------|-------------|-----------|
| **Primary Display** | Tests Windows primary display detection | Monitor ID, resolution, positioning |
| **Internal Display** | Tests laptop screen detection (TMX, LGD, etc.) | Internal display preference, scaling |
| **External Display** | Tests external monitor detection (PHL, DEL, etc.) | External monitor priority, configuration |

#### **Output Example**

```
=== Testing: Internal Display ===
✅ Display Capture source found
   Monitor ID: \\?\DISPLAY#TMX0002#5&1f28af72&0&UID256#{...}
   Manufacturer: TMX0002, Device: 5&1f28af72&0&UID256
✅ Correct monitor configured (TMX0002)
   Base Resolution: 1280x720
✅ Correct resolution configured

=== Launching OBS for Manual Validation ===
Please verify:
1. Display Capture source shows correct monitor/display
2. Resolution and content look correct
3. No black screen or positioning issues
4. Close OBS to continue to next test
```

## 🔄 Integration with Main Script

The testing tools work seamlessly with the main deployment script:

- **Auto-Detection**: Automatically finds `Deploy-OBSStudio.ps1` in parent directory
- **Parameter Compatibility**: Uses same parameters as main script
- **Configuration Validation**: Verifies same configuration files
- **OBS Integration**: Uses same OBS launch methodology

## 🚀 Development Workflow

1. **Make changes** to `Deploy-OBSStudio.ps1`
2. **Run testing tool** to validate all display configurations
3. **Verify manually** in OBS that configurations work correctly
4. **Commit changes** with confidence that all display modes work

## 📋 Requirements

- PowerShell 5.1 or later
- Windows 10/11
- OBS Studio Portable installation
- Parent directory containing `Deploy-OBSStudio.ps1`

## 🔧 Troubleshooting

### **"Deploy-OBSStudio.ps1 not found"**
- Ensure script is in parent directory or specify with `-ScriptPath`

### **"Could not auto-detect OBS installation"**
- Specify installation path with `-InstallPath` parameter
- Verify OBS executable exists at `[Path]\bin\64bit\obs64.exe`

### **"No Display Capture sources found"**
- Run with main script first to create initial configuration
- Check that scene file exists in OBS profile directory

