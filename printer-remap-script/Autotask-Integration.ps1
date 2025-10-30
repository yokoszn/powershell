# Autotask PSA Integration Module
# Automatically creates tickets for printer failures and updates asset configurations

#Region Autotask Configuration
$autotaskConfig = @{
    # API Configuration
    APIUsername = "your-api-username@company.com"
    APISecret = "your-api-secret"
    APIIntegrationCode = "your-integration-code"
    BaseURL = "https://webservices.autotask.net/ATServicesRest/V1.0"

    # Ticket Configuration
    QueueID = 12345  # Your default ticket queue ID
    IssueTypeID = 67  # Issue type for printer problems
    TicketCategoryID = 89  # Category for printer-related tickets
    PriorityID = 3  # 1=Critical, 2=High, 3=Medium, 4=Low
    StatusID = 1  # 1=New

    # Create tickets for failures
    CreateTicketsForFailures = $true
    MinimumFailuresForTicket = 2  # Only create ticket if 2+ printers fail

    # Update configuration items
    UpdateConfigItems = $true
}
#EndRegion

#Region Helper Functions
function Get-AutotaskHeaders {
    param(
        [string]$Username,
        [string]$Secret,
        [string]$IntegrationCode
    )

    $encodedCredentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Username`:$Secret"))

    return @{
        "Authorization" = "Basic $encodedCredentials"
        "ApiIntegrationCode" = $IntegrationCode
        "Content-Type" = "application/json"
    }
}

function Find-AutotaskCompany {
    param(
        [string]$ComputerName,
        [hashtable]$Headers,
        [string]$BaseURL
    )

    try {
        # Try to find company by computer name or asset
        $searchURL = "$BaseURL/Companies/query"

        $searchBody = @{
            filter = @(
                @{
                    op = "contains"
                    field = "companyName"
                    value = $ComputerName
                }
            )
        } | ConvertTo-Json -Depth 5

        $response = Invoke-RestMethod -Uri $searchURL -Method Post -Headers $Headers -Body $searchBody -ErrorAction Stop

        if ($response.items.Count -gt 0) {
            return $response.items[0].id
        }

        # If not found, return null (caller should handle)
        Write-Warning "Could not find Autotask company for $ComputerName"
        return $null
    }
    catch {
        Write-Warning "Failed to search Autotask companies: $($_.Exception.Message)"
        return $null
    }
}

function New-AutotaskTicket {
    param(
        [string]$Title,
        [string]$Description,
        [int]$CompanyID,
        [hashtable]$Config,
        [hashtable]$Headers,
        [string]$BaseURL
    )

    try {
        $ticketURL = "$BaseURL/Tickets"

        $ticketBody = @{
            companyID = $CompanyID
            title = $Title
            description = $Description
            queueID = $Config.QueueID
            issueType = $Config.IssueTypeID
            ticketCategory = $Config.TicketCategoryID
            priority = $Config.PriorityID
            status = $Config.StatusID
        } | ConvertTo-Json -Depth 5

        $response = Invoke-RestMethod -Uri $ticketURL -Method Post -Headers $Headers -Body $ticketBody -ErrorAction Stop

        Write-Host "Created Autotask ticket #$($response.item.ticketNumber)" -ForegroundColor Green
        return $response.item
    }
    catch {
        Write-Warning "Failed to create Autotask ticket: $($_.Exception.Message)"
        return $null
    }
}

function Update-AutotaskConfigItem {
    param(
        [string]$ComputerName,
        [string]$PrinterInfo,
        [hashtable]$Headers,
        [string]$BaseURL
    )

    try {
        # Search for configuration item (asset)
        $searchURL = "$BaseURL/ConfigurationItems/query"

        $searchBody = @{
            filter = @(
                @{
                    op = "eq"
                    field = "referenceTitle"
                    value = $ComputerName
                }
            )
        } | ConvertTo-Json -Depth 5

        $response = Invoke-RestMethod -Uri $searchURL -Method Post -Headers $Headers -Body $searchBody -ErrorAction SilentlyContinue

        if ($response.items.Count -gt 0) {
            $configItemID = $response.items[0].id

            # Update configuration item with printer information
            $updateURL = "$BaseURL/ConfigurationItems/$configItemID"

            $updateBody = @{
                id = $configItemID
                referenceTitle = $ComputerName
                notes = $PrinterInfo
            } | ConvertTo-Json -Depth 5

            Invoke-RestMethod -Uri $updateURL -Method Patch -Headers $Headers -Body $updateBody -ErrorAction Stop
            Write-Host "Updated Autotask configuration item for $ComputerName" -ForegroundColor Green
        }
        else {
            Write-Warning "Configuration item not found for $ComputerName"
        }
    }
    catch {
        Write-Warning "Failed to update Autotask configuration item: $($_.Exception.Message)"
    }
}
#EndRegion

#Region Main Integration Function
function Send-AutotaskReport {
    param(
        [object]$PrinterReport
    )

    try {
        if (-not $autotaskConfig.CreateTicketsForFailures -and -not $autotaskConfig.UpdateConfigItems) {
            Write-Host "Autotask integration is disabled in configuration"
            return
        }

        # Get Autotask headers
        $headers = Get-AutotaskHeaders -Username $autotaskConfig.APIUsername `
                                      -Secret $autotaskConfig.APISecret `
                                      -IntegrationCode $autotaskConfig.APIIntegrationCode

        # Find company in Autotask
        $companyID = Find-AutotaskCompany -ComputerName $PrinterReport.ComputerName `
                                         -Headers $headers `
                                         -BaseURL $autotaskConfig.BaseURL

        if (-not $companyID) {
            Write-Warning "Cannot proceed with Autotask integration - company not found"
            return
        }

        # Create ticket for failures if threshold is met
        if ($autotaskConfig.CreateTicketsForFailures -and
            $PrinterReport.Failed -ge $autotaskConfig.MinimumFailuresForTicket) {

            $ticketTitle = "Printer Installation Failures on $($PrinterReport.ComputerName)"

            $ticketDescription = @"
Automated printer remapping encountered failures on $($PrinterReport.ComputerName).

User: $($PrinterReport.Domain)\$($PrinterReport.UserName)
Timestamp: $($PrinterReport.Timestamp)
Duration: $($PrinterReport.Duration) seconds

Results:
- Successfully Installed: $($PrinterReport.Success)
- Failed: $($PrinterReport.Failed)
- Skipped (unreachable): $($PrinterReport.Skipped)

Failed Printers:
$($PrinterReport.FailedPrinters | ForEach-Object { "- $($_.Name) ($($_.IP)): $($_.Reason)" } | Out-String)

Installed Printers:
$($PrinterReport.InstalledPrinters | ForEach-Object { "- $($_.Name) ($($_.Path))" } | Out-String)

Please investigate the failed printers and resolve connectivity or configuration issues.

This ticket was automatically generated by the Printer Remapping Script.
"@

            $ticket = New-AutotaskTicket -Title $ticketTitle `
                                        -Description $ticketDescription `
                                        -CompanyID $companyID `
                                        -Config $autotaskConfig `
                                        -Headers $headers `
                                        -BaseURL $autotaskConfig.BaseURL

            if ($ticket) {
                Write-Host "Autotask ticket created: #$($ticket.ticketNumber)" -ForegroundColor Green
            }
        }
        elseif ($PrinterReport.Failed -gt 0) {
            Write-Host "Printer failures ($($PrinterReport.Failed)) below threshold ($($autotaskConfig.MinimumFailuresForTicket)) - no ticket created"
        }

        # Update configuration item with printer status
        if ($autotaskConfig.UpdateConfigItems) {
            $printerInfo = @"
Last Printer Remap: $($PrinterReport.Timestamp)
User: $($PrinterReport.Domain)\$($PrinterReport.UserName)

Installed Printers:
$($PrinterReport.InstalledPrinters | ForEach-Object { "- $($_.Name)" } | Out-String)

Status: $($PrinterReport.Success) installed, $($PrinterReport.Failed) failed, $($PrinterReport.Skipped) skipped
"@

            Update-AutotaskConfigItem -ComputerName $PrinterReport.ComputerName `
                                     -PrinterInfo $printerInfo `
                                     -Headers $headers `
                                     -BaseURL $autotaskConfig.BaseURL
        }

        Write-Host "Autotask integration completed successfully" -ForegroundColor Green
    }
    catch {
        Write-Warning "Autotask integration error: $($_.Exception.Message)"
    }
}
#EndRegion

# Export function for use in main script
Export-ModuleMember -Function Send-AutotaskReport
