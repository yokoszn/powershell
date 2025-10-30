# Printer Remapping Script with GUI
# This script unmaps old printers and remaps them based on configuration

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Get script directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptPath "PrinterConfig.json"
$logPath = Join-Path $scriptPath "PrinterRemap.log"

# Logging function
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Add-Content -Path $logPath -Value $logMessage
    Write-Host $logMessage
}

# Load configuration
function Load-Config {
    try {
        if (-not (Test-Path $configPath)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Configuration file not found at: $configPath",
                "Configuration Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            return $null
        }

        $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
        Write-Log "Configuration loaded successfully"
        return $config
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Error loading configuration: $($_.Exception.Message)",
            "Configuration Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        Write-Log "ERROR: Failed to load configuration - $($_.Exception.Message)"
        return $null
    }
}

# Test printer connectivity
function Test-PrinterConnectivity {
    param([string]$IP, [string]$Name)

    try {
        Write-Log "Pinging $Name at $IP..."
        $ping = Test-Connection -ComputerName $IP -Count 2 -Quiet -ErrorAction Stop

        if ($ping) {
            Write-Log "SUCCESS: $Name ($IP) is reachable"
            return $true
        }
        else {
            Write-Log "WARNING: $Name ($IP) is not reachable"
            return $false
        }
    }
    catch {
        Write-Log "ERROR: Failed to ping $Name ($IP) - $($_.Exception.Message)"
        return $false
    }
}

# Remove existing printers
function Remove-ExistingPrinters {
    param([System.Windows.Forms.ProgressBar]$ProgressBar, [System.Windows.Forms.Label]$StatusLabel)

    try {
        Write-Log "Starting printer removal process..."
        $StatusLabel.Text = "Retrieving current printers..."
        $printers = Get-Printer | Where-Object { $_.Type -eq "Connection" }

        if ($printers.Count -eq 0) {
            Write-Log "No network printers found to remove"
            return $true
        }

        $count = 0
        $total = $printers.Count

        foreach ($printer in $printers) {
            $count++
            $percentage = [int](($count / $total) * 50)  # First 50% for removal
            $ProgressBar.Value = $percentage
            $StatusLabel.Text = "Removing: $($printer.Name) ($count of $total)"
            [System.Windows.Forms.Application]::DoEvents()

            try {
                Remove-Printer -Name $printer.Name -ErrorAction Stop
                Write-Log "Removed printer: $($printer.Name)"
            }
            catch {
                Write-Log "ERROR: Failed to remove printer $($printer.Name) - $($_.Exception.Message)"
            }

            Start-Sleep -Milliseconds 200
        }

        Write-Log "Printer removal completed. Removed $count printer(s)"
        return $true
    }
    catch {
        Write-Log "ERROR: Printer removal process failed - $($_.Exception.Message)"
        return $false
    }
}

# Add new printers
function Add-NewPrinters {
    param(
        [object]$Config,
        [System.Windows.Forms.ProgressBar]$ProgressBar,
        [System.Windows.Forms.Label]$StatusLabel
    )

    try {
        Write-Log "Starting printer installation process..."
        $successCount = 0
        $failCount = 0
        $count = 0
        $total = $Config.Printers.Count

        foreach ($printer in $Config.Printers) {
            $count++
            $basePercentage = 50  # Start at 50% (after removal)
            $percentage = $basePercentage + [int](($count / $total) * 50)
            $ProgressBar.Value = $percentage

            $StatusLabel.Text = "Testing connectivity: $($printer.Name) ($count of $total)"
            [System.Windows.Forms.Application]::DoEvents()

            # Test connectivity first
            $isReachable = Test-PrinterConnectivity -IP $printer.IP -Name $printer.Name

            if (-not $isReachable) {
                Write-Log "WARNING: Skipping $($printer.Name) - printer is not reachable"
                $failCount++
                continue
            }

            # Add printer
            $printerPath = "$($Config.UniversalPrintPath)\$($printer.ShareName)"
            $StatusLabel.Text = "Installing: $($printer.Name) ($count of $total)"
            [System.Windows.Forms.Application]::DoEvents()

            try {
                Add-Printer -ConnectionName $printerPath -ErrorAction Stop
                Write-Log "SUCCESS: Installed printer $($printer.Name) from $printerPath"
                $successCount++
            }
            catch {
                Write-Log "ERROR: Failed to install $($printer.Name) - $($_.Exception.Message)"
                $failCount++
            }

            Start-Sleep -Milliseconds 200
        }

        Write-Log "Printer installation completed. Success: $successCount, Failed: $failCount"
        return @{
            Success = $successCount
            Failed = $failCount
        }
    }
    catch {
        Write-Log "ERROR: Printer installation process failed - $($_.Exception.Message)"
        return @{
            Success = 0
            Failed = $total
        }
    }
}

# Main GUI Form
function Show-PrinterRemapGUI {
    # Create form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Printer Remapping Tool"
    $form.Size = New-Object System.Drawing.Size(500, 300)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false

    # Title Label
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $titleLabel.Size = New-Object System.Drawing.Size(460, 30)
    $titleLabel.Text = "Printer Remapping Utility"
    $titleLabel.Font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($titleLabel)

    # Info Label
    $infoLabel = New-Object System.Windows.Forms.Label
    $infoLabel.Location = New-Object System.Drawing.Point(20, 60)
    $infoLabel.Size = New-Object System.Drawing.Size(460, 40)
    $infoLabel.Text = "This tool will unmap existing network printers and remap them based on the configuration file."
    $form.Controls.Add($infoLabel)

    # Status Label
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Location = New-Object System.Drawing.Point(20, 110)
    $statusLabel.Size = New-Object System.Drawing.Size(460, 20)
    $statusLabel.Text = "Ready to begin..."
    $form.Controls.Add($statusLabel)

    # Progress Bar
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(20, 140)
    $progressBar.Size = New-Object System.Drawing.Size(460, 30)
    $progressBar.Style = "Continuous"
    $progressBar.Minimum = 0
    $progressBar.Maximum = 100
    $progressBar.Value = 0
    $form.Controls.Add($progressBar)

    # Start Button
    $startButton = New-Object System.Windows.Forms.Button
    $startButton.Location = New-Object System.Drawing.Point(150, 190)
    $startButton.Size = New-Object System.Drawing.Size(100, 35)
    $startButton.Text = "Start"
    $startButton.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)

    # Close Button
    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Location = New-Object System.Drawing.Point(260, 190)
    $closeButton.Size = New-Object System.Drawing.Size(100, 35)
    $closeButton.Text = "Close"
    $closeButton.Font = New-Object System.Drawing.Font("Arial", 10)
    $closeButton.Enabled = $false

    # Start Button Click Event
    $startButton.Add_Click({
        Write-Log "=== Printer Remapping Process Started ==="
        $startButton.Enabled = $false
        $progressBar.Value = 0

        # Load configuration
        $config = Load-Config
        if ($null -eq $config) {
            $statusLabel.Text = "Failed to load configuration"
            $startButton.Enabled = $true
            return
        }

        # Remove existing printers
        $statusLabel.Text = "Removing existing printers..."
        [System.Windows.Forms.Application]::DoEvents()
        Remove-ExistingPrinters -ProgressBar $progressBar -StatusLabel $statusLabel

        # Add new printers
        $statusLabel.Text = "Adding new printers..."
        [System.Windows.Forms.Application]::DoEvents()
        $result = Add-NewPrinters -Config $config -ProgressBar $progressBar -StatusLabel $statusLabel

        # Complete
        $progressBar.Value = 100
        $statusLabel.Text = "Completed! Success: $($result.Success), Failed: $($result.Failed)"
        Write-Log "=== Printer Remapping Process Completed ==="

        $closeButton.Enabled = $true

        # Show completion message
        [System.Windows.Forms.MessageBox]::Show(
            "Printer remapping completed!`n`nSuccessfully installed: $($result.Success)`nFailed: $($result.Failed)`n`nCheck the log file for details: $logPath",
            "Process Complete",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    })

    # Close Button Click Event
    $closeButton.Add_Click({
        $form.Close()
    })

    $form.Controls.Add($startButton)
    $form.Controls.Add($closeButton)

    # Show form
    $form.ShowDialog()
}

# Run the GUI
Write-Log "=== Script Started ==="
Show-PrinterRemapGUI
Write-Log "=== Script Ended ==="
