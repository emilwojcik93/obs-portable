# OBS Studio Configuration Templates

This directory contains external template files used for silent deployment of OBS Studio configurations.

## 📁 Directory Structure

```
templates/
├── obs-config/                 # OBS Studio configuration templates
│   ├── basic.ini.template      # Main OBS profile configuration
│   ├── user.ini.template       # User interface and first-run settings
│   ├── global.ini.template     # Global OBS settings
│   └── scene.json.template     # Scene configuration with Display Capture
└── input-overlay/              # Input Overlay plugin templates
    └── custom-input-history.html # Professional input history template
```

## 🔧 Template System

### Parameter Replacement

Templates use `{{PARAMETER_NAME}}` placeholders that are dynamically replaced with hardware-specific values during deployment.

### Available Parameters

| Parameter | Description | Example Value |
|-----------|-------------|---------------|
| `{{ONEDRIVE_PATH}}` | OneDrive recordings path | `C:\\Users\\user\\OneDrive\\Recordings` |
| `{{VIDEO_BITRATE}}` | Dynamic video bitrate | `3833` |
| `{{AUDIO_BITRATE}}` | Audio bitrate based on performance mode | `96` |
| `{{GPU_PRESET}}` | GPU encoder preset | `balanced` |
| `{{STREAM_ENCODER}}` | Simple Output streaming encoder | `amd` |
| `{{REC_ENCODER}}` | Simple Output recording encoder | `amd` |
| `{{GPU_ENCODER}}` | Advanced Output encoder | `amd_amf_h264` |
| `{{BASE_WIDTH}}` | Native display width | `5120` |
| `{{BASE_HEIGHT}}` | Native display height | `1440` |
| `{{OUTPUT_WIDTH}}` | Recording output width | `2560` |
| `{{OUTPUT_HEIGHT}}` | Recording output height | `720` |
| `{{FPS}}` | Frames per second | `30` |
| `{{MONITOR_ID}}` | Display monitor identifier | `\\\\?\\DISPLAY#PHL092A#...` |
| `{{INSTALL_GUID}}` | Unique installation GUID | `A1B2C3D4E5F6...` |
| `{{COOKIE_ID}}` | Session cookie ID | `1A2B3C4D5E6F7G8H` |
| `{{AMF_PREANALYSIS}}` | AMD AMF pre-analysis setting | `True` |
| `{{AMF_BFRAMES}}` | AMD AMF B-frames setting | `2` |
| `{{DESKTOP_AUDIO_UUID}}` | Desktop audio source UUID | `785aeacd-c021-...` |
| `{{MIC_AUDIO_UUID}}` | Microphone audio source UUID | `621c771c-5bac-...` |
| `{{SCENE_UUID}}` | Scene UUID | `63511bfd-89c4-...` |
| `{{DISPLAY_SOURCE_UUID}}` | Display Capture source UUID | `169500fb-e666-...` |

## 🎮 Input Overlay Templates

### **Custom Input History Template**

The `input-overlay/custom-input-history.html` template provides professional keyboard and mouse input visualization:

- ✅ **Real-time Input Display**: Shows keyboard presses and mouse clicks
- ✅ **Professional Styling**: Clean, modern interface design
- ✅ **WebSocket Integration**: Connects with Input Overlay plugin
- ✅ **Customizable Appearance**: Easy to modify colors, fonts, and layout

**Usage**: After installing with `-InstallInputOverlay`, the template is automatically copied to:
`[OBS-Install-Path]\data\input-overlay-presets\input-history-windows\custom-input-history.html`

## 📝 Template Customization

### Modifying Templates

1. **Edit template files directly** - Changes apply to all future deployments
2. **Add new parameters** - Update both template and `New-OBSConfigurationTemplate` function
3. **Test changes** - Use `-SilentDeployment` parameter to verify modifications

### Example: Adding Custom Audio Settings

```ini
# In basic.ini.template
[Audio]
MonitoringDeviceId={{MONITORING_DEVICE}}
SampleRate={{SAMPLE_RATE}}
ChannelSetup={{CHANNEL_SETUP}}
```

Then add to PowerShell script:
```powershell
$parameters = @{
    'MONITORING_DEVICE' = 'default'
    'SAMPLE_RATE'       = '48000'
    'CHANNEL_SETUP'     = 'Stereo'
    # ... other parameters
}
```

## 🚀 Benefits

- **✅ Maintainable**: Templates separate from script logic
- **✅ Customizable**: Easy to modify without touching PowerShell code
- **✅ Version Control**: Templates can be tracked and versioned independently
- **✅ Reusable**: Same templates work across different hardware configurations
- **✅ Testable**: Templates can be validated independently

## 🔄 Usage

Templates are automatically used when running:

```powershell
.\Deploy-OBSStudio.ps1 -SilentDeployment -PerformanceMode 60
```

The script will:
1. Load templates from `templates/obs-config/`
2. Replace all `{{PARAMETER}}` placeholders with detected hardware values
3. Generate complete OBS configuration files
4. Skip Auto-Configuration Wizard entirely

## 📋 Template Validation

To ensure templates are valid:

1. **Syntax Check**: Verify INI/JSON syntax is correct
2. **Parameter Check**: Ensure all `{{PARAMETERS}}` have corresponding values
3. **Test Deployment**: Run silent deployment to verify configuration works
4. **OBS Validation**: Launch OBS to confirm settings are applied correctly
