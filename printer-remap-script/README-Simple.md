# Universal Print Remapping - Simple Version

This is a simplified, production-ready solution for Universal Print printer remapping with **clear separation of concerns**.

## Two Independent Scripts

### 1. RemapPrinters-Simple.ps1
**Purpose:** Remove and remap printers (business logic ONLY)

**Features:**
- Simple GUI with printer selection
- Loads printer shares from Microsoft Graph or config file
- Removes existing network printers
- Installs Universal Print printers using `UPPrinterInstaller.exe`
- Logs operations to `%LOCALAPPDATA%\PrinterRemap\remap_*.log`

**Does NOT include:** Diagnostics, testing, or troubleshooting logic

### 2. Test-UniversalPrintConnectivity.ps1
**Purpose:** Diagnose and report on Universal Print connectivity (troubleshooting ONLY)

**Features:**
- Tests environment and configuration
- Validates PowerShell modules
- Tests Microsoft Graph connectivity
- Retrieves and validates printer shares
- Tests network connectivity to physical printer IPs
- Checks Windows print service
- Tests internet connectivity to Universal Print endpoints
- Generates comprehensive diagnostic report

**Does NOT:** Remove or install any printers

## Why Separate Scripts?

**Stability:** Diagnostic logic can't break printer remapping
**Clarity:** Each script has a single, clear purpose
**Troubleshooting:** Run diagnostics independently when issues occur
**Maintenance:** Easier to update and debug each component

## Quick Start

### Step 1: Run Diagnostics First
```powershell
.\Test-UniversalPrintConnectivity.ps1
```

This will:
- Check if your environment is ready
- Test connectivity to Universal Print
- Identify missing modules or configuration
- Generate a report at `%LOCALAPPDATA%\PrinterRemap\diagnostics_*.txt`

**Review the report** to ensure everything is working before remapping.

### Step 2: Get Your Printer Share IDs

**Option A: Use Microsoft Graph (Recommended)**

The diagnostic script will list available printer shares. Copy the IDs to your config file.

**Option B: Use Azure Portal**
1. Go to https://portal.microsoft.com
2. Navigate to **Devices** > **Printers** > **Printer shares**
3. Note the share names and IDs

**Option C: Use PowerShell**
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
Connect-MgGraph -Scopes "Printer.Read.All", "PrinterShare.ReadBasic.All"
Get-MgPrintShare | Select-Object DisplayName, Id
```

### Step 3: Configure PrinterShares.json

Edit `PrinterShares.json` with your printer share IDs:

```json
{
  "PrinterShares": [
    {
      "DisplayName": "Office Printer 1",
      "Id": "actual-share-id-from-step-2"
    }
  ],
  "PrinterIPs": [
    "192.168.1.10"
  ]
}
```

**PrinterIPs** are optional - only used by the diagnostic script to test physical printer connectivity.

### Step 4: Run the Remapping Script
```powershell
.\RemapPrinters-Simple.ps1
```

The GUI will:
1. Load printer shares from Microsoft Graph (or config file as fallback)
2. Display available printers
3. Let you select which printers to install
4. Remove existing network printers
5. Install selected Universal Print printers

## Usage Scenarios

### Scenario 1: Initial Setup
```powershell
# 1. Run diagnostics to validate environment
.\Test-UniversalPrintConnectivity.ps1 -Detailed

# 2. Review the diagnostic report

# 3. Configure PrinterShares.json

# 4. Run diagnostics again to validate config
.\Test-UniversalPrintConnectivity.ps1

# 5. Run remapping
.\RemapPrinters-Simple.ps1
```

### Scenario 2: Troubleshooting
```powershell
# User reports printer installation failed

# Run diagnostics to identify the issue
.\Test-UniversalPrintConnectivity.ps1 -Detailed

# Check the diagnostic report for:
# - Missing modules
# - Graph connectivity issues
# - Invalid printer share IDs
# - Network connectivity problems
# - Print service status

# Fix the identified issues, then run diagnostics again
```

### Scenario 3: Regular Deployment
```powershell
# Just run the remapping script
# It will auto-load shares from Microsoft Graph
.\RemapPrinters-Simple.ps1
```

## Requirements

### Windows Version
- Windows 10 20H2 or later
- Windows 11 (any version)

Universal Print requires modern Windows with `UPPrinterInstaller.exe`.

### PowerShell Modules (Optional but Recommended)
```powershell
# For Graph API support (auto-discovery of printers)
Install-Module Microsoft.Graph -Scope CurrentUser

# Or just the required modules
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module Microsoft.Graph.DeviceManagement.Actions -Scope CurrentUser
```

**Note:** The remapping script works without these modules if you manually configure `PrinterShares.json`.

### Microsoft 365 Requirements
- Universal Print license
- Printer shares created and published
- User has permission to access printer shares

## How the Remapping Script Works

1. **Auto-discovers printers** via Microsoft Graph API
2. **Falls back to config file** if Graph is unavailable
3. **Removes old network printers** using `Remove-Printer`
4. **Installs Universal Print printers** using:
   - Primary method: `UPPrinterInstaller.exe /install /printerSharedId:<id>`
   - Fallback method: `Add-Printer -ConnectionName https://universalprint.windows.net/<id>`

## How the Diagnostic Script Works

Runs 10 independent tests:

1. ✅ Environment Information
2. ✅ UPPrinterInstaller.exe Check
3. ✅ PowerShell Modules Check
4. ✅ Config File Validation
5. ✅ Windows Print Service Check
6. ✅ Internet Connectivity Test
7. ✅ Microsoft Graph Connectivity
8. ✅ Universal Print Shares Test
9. ✅ Current Printer Configuration
10. ✅ Printer IP Connectivity (optional)

Generates a detailed report with:
- Test results (PASS/FAIL)
- Error messages
- Recommendations for fixing issues
- Configuration validation

## Logs and Reports

### Remapping Logs
Location: `%LOCALAPPDATA%\PrinterRemap\remap_YYYYMMDD_HHMMSS.log`

Example:
```
[2025-11-09 14:30:15] === Universal Print Remapping Started ===
[2025-11-09 14:30:16] User selected 2 printer shares
[2025-11-09 14:30:20] Removed printer: \\OLD-SERVER\Printer1
[2025-11-09 14:30:25] Successfully installed Office Printer 1
[2025-11-09 14:30:30] === Remapping Finished ===
```

### Diagnostic Reports
Location: `%LOCALAPPDATA%\PrinterRemap\diagnostics_YYYYMMDD_HHMMSS.txt`

Example:
```
===============================================================================
DIAGNOSTIC SUMMARY
===============================================================================
Tests Passed: 8
Tests Failed: 2

[PASS] Environment
[PASS] UPPrinterInstaller
[FAIL] PowerShell Modules
[PASS] Config File
...

===============================================================================
RECOMMENDATIONS
===============================================================================
- Install Microsoft Graph PowerShell SDK:
  Install-Module Microsoft.Graph -Scope CurrentUser
```

## Troubleshooting

### "UPPrinterInstaller.exe not found"
**Solution:** Update Windows to 20H2 or later
```powershell
# Check Windows version
winver

# Update Windows
Start-Process ms-settings:windowsupdate
```

### "Failed to get shares from Graph"
**Solution:** Install Graph modules or use config file
```powershell
# Install Graph
Install-Module Microsoft.Graph -Scope CurrentUser

# Or manually edit PrinterShares.json
```

### "No printer shares found in tenant"
**Solution:**
1. Verify Universal Print is configured in Microsoft 365 admin center
2. Ensure printers are registered and shares are created
3. Check that shares are **published** (not just created)
4. Verify your account has appropriate permissions

### "Printer installation failed"
**Solution:** Run diagnostics
```powershell
.\Test-UniversalPrintConnectivity.ps1 -Detailed
```

Check the report for:
- Invalid printer share IDs
- Network connectivity issues
- Missing permissions
- Service issues

## Deployment with Intune

### Using Remapping Script
1. Package the script with PrinterShares.json
2. Deploy as a Win32 app or PowerShell script
3. Run in **user context** (not SYSTEM)
4. Install command: `powershell.exe -ExecutionPolicy Bypass -File RemapPrinters-Simple.ps1`

### Using Diagnostic Script
Deploy separately as a troubleshooting tool:
```powershell
# Detection script
.\Test-UniversalPrintConnectivity.ps1
exit 0  # Always run
```

## Security Notes

- **No credentials stored:** Uses current user's authentication
- **Graph API uses delegated permissions:** User must have access to printer shares
- **Logs stored in user profile:** No sensitive data in logs
- **Config file:** Should only contain share IDs (no secrets)

## File Structure

```
printer-remap-script/
├── RemapPrinters-Simple.ps1           # Main remapping script
├── Test-UniversalPrintConnectivity.ps1 # Diagnostic script
├── PrinterShares.json                  # Configuration file
└── README-Simple.md                    # This file

Logs (auto-created):
%LOCALAPPDATA%\PrinterRemap\
├── remap_20251109_143015.log          # Remapping logs
└── diagnostics_20251109_142000.txt    # Diagnostic reports
```

## Support

### Run Diagnostics First
```powershell
.\Test-UniversalPrintConnectivity.ps1 -Detailed
```

### Check Logs
```powershell
# View latest remapping log
explorer "$env:LOCALAPPDATA\PrinterRemap"

# View latest diagnostic report
explorer "$env:LOCALAPPDATA\PrinterRemap"
```

### Common Issues

| Issue | Solution |
|-------|----------|
| No printer shares in dropdown | Run diagnostic script, check Graph connectivity |
| Installation fails | Verify share IDs in config match actual shares |
| UPPrinterInstaller not found | Update Windows to 20H2+ |
| Graph connection fails | Install Microsoft.Graph module |
| Print service not running | Restart Print Spooler service |

## Version History

### Version 2.0 (2025-11-09)
- **BREAKING:** Split into two separate scripts
- Remapping script: Focused on business logic only
- Diagnostic script: Comprehensive testing and reporting
- Improved stability and maintainability
- Clearer separation of concerns

### Version 1.0
- Original combined implementation

## License

Use at your own risk. Test thoroughly before production deployment.
