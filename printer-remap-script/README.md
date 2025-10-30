# Printer Remapping Script

A PowerShell-based GUI tool for unmapping and remapping network printers with progress tracking and connectivity testing.

## Files

- `RemapPrinters.ps1` - Main PowerShell script with GUI
- `PrinterConfig.json` - Configuration file for printer settings
- `PrinterRemap.log` - Auto-generated log file (created on first run)

## Setup Instructions

### 1. Configure Printers

Edit `PrinterConfig.json` to match your environment:

```json
{
  "UniversalPrintPath": "\\\\print-server\\printers",
  "Printers": [
    {
      "Name": "Office Printer 1",
      "IP": "192.168.1.10",
      "ShareName": "Printer-Office-1"
    }
  ]
}
```

- **UniversalPrintPath**: The base network path to your print server
- **Name**: Descriptive name for the printer (for logging)
- **IP**: IP address of the printer (used for ping test)
- **ShareName**: The share name on the print server

### 2. Copy to Desktop

1. Copy both `RemapPrinters.ps1` and `PrinterConfig.json` to the user's Desktop
2. Right-click `RemapPrinters.ps1` and select "Create shortcut"
3. Rename the shortcut to "Remap Printers"

### 3. Run the Script

Double-click the script or shortcut to launch the GUI. Click "Start" to begin the remapping process.

## Features

- **GUI Interface**: User-friendly window with progress bar
- **Connectivity Testing**: Pings each printer before attempting to map
- **Progress Tracking**: Real-time progress bar showing current operation
- **Detailed Logging**: All operations logged to `PrinterRemap.log`
- **Error Handling**: Graceful handling of failures with detailed error messages

## Process Flow

1. **Load Configuration**: Reads printer settings from config file
2. **Remove Printers**: Unmaps all existing network printers (50% progress)
3. **Ping Test**: Tests connectivity to each printer via IP
4. **Install Printers**: Maps printers that pass connectivity test (50-100% progress)
5. **Summary**: Shows success/failure count and completion message

## Troubleshooting

### Script won't run
- Right-click the script → Properties → Unblock
- Or run PowerShell as Administrator and execute:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

### Printers not mapping
- Verify the `UniversalPrintPath` in config file
- Ensure printer share names match exactly
- Check network connectivity to print server
- Review `PrinterRemap.log` for specific errors

### Ping test failing
- Verify printer IP addresses in config file
- Ensure printers are powered on and connected to network
- Check if ICMP (ping) is blocked by firewall

## Log File

The script creates `PrinterRemap.log` in the same directory. Each entry includes:
- Timestamp
- Operation performed
- Success/failure status
- Error messages (if any)

Example log entry:
```
[2025-10-31 14:30:15] SUCCESS: Installed printer Office Printer 1 from \\print-server\printers\Printer-Office-1
```
