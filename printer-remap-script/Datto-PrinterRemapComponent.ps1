# Datto RMM Component - Printer Remapping Script
# This script is designed to run via Datto RMM with custom field updates

#Region Datto RMM Environment Variables
# These are typically set by Datto RMM automatically
# Uncomment for local testing
# $env:CS_PROFILE_NAME = "TestProfile"
# $env:computerName = $env:COMPUTERNAME
#EndRegion

#Region Configuration
$printerConfig = @{
    UniversalPrintPath = "\\print-server\printers"
    Printers = @(
        @{ Name = "Office Printer 1"; IP = "192.168.1.10"; ShareName = "Printer-Office-1" }
        @{ Name = "Office Printer 2"; IP = "192.168.1.11"; ShareName = "Printer-Office-2" }
        @{ Name = "Accounting Printer"; IP = "192.168.1.20"; ShareName = "Printer-Accounting" }
        @{ Name = "Warehouse Printer"; IP = "192.168.1.30"; ShareName = "Printer-Warehouse" }
    )
}

# Datto Custom Field Names - Configure these in your Datto RMM
$customFields = @{
    LastRemapDate = "PrinterRemapDate"
    RemapStatus = "PrinterRemapStatus"
    RemapResults = "PrinterRemapResults"
    FailedPrinters = "PrinterRemapFailed"
    InstalledCount = "PrintersInstalled"
}
#EndRegion

#Region Logging
$logPath = "C:\ProgramData\DattoRMM\PrinterRemap.log"

function Write-DattoLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to log file
    Add-Content -Path $logPath -Value $logMessage -ErrorAction SilentlyContinue

    # Write to console for Datto activity log
    Write-Host $logMessage
}
#EndRegion

#Region Datto Custom Field Functions
function Set-DattoCustomField {
    param(
        [string]$FieldName,
        [string]$Value
    )

    try {
        # Datto RMM custom field format
        Write-Host "<-Start Result->"
        Write-Host "Field=$FieldName"
        Write-Host "Value=$Value"
        Write-Host "<-End Result->"

        Write-DattoLog "Set custom field: $FieldName = $Value" "SUCCESS"
    }
    catch {
        Write-DattoLog "Failed to set custom field $FieldName - $($_.Exception.Message)" "ERROR"
    }
}
#EndRegion

#Region Printer Functions
function Test-PrinterConnectivity {
    param([string]$IP, [string]$Name)

    try {
        $ping = Test-Connection -ComputerName $IP -Count 2 -Quiet -ErrorAction Stop

        if ($ping) {
            Write-DattoLog "$Name ($IP) is reachable" "SUCCESS"
            return $true
        }
        else {
            Write-DattoLog "$Name ($IP) is not reachable" "WARNING"
            return $false
        }
    }
    catch {
        Write-DattoLog "Failed to ping $Name ($IP) - $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Remove-NetworkPrinters {
    try {
        Write-DattoLog "Starting printer removal process..."
        $printers = Get-Printer | Where-Object { $_.Type -eq "Connection" }

        if ($printers.Count -eq 0) {
            Write-DattoLog "No network printers found to remove"
            return @()
        }

        $removedPrinters = @()
        foreach ($printer in $printers) {
            try {
                Remove-Printer -Name $printer.Name -ErrorAction Stop
                Write-DattoLog "Removed printer: $($printer.Name)" "SUCCESS"
                $removedPrinters += $printer.Name
            }
            catch {
                Write-DattoLog "Failed to remove printer $($printer.Name) - $($_.Exception.Message)" "ERROR"
            }
        }

        Write-DattoLog "Printer removal completed. Removed $($removedPrinters.Count) printer(s)"
        return $removedPrinters
    }
    catch {
        Write-DattoLog "Printer removal process failed - $($_.Exception.Message)" "ERROR"
        return @()
    }
}

function Install-NetworkPrinters {
    param([hashtable]$Config)

    $report = @{
        Success = 0
        Failed = 0
        Skipped = 0
        InstalledPrinters = @()
        FailedPrinters = @()
    }

    try {
        Write-DattoLog "Starting printer installation process..."

        foreach ($printer in $Config.Printers) {
            # Test connectivity first
            $isReachable = Test-PrinterConnectivity -IP $printer.IP -Name $printer.Name

            if (-not $isReachable) {
                Write-DattoLog "Skipping $($printer.Name) - printer is not reachable" "WARNING"
                $report.Skipped++
                $report.FailedPrinters += "$($printer.Name) (Not reachable)"
                continue
            }

            # Add printer
            $printerPath = "$($Config.UniversalPrintPath)\$($printer.ShareName)"

            try {
                Add-Printer -ConnectionName $printerPath -ErrorAction Stop
                Write-DattoLog "Installed printer $($printer.Name) from $printerPath" "SUCCESS"
                $report.Success++
                $report.InstalledPrinters += $printer.Name
            }
            catch {
                Write-DattoLog "Failed to install $($printer.Name) - $($_.Exception.Message)" "ERROR"
                $report.Failed++
                $report.FailedPrinters += "$($printer.Name) ($($_.Exception.Message))"
            }

            Start-Sleep -Milliseconds 500
        }

        Write-DattoLog "Printer installation completed. Success: $($report.Success), Failed: $($report.Failed), Skipped: $($report.Skipped)"
        return $report
    }
    catch {
        Write-DattoLog "Printer installation process failed - $($_.Exception.Message)" "ERROR"
        return $report
    }
}
#EndRegion

#Region Main Execution
try {
    Write-DattoLog "========================================" "INFO"
    Write-DattoLog "Datto RMM Printer Remapping Script Started" "INFO"
    Write-DattoLog "Computer: $env:COMPUTERNAME" "INFO"
    Write-DattoLog "User: $env:USERNAME" "INFO"
    Write-DattoLog "========================================" "INFO"

    $startTime = Get-Date

    # Remove existing printers
    $removedPrinters = Remove-NetworkPrinters

    # Install new printers
    $installReport = Install-NetworkPrinters -Config $printerConfig

    # Calculate duration
    $duration = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)

    # Prepare results
    $statusMessage = if ($installReport.Failed -eq 0 -and $installReport.Skipped -eq 0) {
        "SUCCESS - All printers installed"
    }
    elseif ($installReport.Success -gt 0) {
        "PARTIAL - $($installReport.Success) installed, $($installReport.Failed) failed, $($installReport.Skipped) skipped"
    }
    else {
        "FAILED - No printers installed"
    }

    $resultsMessage = "Success: $($installReport.Success) | Failed: $($installReport.Failed) | Skipped: $($installReport.Skipped) | Duration: $($duration)s"
    $failedPrintersMessage = if ($installReport.FailedPrinters.Count -gt 0) {
        $installReport.FailedPrinters -join "; "
    }
    else {
        "None"
    }

    # Update Datto custom fields
    Set-DattoCustomField -FieldName $customFields.LastRemapDate -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    Set-DattoCustomField -FieldName $customFields.RemapStatus -Value $statusMessage
    Set-DattoCustomField -FieldName $customFields.RemapResults -Value $resultsMessage
    Set-DattoCustomField -FieldName $customFields.FailedPrinters -Value $failedPrintersMessage
    Set-DattoCustomField -FieldName $customFields.InstalledCount -Value $installReport.Success.ToString()

    Write-DattoLog "========================================" "INFO"
    Write-DattoLog "Printer Remapping Completed" "INFO"
    Write-DattoLog "Status: $statusMessage" "INFO"
    Write-DattoLog "Results: $resultsMessage" "INFO"
    Write-DattoLog "========================================" "INFO"

    # Exit with appropriate code
    if ($installReport.Failed -eq 0 -and $installReport.Skipped -eq 0) {
        exit 0  # Complete success
    }
    elseif ($installReport.Success -gt 0) {
        exit 0  # Partial success (some printers installed)
    }
    else {
        exit 1  # Complete failure
    }
}
catch {
    Write-DattoLog "CRITICAL ERROR: $($_.Exception.Message)" "ERROR"
    Write-DattoLog "Stack Trace: $($_.ScriptStackTrace)" "ERROR"

    Set-DattoCustomField -FieldName $customFields.RemapStatus -Value "ERROR - Script failed"
    Set-DattoCustomField -FieldName $customFields.RemapResults -Value $_.Exception.Message

    exit 1
}
#EndRegion
