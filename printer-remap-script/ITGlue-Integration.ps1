# IT Glue Documentation Integration Module
# Automatically updates documentation with printer configuration and status

#Region IT Glue Configuration
$itGlueConfig = @{
    # API Configuration
    APIKey = "your-it-glue-api-key"
    BaseURL = "https://api.itglue.com"

    # Documentation Configuration
    UpdateFlexibleAssets = $true
    FlexibleAssetTypeID = 12345  # Your "Printer Configuration" flexible asset type ID

    # Configuration Item Updates
    UpdateConfigurationItems = $true

    # Password Documentation
    DocumentPrinterCredentials = $false  # Set to true if you manage printer admin passwords
}
#EndRegion

#Region Helper Functions
function Get-ITGlueHeaders {
    param([string]$APIKey)

    return @{
        "x-api-key" = $APIKey
        "Content-Type" = "application/vnd.api+json"
    }
}

function Find-ITGlueOrganization {
    param(
        [string]$ComputerName,
        [hashtable]$Headers,
        [string]$BaseURL
    )

    try {
        # Search for organization by name
        $searchURL = "$BaseURL/organizations"

        $response = Invoke-RestMethod -Uri $searchURL -Method Get -Headers $Headers -ErrorAction Stop

        # Try to match by computer name pattern (assuming computer name contains org identifier)
        foreach ($org in $response.data) {
            if ($ComputerName -match $org.attributes.name -or $org.attributes.name -match $ComputerName) {
                return $org.id
            }
        }

        # If not found, return the first organization (or implement better logic)
        if ($response.data.Count -gt 0) {
            Write-Warning "Could not match organization for $ComputerName, using first available"
            return $response.data[0].id
        }

        return $null
    }
    catch {
        Write-Warning "Failed to find IT Glue organization: $($_.Exception.Message)"
        return $null
    }
}

function Find-ITGlueConfigurationItem {
    param(
        [int]$OrganizationID,
        [string]$ComputerName,
        [hashtable]$Headers,
        [string]$BaseURL
    )

    try {
        $searchURL = "$BaseURL/configurations?filter[organization_id]=$OrganizationID&filter[name]=$ComputerName"

        $response = Invoke-RestMethod -Uri $searchURL -Method Get -Headers $Headers -ErrorAction Stop

        if ($response.data.Count -gt 0) {
            return $response.data[0].id
        }

        return $null
    }
    catch {
        Write-Warning "Failed to find configuration item: $($_.Exception.Message)"
        return $null
    }
}

function New-ITGlueFlexibleAsset {
    param(
        [int]$OrganizationID,
        [string]$ComputerName,
        [object]$PrinterReport,
        [hashtable]$Config,
        [hashtable]$Headers,
        [string]$BaseURL
    )

    try {
        $assetURL = "$BaseURL/flexible_assets"

        # Build printer status table
        $printerStatusHTML = @"
<h3>Printer Configuration Status</h3>
<table border='1' cellpadding='5' style='border-collapse: collapse;'>
<tr>
    <th>Printer Name</th>
    <th>IP Address</th>
    <th>Status</th>
    <th>Path</th>
</tr>
"@

        foreach ($printer in $PrinterReport.InstalledPrinters) {
            $printerStatusHTML += @"
<tr>
    <td>$($printer.Name)</td>
    <td>$($printer.IP)</td>
    <td style='color: green;'>Installed</td>
    <td>$($printer.Path)</td>
</tr>
"@
        }

        foreach ($printer in $PrinterReport.FailedPrinters) {
            $printerStatusHTML += @"
<tr>
    <td>$($printer.Name)</td>
    <td>$($printer.IP)</td>
    <td style='color: red;'>Failed</td>
    <td>$($printer.Reason)</td>
</tr>
"@
        }

        $printerStatusHTML += "</table>"

        # Create flexible asset
        $assetData = @{
            data = @{
                type = "flexible-assets"
                attributes = @{
                    "organization-id" = $OrganizationID
                    "flexible-asset-type-id" = $Config.FlexibleAssetTypeID
                    traits = @{
                        "name" = "Printer Configuration - $ComputerName"
                        "computer-name" = $ComputerName
                        "last-updated" = $PrinterReport.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
                        "updated-by" = "$($PrinterReport.Domain)\$($PrinterReport.UserName)"
                        "printer-status" = $printerStatusHTML
                        "success-count" = $PrinterReport.Success
                        "failed-count" = $PrinterReport.Failed
                        "skipped-count" = $PrinterReport.Skipped
                    }
                }
            }
        } | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri $assetURL -Method Post -Headers $Headers -Body $assetData -ErrorAction Stop

        Write-Host "Created IT Glue flexible asset for $ComputerName" -ForegroundColor Green
        return $response.data.id
    }
    catch {
        Write-Warning "Failed to create IT Glue flexible asset: $($_.Exception.Message)"
        if ($_.ErrorDetails.Message) {
            Write-Warning "Details: $($_.ErrorDetails.Message)"
        }
        return $null
    }
}

function Update-ITGlueConfigurationItem {
    param(
        [int]$ConfigurationID,
        [object]$PrinterReport,
        [hashtable]$Headers,
        [string]$BaseURL
    )

    try {
        $updateURL = "$BaseURL/configurations/$ConfigurationID"

        $notes = @"
=== Printer Configuration Updated ===
Timestamp: $($PrinterReport.Timestamp)
User: $($PrinterReport.Domain)\$($PrinterReport.UserName)

Installed Printers ($($PrinterReport.Success)):
$($PrinterReport.InstalledPrinters | ForEach-Object { "- $($_.Name) at $($_.IP)" } | Out-String)

Failed Printers ($($PrinterReport.Failed)):
$($PrinterReport.FailedPrinters | ForEach-Object { "- $($_.Name) at $($_.IP) - $($_.Reason)" } | Out-String)

Skipped Printers ($($PrinterReport.Skipped)):
(Printers were unreachable during installation)

Duration: $($PrinterReport.Duration) seconds
"@

        $updateData = @{
            data = @{
                type = "configurations"
                attributes = @{
                    notes = $notes
                }
            }
        } | ConvertTo-Json -Depth 10

        Invoke-RestMethod -Uri $updateURL -Method Patch -Headers $Headers -Body $updateData -ErrorAction Stop

        Write-Host "Updated IT Glue configuration item #$ConfigurationID" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to update IT Glue configuration item: $($_.Exception.Message)"
    }
}

function New-ITGlueDocumentationNote {
    param(
        [int]$OrganizationID,
        [object]$PrinterReport,
        [hashtable]$Headers,
        [string]$BaseURL
    )

    try {
        # Create a general documentation note about the printer remap
        $noteURL = "$BaseURL/organizations/$OrganizationID/relationships/notes"

        $noteBody = @"
<h2>Printer Remapping Event</h2>
<p><strong>Computer:</strong> $($PrinterReport.ComputerName)</p>
<p><strong>User:</strong> $($PrinterReport.Domain)\$($PrinterReport.UserName)</p>
<p><strong>Timestamp:</strong> $($PrinterReport.Timestamp)</p>
<p><strong>Duration:</strong> $($PrinterReport.Duration) seconds</p>

<h3>Summary</h3>
<ul>
<li>Successfully Installed: $($PrinterReport.Success)</li>
<li>Failed: $($PrinterReport.Failed)</li>
<li>Skipped: $($PrinterReport.Skipped)</li>
</ul>

<h3>Installed Printers</h3>
<ul>
$($PrinterReport.InstalledPrinters | ForEach-Object { "<li>$($_.Name) - $($_.Path)</li>" } | Out-String)
</ul>

$(if ($PrinterReport.FailedPrinters.Count -gt 0) {
"<h3>Failed Printers</h3>
<ul>
$($PrinterReport.FailedPrinters | ForEach-Object { "<li>$($_.Name) ($($_.IP)) - $($_.Reason)</li>" } | Out-String)
</ul>"
})

<p><em>This documentation was automatically generated by the Printer Remapping Script.</em></p>
"@

        $noteData = @{
            data = @{
                type = "notes"
                attributes = @{
                    body = $noteBody
                }
            }
        } | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri $noteURL -Method Post -Headers $Headers -Body $noteData -ErrorAction Stop

        Write-Host "Created IT Glue documentation note" -ForegroundColor Green
        return $response.data.id
    }
    catch {
        Write-Warning "Failed to create IT Glue note: $($_.Exception.Message)"
        return $null
    }
}
#EndRegion

#Region Main Integration Function
function Send-ITGlueDocumentation {
    param(
        [object]$PrinterReport
    )

    try {
        if (-not $itGlueConfig.UpdateFlexibleAssets -and -not $itGlueConfig.UpdateConfigurationItems) {
            Write-Host "IT Glue integration is disabled in configuration"
            return
        }

        # Get IT Glue headers
        $headers = Get-ITGlueHeaders -APIKey $itGlueConfig.APIKey

        # Find organization
        $organizationID = Find-ITGlueOrganization -ComputerName $PrinterReport.ComputerName `
                                                  -Headers $headers `
                                                  -BaseURL $itGlueConfig.BaseURL

        if (-not $organizationID) {
            Write-Warning "Cannot proceed with IT Glue integration - organization not found"
            return
        }

        Write-Host "Using IT Glue organization ID: $organizationID"

        # Create or update flexible asset
        if ($itGlueConfig.UpdateFlexibleAssets) {
            $assetID = New-ITGlueFlexibleAsset -OrganizationID $organizationID `
                                               -ComputerName $PrinterReport.ComputerName `
                                               -PrinterReport $PrinterReport `
                                               -Config $itGlueConfig `
                                               -Headers $headers `
                                               -BaseURL $itGlueConfig.BaseURL
        }

        # Update configuration item
        if ($itGlueConfig.UpdateConfigurationItems) {
            $configID = Find-ITGlueConfigurationItem -OrganizationID $organizationID `
                                                     -ComputerName $PrinterReport.ComputerName `
                                                     -Headers $headers `
                                                     -BaseURL $itGlueConfig.BaseURL

            if ($configID) {
                Update-ITGlueConfigurationItem -ConfigurationID $configID `
                                              -PrinterReport $PrinterReport `
                                              -Headers $headers `
                                              -BaseURL $itGlueConfig.BaseURL
            }
            else {
                Write-Warning "Configuration item not found for $($PrinterReport.ComputerName)"
            }
        }

        # Create documentation note for significant events
        if ($PrinterReport.Failed -gt 0) {
            New-ITGlueDocumentationNote -OrganizationID $organizationID `
                                       -PrinterReport $PrinterReport `
                                       -Headers $headers `
                                       -BaseURL $itGlueConfig.BaseURL
        }

        Write-Host "IT Glue documentation integration completed successfully" -ForegroundColor Green
    }
    catch {
        Write-Warning "IT Glue integration error: $($_.Exception.Message)"
    }
}
#EndRegion

# Export function for use in main script
Export-ModuleMember -Function Send-ITGlueDocumentation
