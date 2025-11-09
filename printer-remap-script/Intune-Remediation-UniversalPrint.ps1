# Universal Print Remediation Script for Intune
# This script installs Universal Print printers silently (no GUI)

$ErrorActionPreference = "Stop"

# Script configuration
$scriptPath = $PSScriptRoot
$configPath = Join-Path $scriptPath "PrinterConfig-UniversalPrint.json"
$logPath = Join-Path $scriptPath "PrinterRemap-UniversalPrint-Intune.log"

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logPath -Value $logMessage -ErrorAction SilentlyContinue
    Write-Output $logMessage
}

# Check and install Universal Print Management module
function Initialize-UniversalPrintModule {
    try {
        Write-Log "Checking for UniversalPrintManagement module..."

        $module = Get-Module -ListAvailable -Name UniversalPrintManagement

        if (-not $module) {
            Write-Log "Installing UniversalPrintManagement module..." "WARNING"
            Install-Module -Name UniversalPrintManagement -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            Write-Log "Module installed successfully" "SUCCESS"
        }

        Import-Module UniversalPrintManagement -ErrorAction Stop
        Write-Log "Module loaded successfully" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to initialize module: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Main remediation logic
try {
    Write-Log "=== Universal Print Remediation Started ==="

    # Initialize module
    if (-not (Initialize-UniversalPrintModule)) {
        Write-Log "Cannot continue without UniversalPrintManagement module" "ERROR"
        exit 1
    }

    # Load configuration
    if (-not (Test-Path $configPath)) {
        Write-Log "Configuration file not found: $configPath" "ERROR"
        exit 1
    }

    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    Write-Log "Configuration loaded successfully"

    # Connect to Universal Print (Interactive - will use current user context)
    Write-Log "Connecting to Universal Print..."

    try {
        # In Intune user context, use interactive auth
        Connect-UPService -ErrorAction Stop
        Write-Log "Connected to Universal Print successfully" "SUCCESS"
    }
    catch {
        Write-Log "Failed to connect to Universal Print: $($_.Exception.Message)" "ERROR"
        exit 1
    }

    # Get available shares
    Write-Log "Retrieving Universal Print shares..."
    $sharesResult = Get-UPPrinterShare -ErrorAction Stop
    $availableShares = $sharesResult.results

    Write-Log "Found $($availableShares.Count) Universal Print shares"

    # Remove existing network printers if configured
    if ($config.Settings.RemoveExistingPrinters) {
        Write-Log "Removing existing network printers..."
        $existingPrinters = Get-Printer | Where-Object { $_.Type -eq "Connection" }

        foreach ($printer in $existingPrinters) {
            try {
                Remove-Printer -Name $printer.Name -ErrorAction Stop
                Write-Log "Removed: $($printer.Name)" "SUCCESS"
            }
            catch {
                Write-Log "Failed to remove $($printer.Name): $($_.Exception.Message)" "WARNING"
            }
        }
    }

    # Install Universal Print printers
    Write-Log "Installing Universal Print printers..."
    $successCount = 0
    $failCount = 0

    $enabledPrinters = $config.Printers | Where-Object { $_.Enabled -eq $true }

    foreach ($printer in $enabledPrinters) {
        # Find the printer share
        $share = $null

        if (-not [string]::IsNullOrEmpty($printer.UniversalPrintShareId)) {
            $share = $availableShares | Where-Object { $_.Id -eq $printer.UniversalPrintShareId }
        }

        if (-not $share -and -not [string]::IsNullOrEmpty($printer.UniversalPrintShareName)) {
            $share = $availableShares | Where-Object { $_.DisplayName -eq $printer.UniversalPrintShareName }
        }

        if (-not $share) {
            Write-Log "Share not found for: $($printer.Name)" "WARNING"
            $failCount++
            continue
        }

        # Install the printer
        try {
            $printerPath = "https://universalprint.windows.net/$($share.Id)"
            Add-Printer -ConnectionName $printerPath -ErrorAction Stop

            Write-Log "Installed: $($printer.Name) from share: $($share.DisplayName)" "SUCCESS"
            $successCount++

            # Set as default if configured
            if ($config.Settings.SetDefaultPrinter -eq $printer.Name) {
                Start-Sleep -Seconds 2
                $installedPrinter = Get-Printer | Where-Object { $_.Name -like "*$($share.DisplayName)*" } | Select-Object -First 1
                if ($installedPrinter) {
                    Set-PrinterAsDefault -Name $installedPrinter.Name -ErrorAction Stop
                    Write-Log "Set as default: $($printer.Name)" "SUCCESS"
                }
            }
        }
        catch {
            Write-Log "Failed to install $($printer.Name): $($_.Exception.Message)" "ERROR"
            $failCount++

            # Retry if configured
            if ($config.Settings.RetryFailedPrinters) {
                for ($retry = 1; $retry -le $config.Settings.MaxRetries; $retry++) {
                    Write-Log "Retry $retry for $($printer.Name)..." "WARNING"
                    Start-Sleep -Seconds 2

                    try {
                        Add-Printer -ConnectionName $printerPath -ErrorAction Stop
                        Write-Log "Retry successful for $($printer.Name)" "SUCCESS"
                        $failCount--
                        $successCount++
                        break
                    }
                    catch {
                        Write-Log "Retry $retry failed: $($_.Exception.Message)" "ERROR"
                    }
                }
            }
        }

        Start-Sleep -Milliseconds $config.Settings.InstallDelayMs
    }

    # Disconnect
    try {
        Disconnect-UPService -ErrorAction SilentlyContinue
        Write-Log "Disconnected from Universal Print"
    }
    catch {
        Write-Log "Error during disconnect: $($_.Exception.Message)" "WARNING"
    }

    # Summary
    Write-Log "=== Remediation Completed ==="
    Write-Log "Success: $successCount | Failed: $failCount"

    # Exit code
    if ($failCount -eq 0) {
        Write-Log "Remediation successful" "SUCCESS"
        exit 0
    }
    elseif ($successCount -gt 0) {
        Write-Log "Remediation partially successful" "WARNING"
        exit 0
    }
    else {
        Write-Log "Remediation failed" "ERROR"
        exit 1
    }
}
catch {
    Write-Log "Remediation failed with error: $($_.Exception.Message)" "ERROR"

    # Try to disconnect
    try {
        Disconnect-UPService -ErrorAction SilentlyContinue
    }
    catch { }

    exit 1
}
