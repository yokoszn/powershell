# Central Webhook Handler - Runs on Server
# Receives printer remap reports and handles all API integrations
# No API keys distributed to endpoints!

# This would typically run as an Azure Function, AWS Lambda, or simple web service

#Region Configuration - Only on YOUR server
$config = @{
    # Autotask Configuration (ONLY ON SERVER)
    Autotask = @{
        Enabled = $true
        APIUsername = "your-api-username@company.com"
        APISecret = "your-api-secret"
        APIIntegrationCode = "your-integration-code"
        BaseURL = "https://webservices.autotask.net/ATServicesRest/V1.0"
        QueueID = 12345
        IssueTypeID = 67
        TicketCategoryID = 89
        PriorityID = 3
        MinimumFailuresForTicket = 2
    }

    # IT Glue Configuration (ONLY ON SERVER)
    ITGlue = @{
        Enabled = $true
        APIKey = "your-it-glue-api-key"
        BaseURL = "https://api.itglue.com"
        FlexibleAssetTypeID = 12345
    }

    # Storage Configuration
    Storage = @{
        CSVPath = "C:\PrinterReports"
        UsageTrackingPath = "C:\PrinterUsage"
    }

    # Slack/Teams Notifications
    Notifications = @{
        SlackWebhook = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
        TeamsWebhook = "https://outlook.office.com/webhook/YOUR/WEBHOOK/URL"
    }
}
#EndRegion

#Region Webhook Listener (Example using HTTP.sys)
function Start-WebhookListener {
    param(
        [int]$Port = 8080
    )

    # Create HTTP listener
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://+:$Port/printerreport/")
    $listener.Start()

    Write-Host "Webhook listener started on port $Port"
    Write-Host "Endpoint: http://your-server:$Port/printerreport/"

    while ($listener.IsListening) {
        try {
            # Wait for incoming request
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response

            Write-Host "Received request from $($request.RemoteEndPoint)"

            if ($request.HttpMethod -eq "POST") {
                # Read POST body
                $reader = New-Object System.IO.StreamReader($request.InputStream)
                $body = $reader.ReadToEnd()
                $reader.Close()

                # Parse JSON
                $reportData = $body | ConvertFrom-Json

                Write-Host "Processing report for $($reportData.ComputerName)"

                # Process the report
                $result = Process-PrinterReport -Report $reportData

                # Send success response
                $responseData = @{
                    status = "success"
                    message = "Report processed successfully"
                    ticketNumber = $result.TicketNumber
                } | ConvertTo-Json

                $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseData)
                $response.ContentLength64 = $buffer.Length
                $response.ContentType = "application/json"
                $response.StatusCode = 200
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            else {
                $response.StatusCode = 405
            }

            $response.Close()
        }
        catch {
            Write-Host "Error processing request: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
#EndRegion

#Region Report Processing
function Process-PrinterReport {
    param([object]$Report)

    $result = @{
        TicketNumber = $null
        ITGlueAssetID = $null
        NotificationsSent = $false
    }

    try {
        Write-Host "Processing report for $($Report.ComputerName)"
        Write-Host "Success: $($Report.Success) | Failed: $($Report.Failed) | Skipped: $($Report.Skipped)"

        # Save to CSV
        if ($config.Storage.CSVPath) {
            Save-ReportToCSV -Report $Report
        }

        # Update usage tracking
        if ($config.Storage.UsageTrackingPath) {
            Update-UsageTracking -Report $Report
        }

        # Create Autotask ticket if needed
        if ($config.Autotask.Enabled -and $Report.Failed -ge $config.Autotask.MinimumFailuresForTicket) {
            $result.TicketNumber = Create-AutotaskTicket -Report $Report
        }

        # Update IT Glue documentation
        if ($config.ITGlue.Enabled) {
            $result.ITGlueAssetID = Update-ITGlueDocumentation -Report $Report
        }

        # Send notifications
        Send-NotificationToSlack -Report $Report
        Send-NotificationToTeams -Report $Report
        $result.NotificationsSent = $true

        return $result
    }
    catch {
        Write-Host "Error processing report: $($_.Exception.Message)" -ForegroundColor Red
        return $result
    }
}

function Save-ReportToCSV {
    param([object]$Report)

    try {
        $csvPath = $config.Storage.CSVPath
        if (-not (Test-Path $csvPath)) {
            New-Item -ItemType Directory -Path $csvPath -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $csvFile = Join-Path $csvPath "PrinterRemap_$($Report.ComputerName)_$timestamp.csv"

        $reportData = [PSCustomObject]@{
            Timestamp = $Report.Timestamp
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

        $reportData | Export-Csv -Path $csvFile -NoTypeInformation
        Write-Host "Report saved to CSV: $csvFile" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to save CSV: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Update-UsageTracking {
    param([object]$Report)

    try {
        $trackingPath = $config.Storage.UsageTrackingPath
        if (-not (Test-Path $trackingPath)) {
            New-Item -ItemType Directory -Path $trackingPath -Force | Out-Null
        }

        $trackingFile = Join-Path $trackingPath "PrinterRemapUsage.csv"

        $usageData = [PSCustomObject]@{
            Timestamp = $Report.Timestamp
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

        Write-Host "Usage tracking updated" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to update usage tracking: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Create-AutotaskTicket {
    param([object]$Report)

    try {
        # Import Autotask integration
        . .\Autotask-Integration.ps1

        $headers = Get-AutotaskHeaders -Username $config.Autotask.APIUsername `
                                      -Secret $config.Autotask.APISecret `
                                      -IntegrationCode $config.Autotask.APIIntegrationCode

        $companyID = Find-AutotaskCompany -ComputerName $Report.ComputerName `
                                         -Headers $headers `
                                         -BaseURL $config.Autotask.BaseURL

        if ($companyID) {
            $title = "Printer Installation Failures on $($Report.ComputerName)"
            $description = @"
Automated printer remapping encountered failures.

Computer: $($Report.ComputerName)
User: $($Report.Domain)\$($Report.UserName)
Timestamp: $($Report.Timestamp)

Results:
- Success: $($Report.Success)
- Failed: $($Report.Failed)
- Skipped: $($Report.Skipped)

Failed Printers:
$($Report.FailedPrinters | ForEach-Object { "- $($_.Name) ($($_.IP)): $($_.Reason)" } | Out-String)
"@

            $ticket = New-AutotaskTicket -Title $title `
                                        -Description $description `
                                        -CompanyID $companyID `
                                        -Config $config.Autotask `
                                        -Headers $headers `
                                        -BaseURL $config.Autotask.BaseURL

            if ($ticket) {
                Write-Host "Created Autotask ticket #$($ticket.ticketNumber)" -ForegroundColor Green
                return $ticket.ticketNumber
            }
        }

        return $null
    }
    catch {
        Write-Host "Failed to create Autotask ticket: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Update-ITGlueDocumentation {
    param([object]$Report)

    try {
        # Import IT Glue integration
        . .\ITGlue-Integration.ps1

        $headers = Get-ITGlueHeaders -APIKey $config.ITGlue.APIKey

        $organizationID = Find-ITGlueOrganization -ComputerName $Report.ComputerName `
                                                  -Headers $headers `
                                                  -BaseURL $config.ITGlue.BaseURL

        if ($organizationID) {
            $assetID = New-ITGlueFlexibleAsset -OrganizationID $organizationID `
                                               -ComputerName $Report.ComputerName `
                                               -PrinterReport $Report `
                                               -Config $config.ITGlue `
                                               -Headers $headers `
                                               -BaseURL $config.ITGlue.BaseURL

            if ($assetID) {
                Write-Host "Updated IT Glue asset #$assetID" -ForegroundColor Green
                return $assetID
            }
        }

        return $null
    }
    catch {
        Write-Host "Failed to update IT Glue: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Send-NotificationToSlack {
    param([object]$Report)

    try {
        if (-not $config.Notifications.SlackWebhook) { return }

        $statusEmoji = if ($Report.Failed -eq 0) { ":white_check_mark:" } else { ":warning:" }
        $color = if ($Report.Failed -eq 0) { "good" } elseif ($Report.Success -gt 0) { "warning" } else { "danger" }

        $payload = @{
            text = "Printer Remap Report"
            attachments = @(
                @{
                    color = $color
                    title = "Printer Remapping - $($Report.ComputerName)"
                    fields = @(
                        @{ title = "Computer"; value = $Report.ComputerName; short = $true }
                        @{ title = "User"; value = "$($Report.Domain)\$($Report.UserName)"; short = $true }
                        @{ title = "Success"; value = $Report.Success; short = $true }
                        @{ title = "Failed"; value = $Report.Failed; short = $true }
                        @{ title = "Skipped"; value = $Report.Skipped; short = $true }
                        @{ title = "Duration"; value = "$($Report.Duration)s"; short = $true }
                    )
                    footer = "Printer Remap Script"
                    ts = [int][double]::Parse((Get-Date -UFormat %s))
                }
            )
        } | ConvertTo-Json -Depth 10

        Invoke-RestMethod -Uri $config.Notifications.SlackWebhook -Method Post -Body $payload -ContentType 'application/json'
        Write-Host "Slack notification sent" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to send Slack notification: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Send-NotificationToTeams {
    param([object]$Report)

    try {
        if (-not $config.Notifications.TeamsWebhook) { return }

        $themeColor = if ($Report.Failed -eq 0) { "28a745" } elseif ($Report.Success -gt 0) { "ffc107" } else { "dc3545" }

        $payload = @{
            "@type" = "MessageCard"
            "@context" = "https://schema.org/extensions"
            summary = "Printer Remap Report"
            themeColor = $themeColor
            title = "Printer Remapping - $($Report.ComputerName)"
            sections = @(
                @{
                    facts = @(
                        @{ name = "Computer"; value = $Report.ComputerName }
                        @{ name = "User"; value = "$($Report.Domain)\$($Report.UserName)" }
                        @{ name = "Success"; value = $Report.Success }
                        @{ name = "Failed"; value = $Report.Failed }
                        @{ name = "Skipped"; value = $Report.Skipped }
                        @{ name = "Duration"; value = "$($Report.Duration)s" }
                    )
                }
            )
        } | ConvertTo-Json -Depth 10

        Invoke-RestMethod -Uri $config.Notifications.TeamsWebhook -Method Post -Body $payload -ContentType 'application/json'
        Write-Host "Teams notification sent" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to send Teams notification: $($_.Exception.Message)" -ForegroundColor Red
    }
}
#EndRegion

# Start the webhook listener
Start-WebhookListener -Port 8080
