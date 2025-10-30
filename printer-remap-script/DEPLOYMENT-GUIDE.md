# Printer Remapping Script - Complete Deployment Guide

## Overview

This comprehensive printer remapping solution includes multiple deployment methods, reporting features, and integrations with Autotask PSA and IT Glue documentation.

## 📁 File Structure

```
PrinterRemapScript/
├── RemapPrinters.ps1                    # Basic GUI version
├── RemapPrinters-Enhanced.ps1           # Advanced version with reporting
├── PrinterConfig.json                   # Basic configuration
├── PrinterConfig-Enhanced.json          # Enhanced configuration with reporting
├── Datto-PrinterRemapComponent.ps1      # Datto RMM component script
├── Intune-Detection.ps1                 # Intune proactive remediation (detect)
├── Intune-Remediation.ps1               # Intune proactive remediation (fix)
├── Autotask-Integration.ps1             # Autotask PSA integration module
├── ITGlue-Integration.ps1               # IT Glue documentation module
├── README.md                            # Basic documentation
└── DEPLOYMENT-GUIDE.md                  # This file
```

## 🚀 Deployment Options

### Option 1: Desktop Script (End User)

**Best for:** Users who manually run printer remapping when needed

**Steps:**
1. Copy `RemapPrinters-Enhanced.ps1` and `PrinterConfig-Enhanced.json` to user's Desktop
2. Edit `PrinterConfig-Enhanced.json` with your printer details
3. Configure reporting settings (CSV export, email, webhooks)
4. Create a shortcut for easy access
5. User double-clicks to run

**Features:**
- GUI with progress bar
- Ping tests before mapping
- CSV export to network share
- Usage tracking (who uses it most)
- Email/webhook notifications
- Detailed logging

### Option 2: Datto RMM Component

**Best for:** Automated deployment across multiple endpoints via Datto RMM

**Steps:**
1. Open `Datto-PrinterRemapComponent.ps1`
2. Edit the configuration section with your printer details:
   ```powershell
   $printerConfig = @{
       UniversalPrintPath = "\\your-print-server\printers"
       Printers = @(
           @{ Name = "Printer1"; IP = "192.168.1.10"; ShareName = "Printer-1" }
           # Add your printers here
       )
   }
   ```
3. Configure custom field names in Datto:
   ```powershell
   $customFields = @{
       LastRemapDate = "PrinterRemapDate"
       RemapStatus = "PrinterRemapStatus"
       # etc...
   }
   ```
4. Create these custom fields in Datto RMM
5. Upload script as a Component in Datto
6. Schedule or run on-demand

**Custom Fields Tracked:**
- `PrinterRemapDate` - Last execution timestamp
- `PrinterRemapStatus` - SUCCESS/PARTIAL/FAILED
- `PrinterRemapResults` - Summary statistics
- `PrinterRemapFailed` - List of failed printers
- `PrintersInstalled` - Count of installed printers

**Benefits:**
- Centralized deployment
- Custom field reporting
- Scheduled execution
- Activity log integration

### Option 3: Intune Proactive Remediation

**Best for:** Microsoft Intune-managed devices with automatic detection and fixing

**Steps:**

1. **Create Detection Script:**
   - In Intune portal → Devices → Scripts and remediations → Remediations
   - Click "Create"
   - Name: "Printer Configuration Check"
   - Upload `Intune-Detection.ps1`

2. **Edit Detection Script Configuration:**
   ```powershell
   $requiredPrinters = @(
       @{ Name = "Printer1"; IP = "192.168.1.10"; SharePath = "\\server\printers\Printer-1" }
       # Add your printers
   )
   ```

3. **Create Remediation Script:**
   - Upload `Intune-Remediation.ps1`
   - Edit configuration section with your printers

4. **Configure Settings:**
   - Run script in user context: **No** (requires admin)
   - Run script as 32-bit: **No**
   - Enforce script signature check: **No** (unless you sign it)

5. **Assign to Device Groups**

6. **Set Schedule:**
   - Recommended: Daily or Weekly
   - Detection runs first
   - Remediation only runs if detection fails

**How It Works:**
- Detection checks if all printers are installed and reachable
- If issues detected → Remediation runs automatically
- Registry tracks last successful remap
- Logs to: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\PrinterRemap.log`

**Benefits:**
- Fully automated
- Self-healing
- Built-in reporting in Intune portal
- No user interaction needed

## 🔧 Configuration

### Basic Printer Configuration

Edit your JSON config file:

```json
{
  "UniversalPrintPath": "\\\\your-print-server\\printers",
  "Printers": [
    {
      "Name": "Office Printer 1",
      "IP": "192.168.1.10",
      "ShareName": "Printer-Office-1"
    },
    {
      "Name": "Office Printer 2",
      "IP": "192.168.1.11",
      "ShareName": "Printer-Office-2"
    },
    {
      "Name": "Accounting Printer",
      "IP": "192.168.1.20",
      "ShareName": "Printer-Accounting"
    },
    {
      "Name": "Warehouse Printer",
      "IP": "192.168.1.30",
      "ShareName": "Printer-Warehouse"
    }
  ]
}
```

### Enhanced Reporting Configuration

In `PrinterConfig-Enhanced.json`:

```json
{
  "Reporting": {
    "EnableCSVExport": true,
    "CSVPath": "\\\\file-server\\IT\\PrinterReports",

    "EnableEmailReport": true,
    "EmailSettings": {
      "SMTPServer": "smtp.office365.com",
      "SMTPPort": 587,
      "FromAddress": "it-alerts@company.com",
      "ToAddress": "it-team@company.com",
      "UseSSL": true,
      "RequiresAuth": true
    },

    "EnableWebhook": true,
    "WebhookURL": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",

    "EnableUsageTracking": true,
    "UsageTrackingPath": "\\\\file-server\\IT\\PrinterUsage"
  }
}
```

## 📊 Reporting Features

### CSV Export

**Location:** Configurable network path
**Filename:** `PrinterRemap_COMPUTERNAME_TIMESTAMP.csv`

**Columns:**
- Timestamp
- ComputerName
- UserName
- Domain
- SuccessCount
- FailedCount
- SkippedCount
- RemovedPrinters
- InstalledPrinters
- FailedPrinters
- DurationSeconds

### Usage Tracking

**Automatic Generation of:**
- Individual execution logs
- Usage summary (after 10+ executions)
- Top users by usage
- Top computers by usage
- Success rate statistics
- Average duration

**Files Created:**
- `PrinterRemapUsage.csv` - All executions
- `UsageSummary.txt` - Aggregated statistics

**Use Cases:**
- Identify users who need training
- Find problematic computers
- Track adoption
- Identify frequently failing printers

### Email Reports

HTML-formatted emails with:
- Execution summary
- Success/failure counts
- List of removed printers
- List of installed printers
- List of failed printers with reasons
- Duration

### Webhook Notifications

Slack/Teams compatible format with:
- Status emoji (✅ or ⚠️)
- Computer and user info
- Success/failed/skipped counts
- Duration

**Example Slack Webhook Setup:**
1. Create incoming webhook in Slack
2. Copy webhook URL
3. Add to config file
4. Enable webhook notifications

## 🎫 Autotask PSA Integration

### Setup

1. **Get API Credentials:**
   - Log into Autotask
   - Admin → Resources → API Users
   - Create API user
   - Generate integration code

2. **Edit `Autotask-Integration.ps1`:**
   ```powershell
   $autotaskConfig = @{
       APIUsername = "your-api-username@company.com"
       APISecret = "your-api-secret"
       APIIntegrationCode = "your-integration-code"
       BaseURL = "https://webservices.autotask.net/ATServicesRest/V1.0"

       QueueID = 12345  # Your queue ID
       IssueTypeID = 67
       TicketCategoryID = 89
       PriorityID = 3  # 1=Critical, 2=High, 3=Medium, 4=Low

       CreateTicketsForFailures = $true
       MinimumFailuresForTicket = 2  # Only create ticket if 2+ printers fail
   }
   ```

3. **Import Module in Your Script:**
   ```powershell
   Import-Module .\Autotask-Integration.ps1
   Send-AutotaskReport -PrinterReport $script:executionReport
   ```

### Features

**Automatic Ticket Creation:**
- Creates ticket when failure threshold is met
- Includes full details of failures
- Links to correct company
- Sets appropriate priority/queue

**Configuration Item Updates:**
- Updates asset notes with printer status
- Tracks last remap date
- Documents installed printers

## 📚 IT Glue Documentation Integration

### Setup

1. **Get API Key:**
   - Log into IT Glue
   - Account → API Keys
   - Generate new API key

2. **Edit `ITGlue-Integration.ps1`:**
   ```powershell
   $itGlueConfig = @{
       APIKey = "your-it-glue-api-key"
       BaseURL = "https://api.itglue.com"

       UpdateFlexibleAssets = $true
       FlexibleAssetTypeID = 12345  # Your flexible asset type

       UpdateConfigurationItems = $true
   }
   ```

3. **Create Flexible Asset Type (Optional):**
   - Name: "Printer Configuration"
   - Fields:
     - Computer Name (Text)
     - Last Updated (Date)
     - Updated By (Text)
     - Printer Status (Textbox - Rich Text)
     - Success Count (Number)
     - Failed Count (Number)
     - Skipped Count (Number)

4. **Import Module:**
   ```powershell
   Import-Module .\ITGlue-Integration.ps1
   Send-ITGlueDocumentation -PrinterReport $script:executionReport
   ```

### Features

**Flexible Asset Management:**
- Creates/updates printer configuration assets
- HTML-formatted status tables
- Tracks success/failure counts

**Configuration Item Updates:**
- Updates computer CI notes
- Documents printer status
- Timestamps all changes

**Documentation Notes:**
- Creates notes for significant events
- Includes full details
- Automatically links to organization

## 🔍 Troubleshooting

### Script Won't Run

**Error:** "Execution of scripts is disabled on this system"

**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Or right-click script → Properties → Unblock

### Printers Not Installing

**Check:**
1. Universal print path is correct
2. Share names match exactly
3. User has permissions to print server
4. Print server is reachable from computer

**Test Manually:**
```powershell
Add-Printer -ConnectionName "\\print-server\printers\Printer-Name"
```

### Ping Tests Failing

**Common Causes:**
- Printer is offline
- Firewall blocking ICMP
- Wrong IP address in config

**Test Manually:**
```powershell
Test-Connection -ComputerName 192.168.1.10 -Count 2
```

### CSV Export Not Working

**Check:**
1. Network path exists
2. User has write permissions
3. Path uses UNC format (`\\server\share`)

**Create Manually:**
```powershell
New-Item -ItemType Directory -Path "\\server\share\PrinterReports" -Force
```

### Datto Custom Fields Not Updating

**Verify:**
1. Custom field names match exactly
2. Fields are created in Datto
3. Component has permissions

### Intune Remediation Not Running

**Check:**
1. Device is checking in to Intune
2. Script is assigned to correct group
3. Schedule is configured
4. Review detection output in Intune portal

### Autotask Tickets Not Creating

**Common Issues:**
- API credentials incorrect
- Company not found in Autotask
- Queue/Issue Type IDs wrong

**Test Connection:**
```powershell
$headers = Get-AutotaskHeaders -Username "..." -Secret "..." -IntegrationCode "..."
Invoke-RestMethod -Uri "https://webservices.autotask.net/ATServicesRest/V1.0/Companies/query" -Headers $headers
```

### IT Glue Not Updating

**Verify:**
1. API key is valid
2. Organization exists
3. Flexible asset type ID is correct

**Test Connection:**
```powershell
$headers = @{ "x-api-key" = "your-key"; "Content-Type" = "application/vnd.api+json" }
Invoke-RestMethod -Uri "https://api.itglue.com/organizations" -Headers $headers
```

## 📈 Usage Analytics

### Viewing Usage Tracking Data

**Location:** `\\file-server\IT\PrinterUsage\PrinterRemapUsage.csv`

**Import into Excel/Power BI:**
```powershell
$usage = Import-Csv "\\file-server\IT\PrinterUsage\PrinterRemapUsage.csv"

# Top 10 users
$usage | Group-Object UserName | Sort-Object Count -Descending | Select-Object -First 10

# Success rate
$totalSuccess = ($usage | Measure-Object -Property Success -Sum).Sum
$totalFailed = ($usage | Measure-Object -Property Failed -Sum).Sum
$successRate = [math]::Round(($totalSuccess / ($totalSuccess + $totalFailed)) * 100, 2)
Write-Host "Success Rate: $successRate%"

# Average duration
$avgDuration = ($usage | Measure-Object -Property DurationSeconds -Average).Average
Write-Host "Average Duration: $avgDuration seconds"
```

### Key Metrics to Monitor

1. **Users with Most Executions** - May need training or have ongoing issues
2. **Computers with Most Executions** - Investigate persistent problems
3. **Success Rate** - Track overall health
4. **Average Duration** - Identify performance issues
5. **Failed Printer Patterns** - Find infrastructure problems

## 🔐 Security Considerations

### API Keys and Credentials

**DO NOT hardcode credentials in scripts!**

**Better Options:**

1. **Secure String Files:**
   ```powershell
   $securePassword = Read-Host -AsSecureString "Enter password"
   $securePassword | ConvertFrom-SecureString | Out-File "encrypted.txt"

   # Later, read it:
   $securePassword = Get-Content "encrypted.txt" | ConvertTo-SecureString
   ```

2. **Azure Key Vault** (for Intune scripts)

3. **Datto Secure Variables**

4. **Environment Variables**

### Permissions Required

**Desktop Script:**
- User context
- Network access to print server
- Write access to reporting shares (if configured)

**Datto/Intune:**
- SYSTEM context (admin rights)
- Network access
- Registry write (for tracking)

## 📅 Recommended Schedules

| Deployment Method | Recommended Schedule | Rationale |
|------------------|---------------------|-----------|
| Desktop Script | On-demand | User-initiated |
| Datto RMM | Weekly | Proactive maintenance |
| Intune Remediation | Daily | Quick detection & fix |

## 🎯 Best Practices

1. **Test in Dev First** - Always test on non-production devices
2. **Backup Printer List** - Document current printers before mass deployment
3. **Stagger Rollout** - Deploy to pilot group first
4. **Monitor Logs** - Review logs daily during initial rollout
5. **Document Failures** - Track patterns in failed installations
6. **Update Documentation** - Keep IT Glue/Autotask current
7. **Review Usage Data** - Weekly review of usage tracking
8. **Automate Where Possible** - Prefer Intune/Datto over manual

## 📞 Support

For issues or questions:
1. Check troubleshooting section above
2. Review log files (locations vary by deployment method)
3. Check Datto/Intune portal for execution results
4. Review Autotask tickets for failure patterns

## 🔄 Maintenance

### Monthly Tasks
- Review usage statistics
- Check success rates
- Update printer configurations
- Review IT Glue documentation
- Close old Autotask tickets

### Quarterly Tasks
- Audit printer inventory
- Review and optimize configurations
- Update API credentials if needed
- Test disaster recovery

### Annual Tasks
- Full security audit
- Review all integrations
- Update documentation
- Train new IT staff
