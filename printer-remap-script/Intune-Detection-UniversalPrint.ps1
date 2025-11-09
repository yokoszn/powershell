# Universal Print Detection Script for Intune
# This script detects if Universal Print printers need to be configured

# Detection criteria:
# 1. Check if UniversalPrintManagement module is available
# 2. Check if expected Universal Print printers are installed
# 3. Return exit code 0 if compliant, 1 if remediation needed

$ErrorActionPreference = "SilentlyContinue"

# Configuration - Update these with your Universal Print share names
$expectedPrinters = @(
    "Office-Printer-1-Share",
    "Office-Printer-2-Share",
    "Accounting-Printer-Share",
    "Warehouse-Printer-Share"
)

# Minimum number of expected printers that should be installed
$minimumRequiredPrinters = 2

try {
    # Check if UniversalPrintManagement module is available
    $module = Get-Module -ListAvailable -Name UniversalPrintManagement

    if (-not $module) {
        Write-Output "UniversalPrintManagement module not found - Remediation needed"
        exit 1
    }

    # Get currently installed printers
    $installedPrinters = Get-Printer | Where-Object {
        $_.Type -eq "Connection" -and
        $_.Name -like "*universalprint*"
    }

    # Count how many expected printers are installed
    $installedCount = 0
    foreach ($expectedPrinter in $expectedPrinters) {
        $found = $installedPrinters | Where-Object { $_.Name -like "*$expectedPrinter*" }
        if ($found) {
            $installedCount++
        }
    }

    # Check if we have minimum required printers
    if ($installedCount -ge $minimumRequiredPrinters) {
        Write-Output "Universal Print printers are configured ($installedCount/$($expectedPrinters.Count)) - Compliant"
        exit 0
    }
    else {
        Write-Output "Insufficient Universal Print printers installed ($installedCount/$minimumRequiredPrinters required) - Remediation needed"
        exit 1
    }
}
catch {
    Write-Output "Error during detection: $($_.Exception.Message) - Remediation needed"
    exit 1
}
