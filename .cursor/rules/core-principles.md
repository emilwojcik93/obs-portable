# Core IaC Principles - OBS Studio Portable Repository

## Repository Purpose

This repository provides **Infrastructure as Code (IaC) automation** for OBS Studio portable deployment with:

- **Automated Installation**: Downloads and installs OBS Studio portable from GitHub API
- **Hardware-Aware Configuration**: Detects GPU, display, and system capabilities
- **Performance Optimization**: 5-tier performance modes (33%, 50%, 60%, 75%, 90% scaling)
- **Microsoft Cloud Integration**: OneDrive/SharePoint optimized settings
- **Enterprise Deployment**: Scheduled tasks, notifications, and protection systems
- **Interactive Setup**: Respects OBS wizard while automating post-configuration

## Infrastructure as Code Principles

### 1. Idempotent Operations
- Scripts produce same result when run multiple times
- Check existing state before making changes
- Support for `-Force` parameter to override existing installations

### 2. Declarative Configuration
- Focus on desired end state rather than procedural steps
- Hardware-aware configuration that adapts to system capabilities
- Performance modes declare target optimization level

### 3. Version Controlled Infrastructure
- All infrastructure changes tracked in Git
- Configuration templates and automation scripts versioned
- Reproducible deployments across different environments

### 4. Comprehensive Testing
- `-CheckOnly` mode for environment validation
- `-WhatIf` mode for dry-run preview of changes
- Configuration verification after deployment

### 5. Self-Documenting
- Comprehensive parameter documentation
- Real-world usage examples
- Troubleshooting guides based on actual issues encountered

## Key Components

### Primary Script: `Deploy-OBSStudio.ps1`
- **Complete automation**: Single script handles entire deployment lifecycle
- **Performance modes**: Unified `-PerformanceMode` parameter (33-90% scaling)
- **Display management**: Automatic, interactive, or parameter-based display selection
- **Hardware detection**: Advanced WMI-based monitor and GPU detection
- **Protection systems**: Video corruption prevention and graceful shutdown

### Documentation: `README.md`
- **Usage examples**: All parameter combinations with expected outputs
- **Hardware compatibility**: GPU-specific optimizations and requirements
- **Troubleshooting**: Real-world issues and tested solutions
- **Performance comparison**: Detailed tables showing optimization levels

## Architecture Decisions

### Interactive First-Time Setup
- **Reasoning**: OBS requires interactive wizard completion for proper configuration
- **Implementation**: Script launches OBS, waits for user completion, then optimizes
- **Benefit**: Respects OBS internal mechanisms while providing automation

### Performance Mode Unification
- **Previous**: Separate `-OptimizedCompression` and `-UltraLightweight` parameters
- **Current**: Single `-PerformanceMode` with values 33, 50, 60, 75, 90
- **Benefit**: Intuitive scaling percentages, clear performance expectations

### Hardware-Aware Optimization
- **GPU Detection**: NVIDIA NVENC → Intel QuickSync → AMD AMF → x264 fallback
- **Display Detection**: Current resolution vs native hardware resolution
- **Manufacturer Recognition**: Real monitor names (Philips PHL 499P9) vs generic names

### Protection System Design
- **Background Jobs**: Auto-stop timer uses PowerShell jobs (no admin required)
- **Scheduled Tasks**: System event monitoring (requires admin)
- **Graceful Shutdown**: 20-second timeout for large video file closure

## Quality Standards

### Code Quality
- **PowerShell Best Practices**: Approved verbs, error handling, parameter validation
- **ASCII/UTF-8 Only**: No Unicode characters in PowerShell scripts
- **Variable Bracketing**: `${var}%` instead of `$var%` for special characters
- **Comprehensive Logging**: Colored output with Info, Success, Warning, Error levels

### Documentation Quality
- **Unicode Allowed**: Full Unicode support in markdown documentation
- **Real Examples**: Actual hardware detection results and configuration outputs
- **Parameter Tables**: Complete with types, defaults, and descriptions
- **Troubleshooting**: Based on real development issues and solutions

## Deployment Modes

### 1. Standard Mode
```powershell
.\Deploy-OBSStudio.ps1 -Force
# 60% scaling (default), 3000 kbps, Intel QuickSync optimized
```

### 2. Enterprise Mode
```powershell
.\Deploy-OBSStudio.ps1 -Force -InstallScheduledTasks -EnableNotifications
# Includes auto-recording service and system integration
```

### 3. Performance Modes
```powershell
.\Deploy-OBSStudio.ps1 -Force -PerformanceMode 33  # Extreme (encoder overload prevention)
.\Deploy-OBSStudio.ps1 -Force -PerformanceMode 50  # Ultra-lightweight
.\Deploy-OBSStudio.ps1 -Force -PerformanceMode 75  # Optimized for older hardware
.\Deploy-OBSStudio.ps1 -Force -PerformanceMode 90  # Standard quality
```

### 4. Validation Modes
```powershell
.\Deploy-OBSStudio.ps1 -CheckOnly     # Environment validation
.\Deploy-OBSStudio.ps1 -WhatIf        # Dry-run preview
```

## Success Metrics

- **Hardware Detection Accuracy**: Real monitor names, correct resolutions
- **Configuration Verification**: Settings actually applied and verified
- **Performance Optimization**: Encoder overload prevention across hardware tiers
- **User Experience**: Clear output, helpful error messages, intuitive parameters
- **Enterprise Ready**: Scheduled tasks, notifications, protection systems
