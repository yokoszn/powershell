# Enhanced Printer Remapping Script with Reporting and Usage Tracking
# Supports CSV export, email reports, webhooks, and usage analytics

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Get script directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptPath "PrinterConfig-Enhanced.json"
$logPath = Join-Path $scriptPath "PrinterRemap.log"

# Global variables
$script:config = $null
$script:executionReport = @{
    Timestamp = Get-Date
    ComputerName = $env:COMPUTERNAME
    UserName = $env:USERNAME
    Domain = $env:USERDOMAIN
    Success = 0
    Failed = 0
    Skipped = 0
    RemovedPrinters = @()
    InstalledPrinters = @()
    FailedPrinters = @()
    Duration = 0
}

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
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
        Write-Log "Failed to load configuration - $($_.Exception.Message)" "ERROR"
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
            Write-Log "$Name ($IP) is reachable" "SUCCESS"
            return $true
        }
        else {
            Write-Log "$Name ($IP) is not reachable" "WARNING"
            return $false
        }
    }
    catch {
        Write-Log "Failed to ping $Name ($IP) - $($_.Exception.Message)" "ERROR"
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
            $percentage = [int](($count / $total) * 50)
            $ProgressBar.Value = $percentage
            $StatusLabel.Text = "Removing: $($printer.Name) ($count of $total)"
            [System.Windows.Forms.Application]::DoEvents()

            try {
                Remove-Printer -Name $printer.Name -ErrorAction Stop
                Write-Log "Removed printer: $($printer.Name)" "SUCCESS"
                $script:executionReport.RemovedPrinters += $printer.Name
            }
            catch {
                Write-Log "Failed to remove printer $($printer.Name) - $($_.Exception.Message)" "ERROR"
            }

            Start-Sleep -Milliseconds 200
        }

        Write-Log "Printer removal completed. Removed $count printer(s)"
        return $true
    }
    catch {
        Write-Log "Printer removal process failed - $($_.Exception.Message)" "ERROR"
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
        $count = 0
        $total = $Config.Printers.Count

        foreach ($printer in $Config.Printers) {
            $count++
            $basePercentage = 50
            $percentage = $basePercentage + [int](($count / $total) * 50)
            $ProgressBar.Value = $percentage

            $StatusLabel.Text = "Testing connectivity: $($printer.Name) ($count of $total)"
            [System.Windows.Forms.Application]::DoEvents()

            # Test connectivity first
            $isReachable = Test-PrinterConnectivity -IP $printer.IP -Name $printer.Name

            if (-not $isReachable) {
                Write-Log "Skipping $($printer.Name) - printer is not reachable" "WARNING"
                $script:executionReport.Skipped++
                $script:executionReport.FailedPrinters += @{
                    Name = $printer.Name
                    IP = $printer.IP
                    Reason = "Not reachable (ping failed)"
                }
                continue
            }

            # Add printer
            $printerPath = "$($Config.UniversalPrintPath)\$($printer.ShareName)"
            $StatusLabel.Text = "Installing: $($printer.Name) ($count of $total)"
            [System.Windows.Forms.Application]::DoEvents()

            try {
                Add-Printer -ConnectionName $printerPath -ErrorAction Stop
                Write-Log "Installed printer $($printer.Name) from $printerPath" "SUCCESS"
                $script:executionReport.Success++
                $script:executionReport.InstalledPrinters += @{
                    Name = $printer.Name
                    IP = $printer.IP
                    Path = $printerPath
                }
            }
            catch {
                Write-Log "Failed to install $($printer.Name) - $($_.Exception.Message)" "ERROR"
                $script:executionReport.Failed++
                $script:executionReport.FailedPrinters += @{
                    Name = $printer.Name
                    IP = $printer.IP
                    Reason = $_.Exception.Message
                }
            }

            Start-Sleep -Milliseconds 200
        }

        Write-Log "Printer installation completed. Success: $($script:executionReport.Success), Failed: $($script:executionReport.Failed), Skipped: $($script:executionReport.Skipped)"
        return $script:executionReport
    }
    catch {
        Write-Log "Printer installation process failed - $($_.Exception.Message)" "ERROR"
        return $script:executionReport
    }
}

# Export report to CSV
function Export-CSVReport {
    param([object]$Report)

    try {
        if (-not $script:config.Reporting.EnableCSVExport) {
            Write-Log "CSV export is disabled in configuration"
            return
        }

        $csvPath = $script:config.Reporting.CSVPath
        if (-not (Test-Path $csvPath)) {
            Write-Log "Creating CSV export directory: $csvPath"
            New-Item -ItemType Directory -Path $csvPath -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $csvFile = Join-Path $csvPath "PrinterRemap_$($Report.ComputerName)_$timestamp.csv"

        $reportData = [PSCustomObject]@{
            Timestamp = $Report.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
            ComputerName = $Report.ComputerName
            UserName = $Report.UserName
            Domain = $Report.Domain
            SuccessCount = $Report.Success
            FailedCount = $Report.Failed
            SkippedCount = $Report.Skipped
            RemovedPrinters = ($Report.RemovedPrinters -join "; ")
            InstalledPrinters = (($Report.InstalledPrinters | ForEach-Object { $_.Name }) -join "; ")
            FailedPrinters = (($Report.FailedPrinters | ForEach-Object { "$($_.Name) ($($_.Reason))" }) -join "; ")
            DurationSeconds = $Report.Duration
        }

        $reportData | Export-Csv -Path $csvFile -NoTypeInformation -Append
        Write-Log "CSV report exported to: $csvFile" "SUCCESS"
    }
    catch {
        Write-Log "Failed to export CSV report - $($_.Exception.Message)" "ERROR"
    }
}

# Update usage tracking
function Update-UsageTracking {
    param([object]$Report)

    try {
        if (-not $script:config.Reporting.EnableUsageTracking) {
            Write-Log "Usage tracking is disabled in configuration"
            return
        }

        $trackingPath = $script:config.Reporting.UsageTrackingPath
        if (-not (Test-Path $trackingPath)) {
            Write-Log "Creating usage tracking directory: $trackingPath"
            New-Item -ItemType Directory -Path $trackingPath -Force | Out-Null
        }

        $trackingFile = Join-Path $trackingPath "PrinterRemapUsage.csv"

        $usageData = [PSCustomObject]@{
            Timestamp = $Report.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
            ComputerName = $Report.ComputerName
            UserName = $Report.UserName
            Domain = $Report.Domain
            Success = $Report.Success
            Failed = $Report.Failed
            Skipped = $Report.Skipped
            TotalPrinters = $Report.Success + $Report.Failed + $Report.Skipped
            DurationSeconds = $Report.Duration
        }

        # Append to tracking file
        if (Test-Path $trackingFile) {
            $usageData | Export-Csv -Path $trackingFile -NoTypeInformation -Append
        }
        else {
            $usageData | Export-Csv -Path $trackingFile -NoTypeInformation
        }

        Write-Log "Usage tracking updated: $trackingFile" "SUCCESS"

        # Generate usage summary if more than 10 entries exist
        $allUsage = Import-Csv $trackingFile
        if ($allUsage.Count -ge 10) {
            $summaryFile = Join-Path $trackingPath "UsageSummary.txt"
            $summary = @"
=== Printer Remap Usage Summary ===
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Total Executions: $($allUsage.Count)

Top 5 Users by Usage:
$($allUsage | Group-Object UserName | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object { "  $($_.Name): $($_.Count) times" } | Out-String)

Top 5 Computers by Usage:
$($allUsage | Group-Object ComputerName | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object { "  $($_.Name): $($_.Count) times" } | Out-String)

Success Rate:
  Total Successful Printers: $(($allUsage | Measure-Object -Property Success -Sum).Sum)
  Total Failed Printers: $(($allUsage | Measure-Object -Property Failed -Sum).Sum)
  Total Skipped Printers: $(($allUsage | Measure-Object -Property Skipped -Sum).Sum)

Average Duration: $([math]::Round(($allUsage | Measure-Object -Property DurationSeconds -Average).Average, 2)) seconds
"@
            $summary | Out-File -FilePath $summaryFile -Force
            Write-Log "Usage summary generated: $summaryFile" "SUCCESS"
        }
    }
    catch {
        Write-Log "Failed to update usage tracking - $($_.Exception.Message)" "ERROR"
    }
}

# Send email report
function Send-EmailReport {
    param([object]$Report)

    try {
        if (-not $script:config.Reporting.EnableEmailReport) {
            Write-Log "Email reporting is disabled in configuration"
            return
        }

        $emailSettings = $script:config.Reporting.EmailSettings

        # Check if we should only email on failures
        if ($emailSettings.OnlyEmailOnFailure -and $Report.Failed -eq 0) {
            Write-Log "No failures detected - skipping email (OnlyEmailOnFailure=true)"
            return
        }

        $subject = "Printer Remap Report - $($Report.ComputerName) - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"

        $body = @"
<html>
<body style='font-family: Arial, sans-serif;'>
<h2>Printer Remapping Report</h2>
<table border='1' cellpadding='5' cellspacing='0' style='border-collapse: collapse;'>
<tr><td><strong>Timestamp:</strong></td><td>$($Report.Timestamp)</td></tr>
<tr><td><strong>Computer:</strong></td><td>$($Report.ComputerName)</td></tr>
<tr><td><strong>User:</strong></td><td>$($Report.Domain)\$($Report.UserName)</td></tr>
<tr><td><strong>Duration:</strong></td><td>$($Report.Duration) seconds</td></tr>
<tr><td><strong>Successfully Installed:</strong></td><td style='color: green;'>$($Report.Success)</td></tr>
<tr><td><strong>Failed:</strong></td><td style='color: red;'>$($Report.Failed)</td></tr>
<tr><td><strong>Skipped:</strong></td><td style='color: orange;'>$($Report.Skipped)</td></tr>
</table>

<h3>Removed Printers:</h3>
<ul>
$(($Report.RemovedPrinters | ForEach-Object { "<li>$_</li>" }) -join "`n")
</ul>

<h3>Installed Printers:</h3>
<ul>
$(($Report.InstalledPrinters | ForEach-Object { "<li>$($_.Name) - $($_.Path)</li>" }) -join "`n")
</ul>

$(if ($Report.FailedPrinters.Count -gt 0) {
"<h3 style='color: red;'>Failed Printers:</h3>
<ul>
$(($Report.FailedPrinters | ForEach-Object { "<li>$($_.Name) ($($_.IP)) - $($_.Reason)</li>" }) -join "`n")
</ul>"
})

<p><em>This is an automated report from the Printer Remapping Script.</em></p>
</body>
</html>
"@

        $mailParams = @{
            SmtpServer = $emailSettings.SMTPServer
            Port = $emailSettings.SMTPPort
            From = $emailSettings.FromAddress
            To = $emailSettings.ToAddress
            Subject = $subject
            Body = $body
            BodyAsHtml = $true
            UseSsl = $emailSettings.UseSSL
        }

        if ($emailSettings.RequiresAuth) {
            # Note: In production, use secure credential storage
            Write-Log "Email requires authentication - credentials must be configured separately" "WARNING"
            # $mailParams.Credential = Get-Credential
        }

        Send-MailMessage @mailParams
        Write-Log "Email report sent to $($emailSettings.ToAddress)" "SUCCESS"
    }
    catch {
        Write-Log "Failed to send email report - $($_.Exception.Message)" "ERROR"
    }
}

# Send report to central webhook handler
function Send-WebhookReport {
    param([object]$Report)

    try {
        if (-not $script:config.Reporting.EnableWebhook) {
            Write-Log "Webhook reporting is disabled in configuration"
            return
        }

        $webhookURL = $script:config.Reporting.WebhookURL

        # Send full report as JSON to central handler
        # The handler will process Autotask, IT Glue, Slack, Teams, etc.
        # NO API KEYS IN THIS SCRIPT!
        $payload = @{
            Timestamp = $Report.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
            ComputerName = $Report.ComputerName
            UserName = $Report.UserName
            Domain = $Report.Domain
            Success = $Report.Success
            Failed = $Report.Failed
            Skipped = $Report.Skipped
            RemovedPrinters = $Report.RemovedPrinters
            InstalledPrinters = $Report.InstalledPrinters
            FailedPrinters = $Report.FailedPrinters
            Duration = $Report.Duration
        } | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri $webhookURL -Method Post -Body $payload -ContentType 'application/json' -TimeoutSec 10
        Write-Log "Report sent to webhook handler successfully" "SUCCESS"

        if ($response.ticketNumber) {
            Write-Log "Autotask ticket created: #$($response.ticketNumber)" "SUCCESS"
        }
    }
    catch {
        Write-Log "Failed to send webhook report - $($_.Exception.Message)" "ERROR"
    }
}

# Main GUI Form
function Show-PrinterRemapGUI {
    # Create form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Printer Remapping Tool - Enhanced"
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
    $infoLabel.Text = "This tool will unmap existing network printers and remap them with reporting."
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
        Write-Log "=== Printer Remapping Process Started ===" "INFO"
        $startTime = Get-Date
        $startButton.Enabled = $false
        $progressBar.Value = 0

        # Reset execution report
        $script:executionReport.Timestamp = Get-Date
        $script:executionReport.Success = 0
        $script:executionReport.Failed = 0
        $script:executionReport.Skipped = 0
        $script:executionReport.RemovedPrinters = @()
        $script:executionReport.InstalledPrinters = @()
        $script:executionReport.FailedPrinters = @()

        # Load configuration
        $script:config = Load-Config
        if ($null -eq $script:config) {
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
        $result = Add-NewPrinters -Config $script:config -ProgressBar $progressBar -StatusLabel $statusLabel

        # Calculate duration
        $endTime = Get-Date
        $script:executionReport.Duration = [math]::Round(($endTime - $startTime).TotalSeconds, 2)

        # Complete
        $progressBar.Value = 100
        $statusLabel.Text = "Generating reports..."
        [System.Windows.Forms.Application]::DoEvents()

        # Generate reports
        Export-CSVReport -Report $script:executionReport
        Update-UsageTracking -Report $script:executionReport
        Send-EmailReport -Report $script:executionReport
        Send-WebhookReport -Report $script:executionReport

        $statusLabel.Text = "Completed! Success: $($result.Success), Failed: $($result.Failed), Skipped: $($result.Skipped)"
        Write-Log "=== Printer Remapping Process Completed ===" "INFO"

        $closeButton.Enabled = $true

        # Show completion message
        [System.Windows.Forms.MessageBox]::Show(
            "Printer remapping completed!`n`nSuccessfully installed: $($result.Success)`nFailed: $($result.Failed)`nSkipped: $($result.Skipped)`n`nDuration: $($script:executionReport.Duration) seconds`n`nCheck the log file for details: $logPath",
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
Write-Log "=== Script Started ===" "INFO"
Show-PrinterRemapGUI
Write-Log "=== Script Ended ===" "INFO"
