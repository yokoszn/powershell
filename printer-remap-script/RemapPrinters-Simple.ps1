# Simple Universal Print Remapping Script
# Removes existing printers and remaps using Universal Print
# Uses UPPrinterInstaller.exe for installation

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Configuration
$configFile = Join-Path $PSScriptRoot "PrinterShares.json"
$logFile = Join-Path $env:LOCALAPPDATA "PrinterRemap\remap_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Ensure log directory exists
$logDir = Split-Path $logFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Simple logging
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage
}

# Get printer shares from Microsoft Graph (if available)
function Get-PrinterSharesFromGraph {
    try {
        # Check if Microsoft.Graph module is available
        if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.DeviceManagement.Actions)) {
            Write-Log "Microsoft Graph module not available - will use manual input"
            return $null
        }

        Import-Module Microsoft.Graph.DeviceManagement.Actions -ErrorAction Stop

        # Try to connect (will use existing session if available)
        $context = Get-MgContext -ErrorAction SilentlyContinue
        if (-not $context) {
            Write-Log "Connecting to Microsoft Graph..."
            Connect-MgGraph -Scopes "Printer.Read.All", "PrinterShare.ReadBasic.All" -ErrorAction Stop
        }

        Write-Log "Retrieving printer shares from Microsoft Graph..."
        $shares = Get-MgPrintShare -All -ErrorAction Stop

        Write-Log "Found $($shares.Count) printer shares"
        return $shares
    }
    catch {
        Write-Log "Failed to get shares from Graph: $($_.Exception.Message)"
        return $null
    }
}

# Load printer shares from config file
function Get-PrinterSharesFromConfig {
    try {
        if (Test-Path $configFile) {
            Write-Log "Loading printer shares from config file..."
            $config = Get-Content $configFile -Raw | ConvertFrom-Json
            return $config.PrinterShares
        }
    }
    catch {
        Write-Log "Failed to load config: $($_.Exception.Message)"
    }
    return $null
}

# Remove existing printers
function Remove-ExistingPrinters {
    param([System.Windows.Forms.ListBox]$StatusBox)

    try {
        $StatusBox.Items.Add("Removing existing network printers...")

        $printers = Get-Printer | Where-Object { $_.Type -eq "Connection" }

        if ($printers.Count -eq 0) {
            $StatusBox.Items.Add("No network printers to remove")
            Write-Log "No network printers found"
            return $true
        }

        foreach ($printer in $printers) {
            try {
                Remove-Printer -Name $printer.Name -ErrorAction Stop
                $StatusBox.Items.Add("  Removed: $($printer.Name)")
                Write-Log "Removed printer: $($printer.Name)"
            }
            catch {
                $StatusBox.Items.Add("  Failed: $($printer.Name) - $($_.Exception.Message)")
                Write-Log "Failed to remove $($printer.Name): $($_.Exception.Message)"
            }
        }

        return $true
    }
    catch {
        $StatusBox.Items.Add("Error removing printers: $($_.Exception.Message)")
        Write-Log "Error in Remove-ExistingPrinters: $($_.Exception.Message)"
        return $false
    }
}

# Install printer using UPPrinterInstaller.exe
function Install-UniversalPrintPrinter {
    param(
        [string]$PrinterShareId,
        [string]$DisplayName,
        [System.Windows.Forms.ListBox]$StatusBox
    )

    try {
        # Find UPPrinterInstaller.exe
        $installerPaths = @(
            "$env:SystemRoot\System32\UPPrinterInstaller.exe",
            "$env:ProgramFiles\Windows NT\Printer\UPPrinterInstaller.exe",
            "C:\Windows\System32\UPPrinterInstaller.exe"
        )

        $installerPath = $null
        foreach ($path in $installerPaths) {
            if (Test-Path $path) {
                $installerPath = $path
                break
            }
        }

        if (-not $installerPath) {
            $StatusBox.Items.Add("  ERROR: UPPrinterInstaller.exe not found")
            Write-Log "UPPrinterInstaller.exe not found in expected locations"

            # Fallback: Try using Add-Printer with Universal Print URL
            try {
                $printerUrl = "https://universalprint.windows.net/$PrinterShareId"
                Add-Printer -ConnectionName $printerUrl -ErrorAction Stop
                $StatusBox.Items.Add("  Installed via Add-Printer: $DisplayName")
                Write-Log "Installed $DisplayName using Add-Printer (fallback)"
                return $true
            }
            catch {
                $StatusBox.Items.Add("  Failed: $($_.Exception.Message)")
                Write-Log "Failed to install $DisplayName using fallback: $($_.Exception.Message)"
                return $false
            }
        }

        # Use UPPrinterInstaller.exe
        $StatusBox.Items.Add("  Installing via UPPrinterInstaller...")
        Write-Log "Installing $DisplayName using UPPrinterInstaller.exe with share ID: $PrinterShareId"

        # Get OMA-DM Account ID from scheduled tasks
        $omaDmAccountId = $null
        try {
            $entMgmtTasks = Get-ScheduledTask -TaskPath "\Microsoft\Windows\EnterpriseMgmt\*" -ErrorAction SilentlyContinue
            if ($entMgmtTasks) {
                # Extract GUID from task path (e.g., \Microsoft\Windows\EnterpriseMgmt\{GUID}\)
                $firstTask = $entMgmtTasks | Select-Object -First 1
                if ($firstTask.TaskPath -match '\\EnterpriseMgmt\\(.+?)\\') {
                    $omaDmAccountId = $matches[1]
                    Write-Log "Found OMA-DM Account ID: $omaDmAccountId"
                }
            }
        }
        catch {
            Write-Log "Could not retrieve OMA-DM Account ID from scheduled tasks: $($_.Exception.Message)"
        }

        # Generate correlation ID
        $correlationId = [guid]::NewGuid().ToString()
        Write-Log "Generated correlation ID: $correlationId"

        # Build arguments
        # Note: Parameter casing matters - use lowercase for printershareId
        $arguments = "/install /printershareId:$PrinterShareId"

        # Add OMA-DM account ID if available (required for Intune-managed devices)
        if ($omaDmAccountId) {
            $arguments += " /omadmaccountid:$omaDmAccountId"
        }

        # Add correlation ID
        $arguments += " /correlationid:$correlationId"

        Write-Log "Installer arguments: $arguments"

        # Run the installer
        $process = Start-Process -FilePath $installerPath -ArgumentList $arguments -Wait -PassThru -NoNewWindow

        if ($process.ExitCode -eq 0) {
            $StatusBox.Items.Add("  Installed: $DisplayName")
            Write-Log "Successfully installed $DisplayName"
            return $true
        }
        else {
            $StatusBox.Items.Add("  Failed with exit code: $($process.ExitCode)")
            Write-Log "UPPrinterInstaller failed with exit code: $($process.ExitCode)"
            Write-Log "  Arguments used: $arguments"
            return $false
        }
    }
    catch {
        $StatusBox.Items.Add("  Error: $($_.Exception.Message)")
        Write-Log "Error installing $DisplayName: $($_.Exception.Message)"
        return $false
    }
}

# Main GUI
function Show-RemapGUI {
    Write-Log "=== Universal Print Remapping Started ==="

    # Create form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Universal Print Remapper"
    $form.Size = New-Object System.Drawing.Size(600, 550)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false

    # Title
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $titleLabel.Size = New-Object System.Drawing.Size(560, 30)
    $titleLabel.Text = "Universal Print Remapper"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($titleLabel)

    # Instructions
    $infoLabel = New-Object System.Windows.Forms.Label
    $infoLabel.Location = New-Object System.Drawing.Point(20, 60)
    $infoLabel.Size = New-Object System.Drawing.Size(560, 40)
    $infoLabel.Text = "Select Universal Print shares to install. Existing network printers will be removed."
    $form.Controls.Add($infoLabel)

    # Printer shares label
    $sharesLabel = New-Object System.Windows.Forms.Label
    $sharesLabel.Location = New-Object System.Drawing.Point(20, 110)
    $sharesLabel.Size = New-Object System.Drawing.Size(200, 20)
    $sharesLabel.Text = "Available Printer Shares:"
    $form.Controls.Add($sharesLabel)

    # Load shares button
    $loadButton = New-Object System.Windows.Forms.Button
    $loadButton.Location = New-Object System.Drawing.Point(450, 105)
    $loadButton.Size = New-Object System.Drawing.Size(120, 30)
    $loadButton.Text = "Load from Graph"
    $form.Controls.Add($loadButton)

    # Printer shares listbox (multi-select)
    $sharesListBox = New-Object System.Windows.Forms.CheckedListBox
    $sharesListBox.Location = New-Object System.Drawing.Point(20, 140)
    $sharesListBox.Size = New-Object System.Drawing.Size(550, 120)
    $sharesListBox.CheckOnClick = $true
    $form.Controls.Add($sharesListBox)

    # Status label
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Location = New-Object System.Drawing.Point(20, 270)
    $statusLabel.Size = New-Object System.Drawing.Size(200, 20)
    $statusLabel.Text = "Status:"
    $form.Controls.Add($statusLabel)

    # Status listbox
    $statusListBox = New-Object System.Windows.Forms.ListBox
    $statusListBox.Location = New-Object System.Drawing.Point(20, 295)
    $statusListBox.Size = New-Object System.Drawing.Size(550, 150)
    $statusListBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    $form.Controls.Add($statusListBox)

    # Remap button
    $remapButton = New-Object System.Windows.Forms.Button
    $remapButton.Location = New-Object System.Drawing.Point(350, 460)
    $remapButton.Size = New-Object System.Drawing.Size(100, 35)
    $remapButton.Text = "Remap"
    $remapButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $remapButton.Enabled = $false
    $form.Controls.Add($remapButton)

    # Close button
    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Location = New-Object System.Drawing.Point(470, 460)
    $closeButton.Size = New-Object System.Drawing.Size(100, 35)
    $closeButton.Text = "Close"
    $closeButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.Controls.Add($closeButton)

    # Load button click
    $loadButton.Add_Click({
        $sharesListBox.Items.Clear()
        $statusListBox.Items.Clear()
        $statusListBox.Items.Add("Loading printer shares...")
        [System.Windows.Forms.Application]::DoEvents()

        # Try Graph API first
        $shares = Get-PrinterSharesFromGraph

        # If Graph fails, try config file
        if (-not $shares) {
            $statusListBox.Items.Add("Trying config file...")
            $shares = Get-PrinterSharesFromConfig
        }

        if ($shares -and $shares.Count -gt 0) {
            foreach ($share in $shares) {
                # Store both display name and ID
                $item = New-Object PSObject -Property @{
                    DisplayName = $share.DisplayName
                    Id = $share.Id
                }
                $sharesListBox.Items.Add($item) | Out-Null
            }
            $sharesListBox.DisplayMember = "DisplayName"
            $statusListBox.Items.Add("Loaded $($shares.Count) printer shares")
            $remapButton.Enabled = $true
        }
        else {
            $statusListBox.Items.Add("No shares found. Create PrinterShares.json manually.")
            $statusListBox.Items.Add("Example format:")
            $statusListBox.Items.Add('  {"PrinterShares": [{"DisplayName":"Printer1","Id":"share-id-123"}]}')
        }
    })

    # Remap button click
    $remapButton.Add_Click({
        $remapButton.Enabled = $false
        $loadButton.Enabled = $false
        $statusListBox.Items.Clear()

        Write-Log "Starting remap process..."

        # Get selected shares
        $selectedShares = @()
        for ($i = 0; $i -lt $sharesListBox.CheckedItems.Count; $i++) {
            $selectedShares += $sharesListBox.CheckedItems[$i]
        }

        if ($selectedShares.Count -eq 0) {
            $statusListBox.Items.Add("No printers selected!")
            $remapButton.Enabled = $true
            $loadButton.Enabled = $true
            return
        }

        $statusListBox.Items.Add("Selected $($selectedShares.Count) printer(s)")
        Write-Log "User selected $($selectedShares.Count) printer shares"

        # Step 1: Remove existing printers
        $statusListBox.Items.Add("")
        $statusListBox.Items.Add("=== Removing Existing Printers ===")
        Remove-ExistingPrinters -StatusBox $statusListBox
        Start-Sleep -Seconds 2

        # Step 2: Install selected printers
        $statusListBox.Items.Add("")
        $statusListBox.Items.Add("=== Installing Universal Print Printers ===")

        $successCount = 0
        $failCount = 0

        foreach ($share in $selectedShares) {
            $statusListBox.Items.Add("Installing: $($share.DisplayName)")
            [System.Windows.Forms.Application]::DoEvents()

            $success = Install-UniversalPrintPrinter -PrinterShareId $share.Id -DisplayName $share.DisplayName -StatusBox $statusListBox

            if ($success) {
                $successCount++
            }
            else {
                $failCount++
            }

            Start-Sleep -Milliseconds 500
        }

        # Summary
        $statusListBox.Items.Add("")
        $statusListBox.Items.Add("=== Complete ===")
        $statusListBox.Items.Add("Success: $successCount | Failed: $failCount")
        $statusListBox.Items.Add("Log file: $logFile")

        Write-Log "Remap complete. Success: $successCount, Failed: $failCount"
        Write-Log "=== Remapping Finished ==="

        [System.Windows.Forms.MessageBox]::Show(
            "Remapping complete!`n`nSuccess: $successCount`nFailed: $failCount`n`nLog: $logFile",
            "Complete",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )

        $remapButton.Enabled = $true
        $loadButton.Enabled = $true
    })

    # Close button click
    $closeButton.Add_Click({
        $form.Close()
    })

    # Auto-load shares on startup
    $loadButton.PerformClick()

    # Show form
    $form.ShowDialog()
}

# Run the GUI
Show-RemapGUI
