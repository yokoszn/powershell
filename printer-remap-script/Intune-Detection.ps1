# Intune Proactive Remediation - Detection Script
# Checks if all required printers are installed and reachable

#Region Configuration
$requiredPrinters = @(
    @{ Name = "Office Printer 1"; IP = "192.168.1.10"; SharePath = "\\print-server\printers\Printer-Office-1" }
    @{ Name = "Office Printer 2"; IP = "192.168.1.11"; SharePath = "\\print-server\printers\Printer-Office-2" }
    @{ Name = "Accounting Printer"; IP = "192.168.1.20"; SharePath = "\\print-server\printers\Printer-Accounting" }
    @{ Name = "Warehouse Printer"; IP = "192.168.1.30"; SharePath = "\\print-server\printers\Printer-Warehouse" }
)

# Grace period for last successful installation (in hours)
$gracePeriodHours = 24

# Registry key for tracking last successful remap
$registryPath = "HKLM:\SOFTWARE\PrinterRemap"
$registryKey = "LastSuccessfulRemap"
#EndRegion

#Region Helper Functions
function Test-PrinterConnectivity {
    param([string]$IP)

    try {
        $ping = Test-Connection -ComputerName $IP -Count 1 -Quiet -ErrorAction SilentlyContinue
        return $ping
    }
    catch {
        return $false
    }
}

function Get-InstalledNetworkPrinters {
    try {
        $printers = Get-Printer | Where-Object { $_.Type -eq "Connection" }
        return $printers
    }
    catch {
        Write-Output "Error getting installed printers: $($_.Exception.Message)"
        return @()
    }
}

function Get-LastRemapDate {
    try {
        if (Test-Path $registryPath) {
            $value = Get-ItemProperty -Path $registryPath -Name $registryKey -ErrorAction SilentlyContinue
            if ($value) {
                return [DateTime]::Parse($value.$registryKey)
            }
        }
        return $null
    }
    catch {
        return $null
    }
}
#EndRegion

#Region Detection Logic
try {
    Write-Output "Starting printer detection..."

    # Get installed printers
    $installedPrinters = Get-InstalledNetworkPrinters
    $installedPrinterPaths = $installedPrinters | Select-Object -ExpandProperty Name

    # Check for missing or unreachable printers
    $missingPrinters = @()
    $unreachablePrinters = @()

    foreach ($printer in $requiredPrinters) {
        # Check if printer is installed
        $isInstalled = $installedPrinterPaths -contains $printer.SharePath

        if (-not $isInstalled) {
            $missingPrinters += $printer.Name
            Write-Output "Missing printer: $($printer.Name)"
        }
        else {
            # Check if printer is reachable
            $isReachable = Test-PrinterConnectivity -IP $printer.IP

            if (-not $isReachable) {
                $unreachablePrinters += $printer.Name
                Write-Output "Printer not reachable: $($printer.Name) ($($printer.IP))"
            }
        }
    }

    # Check last successful remap date
    $lastRemapDate = Get-LastRemapDate
    $remapIsStale = $false

    if ($lastRemapDate) {
        $hoursSinceRemap = ((Get-Date) - $lastRemapDate).TotalHours
        Write-Output "Last successful remap: $lastRemapDate ($([math]::Round($hoursSinceRemap, 2)) hours ago)"

        if ($hoursSinceRemap -gt $gracePeriodHours) {
            $remapIsStale = $true
            Write-Output "Remap is older than grace period ($gracePeriodHours hours)"
        }
    }
    else {
        Write-Output "No previous remap detected"
        $remapIsStale = $true
    }

    # Determine if remediation is needed
    $needsRemediation = $false

    if ($missingPrinters.Count -gt 0) {
        Write-Output "ISSUE DETECTED: $($missingPrinters.Count) printer(s) missing"
        $needsRemediation = $true
    }

    if ($unreachablePrinters.Count -gt 0) {
        Write-Output "ISSUE DETECTED: $($unreachablePrinters.Count) printer(s) not reachable"
        # Note: Unreachable printers don't necessarily need remediation
        # They might be offline temporarily
    }

    if ($remapIsStale -and $missingPrinters.Count -eq 0) {
        Write-Output "INFO: Remap is stale but all printers are installed"
        # Optional: Enable this to force periodic remapping
        # $needsRemediation = $true
    }

    # Exit with appropriate code
    if ($needsRemediation) {
        Write-Output "DETECTION RESULT: Remediation required"
        Write-Output "Missing: $($missingPrinters -join ', ')"
        if ($unreachablePrinters.Count -gt 0) {
            Write-Output "Unreachable: $($unreachablePrinters -join ', ')"
        }
        exit 1  # Issue detected - trigger remediation
    }
    else {
        Write-Output "DETECTION RESULT: All printers are properly configured"
        Write-Output "Installed printers: $($installedPrinters.Count)"
        exit 0  # No issues - no remediation needed
    }
}
catch {
    Write-Output "ERROR during detection: $($_.Exception.Message)"
    Write-Output "Stack trace: $($_.ScriptStackTrace)"
    exit 1  # Error occurred - trigger remediation to be safe
}
#EndRegion
