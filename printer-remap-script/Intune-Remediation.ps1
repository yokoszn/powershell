# Intune Proactive Remediation - Remediation Script
# Remaps printers when detection script identifies issues

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

# Registry key for tracking last successful remap
$registryPath = "HKLM:\SOFTWARE\PrinterRemap"
$registryKey = "LastSuccessfulRemap"

# Logging
$logPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\PrinterRemap.log"
#EndRegion

#Region Helper Functions
function Write-RemediationLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    try {
        $logDir = Split-Path $logPath -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Add-Content -Path $logPath -Value $logMessage -ErrorAction SilentlyContinue
    }
    catch {
        # Silently continue if logging fails
    }

    Write-Output $logMessage
}

function Test-PrinterConnectivity {
    param([string]$IP, [string]$Name)

    try {
        $ping = Test-Connection -ComputerName $IP -Count 2 -Quiet -ErrorAction Stop
        if ($ping) {
            Write-RemediationLog "$Name ($IP) is reachable" "SUCCESS"
            return $true
        }
        else {
            Write-RemediationLog "$Name ($IP) is not reachable" "WARNING"
            return $false
        }
    }
    catch {
        Write-RemediationLog "Failed to ping $Name ($IP)" "WARNING"
        return $false
    }
}

function Remove-NetworkPrinters {
    try {
        Write-RemediationLog "Removing existing network printers..."
        $printers = Get-Printer | Where-Object { $_.Type -eq "Connection" }

        if ($printers.Count -eq 0) {
            Write-RemediationLog "No network printers to remove"
            return 0
        }

        $removedCount = 0
        foreach ($printer in $printers) {
            try {
                Remove-Printer -Name $printer.Name -ErrorAction Stop
                Write-RemediationLog "Removed: $($printer.Name)" "SUCCESS"
                $removedCount++
            }
            catch {
                Write-RemediationLog "Failed to remove $($printer.Name): $($_.Exception.Message)" "ERROR"
            }
        }

        Write-RemediationLog "Removed $removedCount printer(s)"
        return $removedCount
    }
    catch {
        Write-RemediationLog "Printer removal failed: $($_.Exception.Message)" "ERROR"
        return 0
    }
}

function Install-NetworkPrinters {
    param([hashtable]$Config)

    $report = @{
        Success = 0
        Failed = 0
        Skipped = 0
    }

    try {
        Write-RemediationLog "Installing network printers..."

        foreach ($printer in $Config.Printers) {
            # Test connectivity
            $isReachable = Test-PrinterConnectivity -IP $printer.IP -Name $printer.Name

            if (-not $isReachable) {
                Write-RemediationLog "Skipping $($printer.Name) - not reachable" "WARNING"
                $report.Skipped++
                continue
            }

            # Install printer
            $printerPath = "$($Config.UniversalPrintPath)\$($printer.ShareName)"

            try {
                Add-Printer -ConnectionName $printerPath -ErrorAction Stop
                Write-RemediationLog "Installed: $($printer.Name)" "SUCCESS"
                $report.Success++
                Start-Sleep -Milliseconds 500
            }
            catch {
                Write-RemediationLog "Failed to install $($printer.Name): $($_.Exception.Message)" "ERROR"
                $report.Failed++
            }
        }

        Write-RemediationLog "Installation complete - Success: $($report.Success), Failed: $($report.Failed), Skipped: $($report.Skipped)"
        return $report
    }
    catch {
        Write-RemediationLog "Printer installation failed: $($_.Exception.Message)" "ERROR"
        return $report
    }
}

function Set-LastRemapDate {
    try {
        if (-not (Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
        }

        Set-ItemProperty -Path $registryPath -Name $registryKey -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Force
        Write-RemediationLog "Updated last remap timestamp in registry" "SUCCESS"
    }
    catch {
        Write-RemediationLog "Failed to update registry: $($_.Exception.Message)" "WARNING"
    }
}
#EndRegion

#Region Remediation Logic
try {
    Write-RemediationLog "========================================"
    Write-RemediationLog "Intune Printer Remediation Started"
    Write-RemediationLog "Computer: $env:COMPUTERNAME"
    Write-RemediationLog "User: $env:USERNAME"
    Write-RemediationLog "========================================"

    $startTime = Get-Date

    # Remove existing printers
    $removedCount = Remove-NetworkPrinters

    # Install new printers
    $installReport = Install-NetworkPrinters -Config $printerConfig

    # Calculate duration
    $duration = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)

    # Update registry with success timestamp if any printers were installed
    if ($installReport.Success -gt 0) {
        Set-LastRemapDate
    }

    Write-RemediationLog "========================================"
    Write-RemediationLog "Remediation Complete"
    Write-RemediationLog "Duration: $duration seconds"
    Write-RemediationLog "Removed: $removedCount | Installed: $($installReport.Success) | Failed: $($installReport.Failed) | Skipped: $($installReport.Skipped)"
    Write-RemediationLog "========================================"

    # Exit with appropriate code
    if ($installReport.Success -gt 0 -and $installReport.Failed -eq 0) {
        Write-Output "Remediation successful - All printers installed"
        exit 0  # Success
    }
    elseif ($installReport.Success -gt 0) {
        Write-Output "Remediation partial - Some printers installed"
        exit 0  # Partial success is still success
    }
    else {
        Write-Output "Remediation failed - No printers installed"
        exit 1  # Failure
    }
}
catch {
    Write-RemediationLog "CRITICAL ERROR: $($_.Exception.Message)" "ERROR"
    Write-RemediationLog "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    Write-Output "Remediation error: $($_.Exception.Message)"
    exit 1  # Error
}
#EndRegion
