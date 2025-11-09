# Universal Print Printer Remapping Script with GUI
# This script unmaps old printers and remaps them using Microsoft Universal Print
# Requires: UniversalPrintManagement PowerShell module

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Get script directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptPath "PrinterConfig-UniversalPrint.json"
$logPath = Join-Path $scriptPath "PrinterRemap-UniversalPrint.log"

# Global variables
$script:config = $null
$script:upSession = $null
$script:availableShares = @()
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

# Check and install Universal Print Management module
function Initialize-UniversalPrintModule {
    try {
        Write-Log "Checking for UniversalPrintManagement module..."

        # Check if module is installed
        $module = Get-Module -ListAvailable -Name UniversalPrintManagement

        if (-not $module) {
            Write-Log "UniversalPrintManagement module not found. Attempting to install..." "WARNING"

            # Check if running as administrator
            $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

            if (-not $isAdmin) {
                throw "Administrator privileges required to install UniversalPrintManagement module. Please run as administrator or install the module manually: Install-Module UniversalPrintManagement"
            }

            # Install module
            Install-Module -Name UniversalPrintManagement -Scope CurrentUser -Force -AllowClobber
            Write-Log "UniversalPrintManagement module installed successfully" "SUCCESS"
        }

        # Import module
        Import-Module UniversalPrintManagement -ErrorAction Stop
        Write-Log "UniversalPrintManagement module loaded successfully" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to initialize UniversalPrintManagement module - $($_.Exception.Message)" "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to initialize Universal Print module:`n`n$($_.Exception.Message)`n`nPlease ensure the UniversalPrintManagement module is installed.`n`nRun: Install-Module UniversalPrintManagement",
            "Module Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return $false
    }
}

# Connect to Universal Print service
function Connect-UniversalPrint {
    param([object]$Config)

    try {
        Write-Log "Connecting to Universal Print service..."

        $authMethod = $Config.UniversalPrint.AuthenticationMethod

        switch ($authMethod) {
            "Interactive" {
                Write-Log "Using interactive authentication..."
                Connect-UPService -ErrorAction Stop
                Write-Log "Successfully connected to Universal Print (Interactive)" "SUCCESS"
            }

            "ServiceAccount" {
                Write-Log "Using service account authentication..."
                $upn = $Config.UniversalPrint.ServiceAccount.UserPrincipalName

                if ($Config.UniversalPrint.ServiceAccount.UseStoredCredentials) {
                    # Load credentials from secure storage
                    $credPath = $Config.UniversalPrint.ServiceAccount.CredentialPath
                    if (Test-Path $credPath) {
                        $credential = Import-Clixml -Path $credPath
                        Connect-UPService -Credential $credential -ErrorAction Stop
                        Write-Log "Successfully connected to Universal Print using stored credentials" "SUCCESS"
                    }
                    else {
                        throw "Stored credential file not found at: $credPath"
                    }
                }
                else {
                    # Prompt for credentials
                    $credential = Get-Credential -UserName $upn -Message "Enter credentials for Universal Print"
                    Connect-UPService -Credential $credential -ErrorAction Stop
                    Write-Log "Successfully connected to Universal Print using service account" "SUCCESS"
                }
            }

            default {
                throw "Unknown authentication method: $authMethod. Valid options: Interactive, ServiceAccount"
            }
        }

        $script:upSession = $true
        return $true
    }
    catch {
        Write-Log "Failed to connect to Universal Print - $($_.Exception.Message)" "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to connect to Universal Print:`n`n$($_.Exception.Message)`n`nPlease check your credentials and network connection.",
            "Connection Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return $false
    }
}

# Disconnect from Universal Print service
function Disconnect-UniversalPrint {
    try {
        if ($script:upSession) {
            Write-Log "Disconnecting from Universal Print service..."
            Disconnect-UPService -ErrorAction SilentlyContinue
            $script:upSession = $null
            Write-Log "Disconnected from Universal Print" "SUCCESS"
        }
    }
    catch {
        Write-Log "Error during disconnect - $($_.Exception.Message)" "WARNING"
    }
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

# Get available Universal Print shares
function Get-AvailableUniversalPrintShares {
    try {
        Write-Log "Retrieving available Universal Print shares..."

        # Get all printer shares (2025 update: use .results for pagination support)
        $sharesResult = Get-UPPrinterShare -ErrorAction Stop
        $script:availableShares = $sharesResult.results

        if ($script:availableShares.Count -eq 0) {
            Write-Log "No Universal Print shares found in tenant" "WARNING"
        }
        else {
            Write-Log "Found $($script:availableShares.Count) Universal Print shares" "SUCCESS"
            foreach ($share in $script:availableShares) {
                Write-Log "  - $($share.DisplayName) (ID: $($share.Id))"
            }
        }

        return $script:availableShares
    }
    catch {
        Write-Log "Failed to retrieve Universal Print shares - $($_.Exception.Message)" "ERROR"
        return @()
    }
}

# Validate Universal Print share availability
function Test-UniversalPrintShare {
    param(
        [string]$ShareName,
        [string]$ShareId
    )

    try {
        # Try to find by ID first (more reliable)
        if (-not [string]::IsNullOrEmpty($ShareId)) {
            $share = $script:availableShares | Where-Object { $_.Id -eq $ShareId }
            if ($share) {
                Write-Log "Found Universal Print share by ID: $ShareId" "SUCCESS"
                return @{
                    Available = $true
                    Share = $share
                }
            }
        }

        # Fall back to name matching
        if (-not [string]::IsNullOrEmpty($ShareName)) {
            $share = $script:availableShares | Where-Object { $_.DisplayName -eq $ShareName }
            if ($share) {
                Write-Log "Found Universal Print share by name: $ShareName" "SUCCESS"
                return @{
                    Available = $true
                    Share = $share
                }
            }
        }

        Write-Log "Universal Print share not found: $ShareName (ID: $ShareId)" "WARNING"
        return @{
            Available = $false
            Share = $null
        }
    }
    catch {
        Write-Log "Error validating Universal Print share - $($_.Exception.Message)" "ERROR"
        return @{
            Available = $false
            Share = $null
        }
    }
}

# Remove existing printers
function Remove-ExistingPrinters {
    param([System.Windows.Forms.ProgressBar]$ProgressBar, [System.Windows.Forms.Label]$StatusLabel)

    try {
        if (-not $script:config.Settings.RemoveExistingPrinters) {
            Write-Log "Printer removal is disabled in configuration - skipping"
            return $true
        }

        Write-Log "Starting printer removal process..."
        $StatusLabel.Text = "Retrieving current printers..."

        # Get all network printers
        $printers = Get-Printer | Where-Object { $_.Type -eq "Connection" }

        if ($printers.Count -eq 0) {
            Write-Log "No network printers found to remove"
            return $true
        }

        $count = 0
        $total = $printers.Count

        foreach ($printer in $printers) {
            $count++
            $percentage = [int](($count / $total) * 30)  # First 30% for removal
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

# Add Universal Print printers
function Add-UniversalPrintPrinters {
    param(
        [object]$Config,
        [System.Windows.Forms.ProgressBar]$ProgressBar,
        [System.Windows.Forms.Label]$StatusLabel
    )

    try {
        Write-Log "Starting Universal Print printer installation..."
        $count = 0
        $enabledPrinters = $Config.Printers | Where-Object { $_.Enabled -eq $true }
        $total = $enabledPrinters.Count

        foreach ($printer in $enabledPrinters) {
            $count++
            $basePercentage = 30  # Start at 30% (after removal)
            $percentage = $basePercentage + [int](($count / $total) * 70)
            $ProgressBar.Value = $percentage

            $StatusLabel.Text = "Validating: $($printer.Name) ($count of $total)"
            [System.Windows.Forms.Application]::DoEvents()

            # Validate Universal Print share availability
            $validation = Test-UniversalPrintShare -ShareName $printer.UniversalPrintShareName -ShareId $printer.UniversalPrintShareId

            if (-not $validation.Available) {
                Write-Log "Skipping $($printer.Name) - Universal Print share not available" "WARNING"
                $script:executionReport.Skipped++
                $script:executionReport.FailedPrinters += @{
                    Name = $printer.Name
                    ShareName = $printer.UniversalPrintShareName
                    Reason = "Universal Print share not found or not available"
                }

                if (-not $Config.Settings.SkipUnavailablePrinters) {
                    Write-Log "SkipUnavailablePrinters is false - stopping installation" "WARNING"
                    break
                }
                continue
            }

            # Install printer using Universal Print share
            $share = $validation.Share
            $StatusLabel.Text = "Installing: $($printer.Name) ($count of $total)"
            [System.Windows.Forms.Application]::DoEvents()

            try {
                # The Universal Print share ID is used to create the printer connection
                # Format: \\universalprint.windows.net\<ShareId>
                $printerPath = "https://universalprint.windows.net/$($share.Id)"

                Write-Log "Installing printer: $($printer.Name) from share: $($share.DisplayName)"
                Write-Log "  Share ID: $($share.Id)"

                # Add the printer using the Universal Print share
                # Note: This requires the printer share to be accessible to the current user
                Add-Printer -ConnectionName $printerPath -ErrorAction Stop

                Write-Log "Successfully installed printer: $($printer.Name)" "SUCCESS"
                $script:executionReport.Success++
                $script:executionReport.InstalledPrinters += @{
                    Name = $printer.Name
                    ShareName = $share.DisplayName
                    ShareId = $share.Id
                    Path = $printerPath
                }

                # Set as default if configured
                if ($Config.Settings.SetDefaultPrinter -eq $printer.Name) {
                    try {
                        $installedPrinter = Get-Printer | Where-Object { $_.Name -like "*$($share.DisplayName)*" } | Select-Object -First 1
                        if ($installedPrinter) {
                            Set-PrinterAsDefault -Name $installedPrinter.Name -ErrorAction Stop
                            Write-Log "Set $($printer.Name) as default printer" "SUCCESS"
                        }
                    }
                    catch {
                        Write-Log "Failed to set default printer - $($_.Exception.Message)" "WARNING"
                    }
                }
            }
            catch {
                Write-Log "Failed to install $($printer.Name) - $($_.Exception.Message)" "ERROR"
                $script:executionReport.Failed++
                $script:executionReport.FailedPrinters += @{
                    Name = $printer.Name
                    ShareName = $printer.UniversalPrintShareName
                    Reason = $_.Exception.Message
                }

                # Retry if enabled
                if ($Config.Settings.RetryFailedPrinters) {
                    for ($retry = 1; $retry -le $Config.Settings.MaxRetries; $retry++) {
                        Write-Log "Retry attempt $retry of $($Config.Settings.MaxRetries) for $($printer.Name)..." "WARNING"
                        Start-Sleep -Seconds 2

                        try {
                            Add-Printer -ConnectionName $printerPath -ErrorAction Stop
                            Write-Log "Retry successful for $($printer.Name)" "SUCCESS"
                            $script:executionReport.Failed--
                            $script:executionReport.Success++

                            # Update the failed printers list
                            $script:executionReport.FailedPrinters = $script:executionReport.FailedPrinters | Where-Object { $_.Name -ne $printer.Name }
                            $script:executionReport.InstalledPrinters += @{
                                Name = $printer.Name
                                ShareName = $share.DisplayName
                                ShareId = $share.Id
                                Path = $printerPath
                            }
                            break
                        }
                        catch {
                            Write-Log "Retry $retry failed - $($_.Exception.Message)" "ERROR"
                        }
                    }
                }
            }

            Start-Sleep -Milliseconds $Config.Settings.InstallDelayMs
        }

        Write-Log "Universal Print installation completed. Success: $($script:executionReport.Success), Failed: $($script:executionReport.Failed), Skipped: $($script:executionReport.Skipped)"
        return $script:executionReport
    }
    catch {
        Write-Log "Universal Print installation process failed - $($_.Exception.Message)" "ERROR"
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
        $csvFile = Join-Path $csvPath "UniversalPrint_Remap_$($Report.ComputerName)_$timestamp.csv"

        $reportData = [PSCustomObject]@{
            Timestamp = $Report.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
            ComputerName = $Report.ComputerName
            UserName = $Report.UserName
            Domain = $Report.Domain
            SuccessCount = $Report.Success
            FailedCount = $Report.Failed
            SkippedCount = $Report.Skipped
            RemovedPrinters = ($Report.RemovedPrinters -join "; ")
            InstalledPrinters = (($Report.InstalledPrinters | ForEach-Object { "$($_.Name) [$($_.ShareName)]" }) -join "; ")
            FailedPrinters = (($Report.FailedPrinters | ForEach-Object { "$($_.Name): $($_.Reason)" }) -join "; ")
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

        $trackingFile = Join-Path $trackingPath "UniversalPrint_Usage.csv"

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

        if (Test-Path $trackingFile) {
            $usageData | Export-Csv -Path $trackingFile -NoTypeInformation -Append
        }
        else {
            $usageData | Export-Csv -Path $trackingFile -NoTypeInformation
        }

        Write-Log "Usage tracking updated: $trackingFile" "SUCCESS"
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

        if ($emailSettings.OnlyEmailOnFailure -and $Report.Failed -eq 0) {
            Write-Log "No failures detected - skipping email (OnlyEmailOnFailure=true)"
            return
        }

        $subject = "Universal Print Remap Report - $($Report.ComputerName) - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"

        $body = @"
<html>
<body style='font-family: Arial, sans-serif;'>
<h2>Universal Print Remapping Report</h2>
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

<h3>Installed Universal Print Printers:</h3>
<ul>
$(($Report.InstalledPrinters | ForEach-Object { "<li>$($_.Name) - Share: $($_.ShareName) (ID: $($_.ShareId))</li>" }) -join "`n")
</ul>

$(if ($Report.FailedPrinters.Count -gt 0) {
"<h3 style='color: red;'>Failed Printers:</h3>
<ul>
$(($Report.FailedPrinters | ForEach-Object { "<li>$($_.Name) - $($_.Reason)</li>" }) -join "`n")
</ul>"
})

<p><em>This is an automated report from the Universal Print Remapping Script.</em></p>
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
            Write-Log "Email requires authentication - credentials must be configured separately" "WARNING"
        }

        Send-MailMessage @mailParams
        Write-Log "Email report sent to $($emailSettings.ToAddress)" "SUCCESS"
    }
    catch {
        Write-Log "Failed to send email report - $($_.Exception.Message)" "ERROR"
    }
}

# Send report to webhook
function Send-WebhookReport {
    param([object]$Report)

    try {
        if (-not $script:config.Reporting.EnableWebhook) {
            Write-Log "Webhook reporting is disabled in configuration"
            return
        }

        $webhookURL = $script:config.Reporting.WebhookURL

        $payload = @{
            Type = "UniversalPrint"
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
    }
    catch {
        Write-Log "Failed to send webhook report - $($_.Exception.Message)" "ERROR"
    }
}

# Main GUI Form
function Show-PrinterRemapGUI {
    # Create form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Universal Print Remapping Tool"
    $form.Size = New-Object System.Drawing.Size(550, 350)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false

    # Title Label
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $titleLabel.Size = New-Object System.Drawing.Size(510, 30)
    $titleLabel.Text = "Universal Print Remapping Utility"
    $titleLabel.Font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($titleLabel)

    # Info Label
    $infoLabel = New-Object System.Windows.Forms.Label
    $infoLabel.Location = New-Object System.Drawing.Point(20, 60)
    $infoLabel.Size = New-Object System.Drawing.Size(510, 40)
    $infoLabel.Text = "This tool connects to Microsoft Universal Print and remaps your printers."
    $form.Controls.Add($infoLabel)

    # Status Label
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Location = New-Object System.Drawing.Point(20, 110)
    $statusLabel.Size = New-Object System.Drawing.Size(510, 20)
    $statusLabel.Text = "Ready to begin..."
    $form.Controls.Add($statusLabel)

    # Progress Bar
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(20, 140)
    $progressBar.Size = New-Object System.Drawing.Size(510, 30)
    $progressBar.Style = "Continuous"
    $progressBar.Minimum = 0
    $progressBar.Maximum = 100
    $progressBar.Value = 0
    $form.Controls.Add($progressBar)

    # Details TextBox
    $detailsBox = New-Object System.Windows.Forms.TextBox
    $detailsBox.Location = New-Object System.Drawing.Point(20, 180)
    $detailsBox.Size = New-Object System.Drawing.Size(510, 60)
    $detailsBox.Multiline = $true
    $detailsBox.ScrollBars = "Vertical"
    $detailsBox.ReadOnly = $true
    $detailsBox.Font = New-Object System.Drawing.Font("Consolas", 8)
    $form.Controls.Add($detailsBox)

    # Start Button
    $startButton = New-Object System.Windows.Forms.Button
    $startButton.Location = New-Object System.Drawing.Point(180, 260)
    $startButton.Size = New-Object System.Drawing.Size(100, 35)
    $startButton.Text = "Start"
    $startButton.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)

    # Close Button
    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Location = New-Object System.Drawing.Point(290, 260)
    $closeButton.Size = New-Object System.Drawing.Size(100, 35)
    $closeButton.Text = "Close"
    $closeButton.Font = New-Object System.Drawing.Font("Arial", 10)
    $closeButton.Enabled = $false

    # Start Button Click Event
    $startButton.Add_Click({
        Write-Log "=== Universal Print Remapping Process Started ===" "INFO"
        $startTime = Get-Date
        $startButton.Enabled = $false
        $progressBar.Value = 0
        $detailsBox.Clear()

        # Reset execution report
        $script:executionReport.Timestamp = Get-Date
        $script:executionReport.Success = 0
        $script:executionReport.Failed = 0
        $script:executionReport.Skipped = 0
        $script:executionReport.RemovedPrinters = @()
        $script:executionReport.InstalledPrinters = @()
        $script:executionReport.FailedPrinters = @()

        # Initialize Universal Print module
        $statusLabel.Text = "Initializing Universal Print module..."
        $detailsBox.AppendText("Checking Universal Print module...`r`n")
        [System.Windows.Forms.Application]::DoEvents()

        if (-not (Initialize-UniversalPrintModule)) {
            $statusLabel.Text = "Failed to initialize Universal Print module"
            $startButton.Enabled = $true
            return
        }

        $detailsBox.AppendText("Module loaded successfully`r`n")
        $progressBar.Value = 5

        # Load configuration
        $statusLabel.Text = "Loading configuration..."
        $detailsBox.AppendText("Loading configuration...`r`n")
        [System.Windows.Forms.Application]::DoEvents()

        $script:config = Load-Config
        if ($null -eq $script:config) {
            $statusLabel.Text = "Failed to load configuration"
            $startButton.Enabled = $true
            return
        }

        $detailsBox.AppendText("Configuration loaded`r`n")
        $progressBar.Value = 10

        # Connect to Universal Print
        $statusLabel.Text = "Connecting to Universal Print..."
        $detailsBox.AppendText("Authenticating to Universal Print...`r`n")
        [System.Windows.Forms.Application]::DoEvents()

        if (-not (Connect-UniversalPrint -Config $script:config)) {
            $statusLabel.Text = "Failed to connect to Universal Print"
            $startButton.Enabled = $true
            return
        }

        $detailsBox.AppendText("Connected to Universal Print`r`n")
        $progressBar.Value = 20

        # Get available shares
        $statusLabel.Text = "Retrieving Universal Print shares..."
        $detailsBox.AppendText("Getting available printer shares...`r`n")
        [System.Windows.Forms.Application]::DoEvents()

        $shares = Get-AvailableUniversalPrintShares
        $detailsBox.AppendText("Found $($shares.Count) printer shares`r`n")
        $progressBar.Value = 30

        # Remove existing printers
        $statusLabel.Text = "Removing existing printers..."
        $detailsBox.AppendText("Removing old printers...`r`n")
        [System.Windows.Forms.Application]::DoEvents()

        Remove-ExistingPrinters -ProgressBar $progressBar -StatusLabel $statusLabel
        $detailsBox.AppendText("Removed $($script:executionReport.RemovedPrinters.Count) printers`r`n")

        # Add Universal Print printers
        $statusLabel.Text = "Installing Universal Print printers..."
        $detailsBox.AppendText("Installing printers...`r`n")
        [System.Windows.Forms.Application]::DoEvents()

        $result = Add-UniversalPrintPrinters -Config $script:config -ProgressBar $progressBar -StatusLabel $statusLabel
        $detailsBox.AppendText("Installation complete`r`n")
        $detailsBox.AppendText("Success: $($result.Success) | Failed: $($result.Failed) | Skipped: $($result.Skipped)`r`n")

        # Calculate duration
        $endTime = Get-Date
        $script:executionReport.Duration = [math]::Round(($endTime - $startTime).TotalSeconds, 2)

        # Complete
        $progressBar.Value = 100
        $statusLabel.Text = "Generating reports..."
        $detailsBox.AppendText("Generating reports...`r`n")
        [System.Windows.Forms.Application]::DoEvents()

        # Generate reports
        Export-CSVReport -Report $script:executionReport
        Update-UsageTracking -Report $script:executionReport
        Send-EmailReport -Report $script:executionReport
        Send-WebhookReport -Report $script:executionReport

        # Disconnect from Universal Print
        Disconnect-UniversalPrint

        $statusLabel.Text = "Completed!"
        $detailsBox.AppendText("Process completed in $($script:executionReport.Duration) seconds`r`n")
        Write-Log "=== Universal Print Remapping Process Completed ===" "INFO"

        $closeButton.Enabled = $true

        # Show completion message
        [System.Windows.Forms.MessageBox]::Show(
            "Universal Print remapping completed!`n`nSuccessfully installed: $($result.Success)`nFailed: $($result.Failed)`nSkipped: $($result.Skipped)`n`nDuration: $($script:executionReport.Duration) seconds`n`nCheck the log file for details: $logPath",
            "Process Complete",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    })

    # Close Button Click Event
    $closeButton.Add_Click({
        Disconnect-UniversalPrint
        $form.Close()
    })

    # Form closing event
    $form.Add_FormClosing({
        Disconnect-UniversalPrint
    })

    $form.Controls.Add($startButton)
    $form.Controls.Add($closeButton)

    # Show form
    $form.ShowDialog()
}

# Run the GUI
Write-Log "=== Universal Print Remapping Script Started ===" "INFO"
Show-PrinterRemapGUI
Write-Log "=== Universal Print Remapping Script Ended ===" "INFO"
