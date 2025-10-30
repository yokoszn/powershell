# Printer Remapping Script - Quick Start Guide

## What You Get

A complete printer management solution with:
- ✅ GUI for users with progress bar
- ✅ Automatic ping testing before mapping
- ✅ CSV reports to network share
- ✅ Usage tracking (see who uses it most)
- ✅ Email to helpdesk on failures (auto-creates tickets)
- ✅ Datto RMM component for mass deployment
- ✅ Intune proactive remediation (auto-healing)
- ✅ Detailed logging

## 5-Minute Desktop Setup

### Step 1: Configure Printers

Edit `PrinterConfig-Enhanced.json`:

```json
{
  "UniversalPrintPath": "\\\\YOUR-PRINT-SERVER\\printers",
  "Printers": [
    {
      "Name": "Main Office Printer",
      "IP": "192.168.1.10",
      "ShareName": "Office-HP-M479"
    },
    {
      "Name": "Warehouse Printer",
      "IP": "192.168.1.20",
      "ShareName": "Warehouse-Brother"
    }
  ]
}
```

### Step 2: Configure Reporting

Still in `PrinterConfig-Enhanced.json`, update the reporting section:

```json
"Reporting": {
  "EnableCSVExport": true,
  "CSVPath": "\\\\file-server\\IT\\PrinterReports",

  "EnableEmailReport": true,
  "EmailSettings": {
    "SMTPServer": "smtp.office365.com",
    "SMTPPort": 587,
    "FromAddress": "printer-remap@yourcompany.com",
    "ToAddress": "helpdesk@yourcompany.com",
    "UseSSL": true,
    "RequiresAuth": false,
    "OnlyEmailOnFailure": true
  },

  "EnableUsageTracking": true,
  "UsageTrackingPath": "\\\\file-server\\IT\\PrinterUsage"
}
```

**What this does:**
- Saves detailed CSV reports to a network share
- Sends email to helpdesk ONLY when printers fail to install
- Tracks who uses the script and how often

### Step 3: Deploy to Users

1. Copy both files to user Desktop:
   - `RemapPrinters-Enhanced.ps1`
   - `PrinterConfig-Enhanced.json`

2. Create shortcut (optional but nice):
   - Right-click `RemapPrinters-Enhanced.ps1`
   - Send to → Desktop (create shortcut)
   - Rename to "Fix Printers"

3. Done! Users double-click when they need printer remapping

## Usage Analytics (Who Uses It Most)

The script automatically tracks usage. After 10+ executions, view stats:

**Location:** `\\file-server\IT\PrinterUsage\UsageSummary.txt`

**Shows:**
- Top 5 users by execution count
- Top 5 computers with most runs
- Overall success rate
- Average duration

**Use this to:**
- Identify users who need training
- Find computers with persistent issues
- Track script effectiveness

## Email Integration with Helpdesk

When failures occur, an HTML email is sent to your helpdesk address with:

**Subject:** `Printer Remap Report - COMPUTERNAME - 2025-10-31 14:30`

**Contains:**
- Computer name and user
- Success/Failed/Skipped counts
- List of removed printers
- List of successfully installed printers
- List of FAILED printers with reasons (ping failed, access denied, etc.)

**Your helpdesk can:**
- Auto-create tickets via email rules (Autotask, Freshdesk, etc.)
- See exactly what failed and why
- Track printer issues over time

## Datto RMM Deployment

### Quick Setup

1. Edit `Datto-PrinterRemapComponent.ps1`
2. Update printer configuration (lines 12-20)
3. Create custom fields in Datto:
   - `PrinterRemapDate` (Date)
   - `PrinterRemapStatus` (Text)
   - `PrinterRemapResults` (Text)
   - `PrinterRemapFailed` (Text)
   - `PrintersInstalled` (Number)

4. Upload to Datto as Component
5. Schedule or run on-demand

**Benefits:**
- Deploy to hundreds of computers instantly
- Monitor via custom fields
- Schedule weekly remapping
- View history in activity log

## Intune Proactive Remediation

### Setup (10 minutes)

1. **Create Remediation in Intune:**
   - Devices → Scripts and remediations → Remediations → Create

2. **Detection Script:**
   - Name: "Printer Configuration Check"
   - Upload `Intune-Detection.ps1`
   - Edit printer config in script (lines 4-9)

3. **Remediation Script:**
   - Upload `Intune-Remediation.ps1`
   - Edit printer config in script (lines 4-11)

4. **Settings:**
   - Run in user context: **No**
   - Schedule: **Daily**

5. **Assign to Device Group**

**How it works:**
- Detection runs daily checking if printers are installed
- If missing → Remediation automatically fixes it
- No user interaction needed
- Self-healing!

## Common Scenarios

### Scenario 1: User Calls "My printers are gone!"

**Solution:** Tell them to run the desktop script
- They double-click "Fix Printers"
- Progress bar shows them it's working
- 30 seconds later, printers are back
- If failures occur, email goes to helpdesk automatically

### Scenario 2: New office opened with new printers

**Solution:** Update the JSON config
```json
{
  "Name": "New Office Printer",
  "IP": "192.168.2.10",
  "ShareName": "NewOffice-Canon"
}
```
- Save to network share
- All users get new printer next time they run script

### Scenario 3: You want proactive monitoring

**Solution:** Deploy Intune remediation
- Detects missing printers automatically
- Fixes them without user knowing
- You see reports in Intune dashboard

### Scenario 4: You want to see usage trends

**Solution:** Check usage tracking
- Open `\\file-server\IT\PrinterUsage\UsageSummary.txt`
- See who's using the script most
- Identify problematic computers
- Track effectiveness

## Troubleshooting

### Script won't run
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Printers not installing
- Check print server path is correct
- Verify share names match exactly
- Test manually: `Add-Printer -ConnectionName "\\server\printers\PrinterName"`

### No emails being sent
- Check SMTP settings
- Verify `OnlyEmailOnFailure: true` (won't email on success)
- Test with a forced failure

### CSV reports not saving
- Check network path exists
- Verify write permissions
- Try creating folder manually

## Files Explained

| File | Purpose | Deploy To |
|------|---------|-----------|
| `RemapPrinters-Enhanced.ps1` | Main script with GUI | User desktops |
| `PrinterConfig-Enhanced.json` | Configuration file | User desktops or network share |
| `Datto-PrinterRemapComponent.ps1` | Datto RMM version | Datto RMM portal |
| `Intune-Detection.ps1` | Checks printer status | Intune portal |
| `Intune-Remediation.ps1` | Fixes missing printers | Intune portal |
| `Webhook-Handler.ps1` | Optional server-side processor | Your server (optional) |
| `Autotask-Integration.ps1` | Autotask API (server-side only) | Your server (optional) |
| `ITGlue-Integration.ps1` | IT Glue API (server-side only) | Your server (optional) |

**Note:** The Autotask and IT Glue integrations are **server-side only** - never deploy these to endpoints!

## Security Best Practices

✅ **DO:**
- Email helpdesk for ticketing
- Store CSV reports on network share
- Use Intune/Datto for deployment

❌ **DON'T:**
- Put API keys in desktop scripts
- Hardcode passwords
- Deploy Autotask/IT Glue integration scripts to endpoints

## Next Steps

1. Test with one computer first
2. Roll out to pilot group (5-10 users)
3. Monitor CSV reports and emails
4. Review usage tracking after a week
5. Deploy via Intune or Datto for automation
6. Set up email rules in helpdesk for auto-ticketing

## Questions?

**"How do I update printers for everyone?"**
- Option A: Update JSON on each computer
- Option B: Store JSON on network share, update once
- Option C: Update Intune/Datto script and redeploy

**"Can I add more than 4 printers?"**
- Yes! Add as many as you want to the JSON array

**"Will it remove my default printer?"**
- Yes - it removes ALL network printers. Set default after running.

**"Can I schedule this automatically?"**
- Yes! Use Intune remediation (daily) or Datto (weekly)

**"How do I know if it's working?"**
- Check CSV reports in `\\file-server\IT\PrinterReports`
- Review usage summary for statistics
- Emails sent to helpdesk on failures

**"What if a printer is offline?"**
- Script pings first - offline printers are skipped
- Logged as "skipped" not "failed"
- User can re-run when printer is online

## Support

For issues:
1. Check log file: `PrinterRemap.log` (same folder as script)
2. Review CSV reports
3. Check email sent to helpdesk (if failures occurred)
