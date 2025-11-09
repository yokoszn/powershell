# Universal Print Printer Remapping Script

This PowerShell script automates the process of removing existing network printers and remapping them using **Microsoft Universal Print**. It includes a GUI interface, comprehensive logging, and integration with reporting systems.

## Features

- **Universal Print Integration**: Connects to Microsoft 365 Universal Print service
- **Automated Printer Management**: Removes old printers and installs Universal Print printers
- **GUI Interface**: User-friendly Windows Forms interface with progress tracking
- **Comprehensive Logging**: Detailed logs of all operations
- **Reporting Features**:
  - CSV export for record-keeping
  - Email notifications (optional)
  - Webhook integration for ticketing systems
  - Usage tracking and analytics
- **Error Handling**: Retry logic for failed printer installations
- **Flexible Configuration**: JSON-based configuration for easy customization

## Prerequisites

### Required

1. **PowerShell 5.1 or later**
2. **UniversalPrintManagement PowerShell Module**
   ```powershell
   Install-Module -Name UniversalPrintManagement -Scope CurrentUser
   ```
3. **Microsoft 365 License** with Universal Print access
4. **Administrator Privileges** (for printer management)
5. **Network Connectivity** to Microsoft 365 services

### Universal Print Setup

Before using this script, ensure:

1. Universal Print is configured in your Microsoft 365 tenant
2. Printers are registered with Universal Print
3. Printer shares are created and published
4. Users have appropriate permissions to access printer shares

## Installation

1. **Download the script files**:
   - `RemapPrinters-UniversalPrint.ps1`
   - `PrinterConfig-UniversalPrint.json`

2. **Install the Universal Print module**:
   ```powershell
   Install-Module -Name UniversalPrintManagement -Scope CurrentUser -Force
   ```

3. **Configure the JSON file** (see Configuration section below)

4. **Run the script**:
   ```powershell
   .\RemapPrinters-UniversalPrint.ps1
   ```

## Configuration

Edit the `PrinterConfig-UniversalPrint.json` file to match your environment:

### Universal Print Settings

```json
{
  "UniversalPrint": {
    "Enabled": true,
    "TenantId": "your-tenant.onmicrosoft.com",
    "AuthenticationMethod": "Interactive",
    "ServiceAccount": {
      "UserPrincipalName": "printer-admin@company.com",
      "UseStoredCredentials": false,
      "CredentialPath": ""
    }
  }
}
```

**Authentication Methods**:
- `Interactive`: User will be prompted to sign in (recommended for manual runs)
- `ServiceAccount`: Uses a service account (for automated deployments)

### Printer Configuration

```json
{
  "Printers": [
    {
      "Name": "Office Printer 1",
      "UniversalPrintShareName": "Office-Printer-1-Share",
      "UniversalPrintShareId": "",
      "Description": "Main office printer",
      "Enabled": true
    }
  ]
}
```

**Fields**:
- `Name`: Display name for the printer (for logging)
- `UniversalPrintShareName`: Name of the Universal Print share (as shown in admin portal)
- `UniversalPrintShareId`: (Optional) Universal Print share ID for more reliable matching
- `Description`: Description for documentation
- `Enabled`: Set to `false` to skip this printer

### Settings

```json
{
  "Settings": {
    "RemoveExistingPrinters": true,
    "SkipUnavailablePrinters": true,
    "SetDefaultPrinter": "",
    "InstallDelayMs": 200,
    "RetryFailedPrinters": true,
    "MaxRetries": 2
  }
}
```

### Reporting Configuration

```json
{
  "Reporting": {
    "EnableCSVExport": true,
    "CSVPath": "\\\\file-server\\IT\\PrinterReports",
    "EnableEmailReport": true,
    "EmailSettings": {
      "SMTPServer": "smtp.office365.com",
      "SMTPPort": 587,
      "FromAddress": "printer-remap@company.com",
      "ToAddress": "helpdesk@company.com",
      "UseSSL": true,
      "RequiresAuth": false,
      "OnlyEmailOnFailure": true
    },
    "EnableWebhook": false,
    "WebhookURL": "http://your-server:8080/printerreport",
    "EnableUsageTracking": true,
    "UsageTrackingPath": "\\\\file-server\\IT\\PrinterUsage"
  }
}
```

## Usage

### Interactive Mode (GUI)

1. Double-click the script or run:
   ```powershell
   .\RemapPrinters-UniversalPrint.ps1
   ```

2. The GUI will appear:
   - Click **Start** to begin the remapping process
   - Monitor progress in the progress bar and details window
   - Wait for completion message
   - Click **Close** when finished

### Silent/Automated Mode

For Intune or other deployment systems, see the included detection and remediation scripts.

## How It Works

1. **Module Initialization**: Checks for and loads the UniversalPrintManagement module
2. **Configuration Loading**: Reads the JSON configuration file
3. **Authentication**: Connects to Universal Print using the configured method
4. **Share Discovery**: Retrieves available Universal Print shares from your tenant
5. **Printer Removal**: Removes existing network printers (if configured)
6. **Share Validation**: Verifies that configured printer shares exist
7. **Printer Installation**: Installs printers from Universal Print shares
8. **Reporting**: Generates reports and sends notifications
9. **Cleanup**: Disconnects from Universal Print

## Finding Universal Print Share Names

To find your Universal Print share names:

### Method 1: Universal Print Admin Portal
1. Go to https://portal.microsoft.com
2. Navigate to **Devices** > **Printers**
3. Click on **Printer shares**
4. Note the **Share name** for each printer

### Method 2: PowerShell
```powershell
# Install and import the module
Install-Module UniversalPrintManagement
Import-Module UniversalPrintManagement

# Connect to Universal Print
Connect-UPService

# Get all printer shares
$shares = Get-UPPrinterShare
$shares.results | Select-Object DisplayName, Id | Format-Table

# Disconnect
Disconnect-UPService
```

Copy the `DisplayName` values into your configuration file's `UniversalPrintShareName` fields.

## Logging

Logs are saved to `PrinterRemap-UniversalPrint.log` in the same directory as the script.

Log format:
```
[2025-11-09 14:30:15] [INFO] Universal Print Remapping Process Started
[2025-11-09 14:30:16] [SUCCESS] UniversalPrintManagement module loaded
[2025-11-09 14:30:20] [SUCCESS] Connected to Universal Print
[2025-11-09 14:30:22] [SUCCESS] Found 4 Universal Print shares
[2025-11-09 14:30:25] [SUCCESS] Installed printer: Office Printer 1
```

## Deployment with Intune

Use the included Intune scripts:
- `Intune-Detection.ps1`: Detects if printers need remapping
- `Intune-Remediation.ps1`: Runs the remapping script

Configure as a **Remediation Script** in Intune:
1. Go to Intune > **Devices** > **Scripts** > **Remediations**
2. Add new script package
3. Upload detection and remediation scripts
4. Assign to user groups

## Troubleshooting

### Module Not Found
```powershell
# Install the module manually
Install-Module UniversalPrintManagement -Scope CurrentUser -Force
```

### Authentication Fails
- Ensure the user has a Universal Print license
- Verify the user has permissions to access printer shares
- Check network connectivity to Microsoft 365
- Try interactive authentication first

### Printer Share Not Found
- Verify the share name exactly matches the portal
- Use PowerShell to list available shares
- Check that the share is published (not just created)
- Ensure the user has access permissions to the share

### Printer Installation Fails
- Check that the share ID or name is correct
- Verify user has permissions to install printers
- Review the log file for detailed error messages
- Try installing manually to test connectivity

### Permission Errors
- Run PowerShell as Administrator
- Ensure user has local admin rights on the computer
- Check Universal Print licensing

## Security Notes

1. **Credential Storage**: For service account authentication with stored credentials, use:
   ```powershell
   # Create encrypted credential file (one-time setup)
   Get-Credential | Export-Clixml -Path "C:\SecurePath\PrinterCreds.xml"
   ```

2. **Configuration File**: Store the configuration file in a secure location with appropriate NTFS permissions

3. **Service Accounts**: Use dedicated service accounts with minimum required permissions

## Support

For issues related to:
- **Universal Print**: Check Microsoft 365 admin center or Microsoft documentation
- **This Script**: Review logs and configuration
- **PowerShell Module**: See https://learn.microsoft.com/en-us/universal-print/

## Version History

### Version 1.0 (2025-11-09)
- Initial release
- Universal Print integration
- GUI interface
- Comprehensive reporting
- Retry logic
- Usage tracking

## Related Files

- `RemapPrinters-UniversalPrint.ps1` - Main script
- `PrinterConfig-UniversalPrint.json` - Configuration file
- `PrinterRemap-UniversalPrint.log` - Log file (generated)
- `Intune-Detection.ps1` - Intune detection script
- `Intune-Remediation.ps1` - Intune remediation script

## License

Use at your own risk. Test thoroughly in your environment before production deployment.
