# Universal Print Diagnostic and Reporting Script
# Tests connectivity, validates configuration, and generates diagnostic report
# Run this SEPARATELY from the remapping script to troubleshoot issues

param(
    [string]$ConfigFile = (Join-Path $PSScriptRoot "PrinterShares.json"),
    [string]$ReportPath = (Join-Path $env:LOCALAPPDATA "PrinterRemap\diagnostics_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"),
    [switch]$Detailed
)

# Ensure report directory exists
$reportDir = Split-Path $ReportPath -Parent
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

# Report output
$script:report = @()

function Add-ReportLine {
    param([string]$Line)
    $script:report += $Line
    Write-Host $Line
}

function Add-ReportSection {
    param([string]$Title)
    Add-ReportLine ""
    Add-ReportLine "=" * 80
    Add-ReportLine $Title
    Add-ReportLine "=" * 80
}

# Test 1: Environment Information
function Test-Environment {
    Add-ReportSection "ENVIRONMENT INFORMATION"

    Add-ReportLine "Date/Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Add-ReportLine "Computer Name: $env:COMPUTERNAME"
    Add-ReportLine "Username: $env:USERNAME"
    Add-ReportLine "Domain: $env:USERDOMAIN"
    Add-ReportLine "PowerShell Version: $($PSVersionTable.PSVersion)"
    Add-ReportLine "OS: $([Environment]::OSVersion.VersionString)"

    # Check if running as admin
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Add-ReportLine "Running as Administrator: $isAdmin"

    return $true
}

# Test 2: Check for UPPrinterInstaller.exe
function Test-UPPrinterInstaller {
    Add-ReportSection "UNIVERSAL PRINT INSTALLER CHECK"

    $installerPaths = @(
        "$env:SystemRoot\System32\UPPrinterInstaller.exe",
        "$env:ProgramFiles\Windows NT\Printer\UPPrinterInstaller.exe",
        "C:\Windows\System32\UPPrinterInstaller.exe"
    )

    $found = $false
    foreach ($path in $installerPaths) {
        if (Test-Path $path) {
            Add-ReportLine "[OK] Found UPPrinterInstaller.exe at: $path"

            # Get file version
            $fileInfo = Get-Item $path
            Add-ReportLine "     Version: $($fileInfo.VersionInfo.FileVersion)"
            Add-ReportLine "     Size: $([math]::Round($fileInfo.Length/1KB, 2)) KB"
            Add-ReportLine "     Last Modified: $($fileInfo.LastWriteTime)"

            $found = $true
            break
        }
    }

    if (-not $found) {
        Add-ReportLine "[ERROR] UPPrinterInstaller.exe not found in any expected location!"
        Add-ReportLine "        This is required for Universal Print installation."
        Add-ReportLine "        Expected locations checked:"
        foreach ($path in $installerPaths) {
            Add-ReportLine "        - $path"
        }
        return $false
    }

    return $true
}

# Test 3: PowerShell Modules
function Test-PowerShellModules {
    Add-ReportSection "POWERSHELL MODULES CHECK"

    # Check Microsoft.Graph modules
    $graphModules = @(
        "Microsoft.Graph.DeviceManagement.Actions",
        "Microsoft.Graph.Authentication",
        "Microsoft.Graph"
    )

    foreach ($moduleName in $graphModules) {
        $module = Get-Module -ListAvailable -Name $moduleName
        if ($module) {
            Add-ReportLine "[OK] $moduleName is installed"
            Add-ReportLine "     Version: $($module.Version)"
        }
        else {
            Add-ReportLine "[WARN] $moduleName is NOT installed"
            Add-ReportLine "       Install with: Install-Module $moduleName -Scope CurrentUser"
        }
    }

    Add-ReportLine ""

    # Check UniversalPrintManagement module (legacy)
    $upModule = Get-Module -ListAvailable -Name UniversalPrintManagement
    if ($upModule) {
        Add-ReportLine "[OK] UniversalPrintManagement module is installed"
        Add-ReportLine "     Version: $($upModule.Version)"
    }
    else {
        Add-ReportLine "[INFO] UniversalPrintManagement module is NOT installed (optional)"
    }

    return $true
}

# Test 4: Microsoft Graph Connectivity
function Test-GraphConnectivity {
    Add-ReportSection "MICROSOFT GRAPH CONNECTIVITY TEST"

    try {
        # Check if module is available
        if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
            Add-ReportLine "[SKIP] Microsoft.Graph.Authentication module not available"
            return $false
        }

        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

        # Check existing connection
        $context = Get-MgContext -ErrorAction SilentlyContinue

        if ($context) {
            Add-ReportLine "[OK] Already connected to Microsoft Graph"
            Add-ReportLine "     Account: $($context.Account)"
            Add-ReportLine "     Tenant: $($context.TenantId)"
            Add-ReportLine "     Scopes: $($context.Scopes -join ', ')"
        }
        else {
            Add-ReportLine "[INFO] Not currently connected to Microsoft Graph"
            Add-ReportLine "       Attempting connection..."

            # Try to connect
            try {
                Connect-MgGraph -Scopes "Printer.Read.All", "PrinterShare.ReadBasic.All" -ErrorAction Stop -NoWelcome
                Add-ReportLine "[OK] Successfully connected to Microsoft Graph"

                $context = Get-MgContext
                Add-ReportLine "     Account: $($context.Account)"
                Add-ReportLine "     Tenant: $($context.TenantId)"
            }
            catch {
                Add-ReportLine "[ERROR] Failed to connect to Microsoft Graph"
                Add-ReportLine "        Error: $($_.Exception.Message)"
                return $false
            }
        }

        return $true
    }
    catch {
        Add-ReportLine "[ERROR] Microsoft Graph connectivity test failed"
        Add-ReportLine "        Error: $($_.Exception.Message)"
        return $false
    }
}

# Test 5: Get Universal Print Shares
function Test-PrinterShares {
    Add-ReportSection "UNIVERSAL PRINT SHARES TEST"

    try {
        if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.DeviceManagement.Actions)) {
            Add-ReportLine "[SKIP] Microsoft.Graph.DeviceManagement.Actions module not available"
            return $false
        }

        Import-Module Microsoft.Graph.DeviceManagement.Actions -ErrorAction Stop

        Add-ReportLine "Retrieving printer shares from Microsoft Graph..."

        $shares = Get-MgPrintShare -All -ErrorAction Stop

        if ($shares.Count -eq 0) {
            Add-ReportLine "[WARN] No printer shares found in tenant"
            Add-ReportLine "       Ensure Universal Print is set up and printers are shared"
            return $false
        }

        Add-ReportLine "[OK] Found $($shares.Count) printer share(s):"
        Add-ReportLine ""

        foreach ($share in $shares) {
            Add-ReportLine "  Printer Share: $($share.DisplayName)"
            Add-ReportLine "  ID: $($share.Id)"

            if ($Detailed) {
                Add-ReportLine "  Capabilities: $($share.Capabilities -join ', ')"
                Add-ReportLine "  Status: $($share.Status)"

                if ($share.Printer) {
                    Add-ReportLine "  Printer Name: $($share.Printer.DisplayName)"
                }
            }

            Add-ReportLine ""
        }

        return $true
    }
    catch {
        Add-ReportLine "[ERROR] Failed to retrieve printer shares"
        Add-ReportLine "        Error: $($_.Exception.Message)"
        Add-ReportLine "        Ensure you have the correct permissions and licenses"
        return $false
    }
}

# Test 6: Current Printer Configuration
function Test-CurrentPrinters {
    Add-ReportSection "CURRENT PRINTER CONFIGURATION"

    try {
        $allPrinters = Get-Printer -ErrorAction Stop

        Add-ReportLine "Total Printers: $($allPrinters.Count)"
        Add-ReportLine ""

        # Network printers
        $networkPrinters = $allPrinters | Where-Object { $_.Type -eq "Connection" }
        Add-ReportLine "Network/Connection Printers: $($networkPrinters.Count)"
        foreach ($printer in $networkPrinters) {
            Add-ReportLine "  - $($printer.Name)"
            if ($Detailed) {
                Add-ReportLine "    Port: $($printer.PortName)"
                Add-ReportLine "    Driver: $($printer.DriverName)"
                Add-ReportLine "    Shared: $($printer.Shared)"
            }
        }
        Add-ReportLine ""

        # Local printers
        $localPrinters = $allPrinters | Where-Object { $_.Type -eq "Local" }
        Add-ReportLine "Local Printers: $($localPrinters.Count)"
        foreach ($printer in $localPrinters) {
            Add-ReportLine "  - $($printer.Name)"
        }

        return $true
    }
    catch {
        Add-ReportLine "[ERROR] Failed to retrieve current printers"
        Add-ReportLine "        Error: $($_.Exception.Message)"
        return $false
    }
}

# Test 7: Network Connectivity to Printer IPs (from config)
function Test-PrinterIPConnectivity {
    Add-ReportSection "NETWORK CONNECTIVITY TEST (FROM CONFIG)"

    if (-not (Test-Path $ConfigFile)) {
        Add-ReportLine "[SKIP] Config file not found: $ConfigFile"
        return $true
    }

    try {
        $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json

        if (-not $config.PrinterIPs) {
            Add-ReportLine "[INFO] No PrinterIPs section in config file"
            Add-ReportLine "       Add 'PrinterIPs': ['192.168.1.10', '192.168.1.11'] to test physical printer connectivity"
            return $true
        }

        Add-ReportLine "Testing connectivity to physical printer IPs..."
        Add-ReportLine ""

        $failed = $false
        foreach ($ip in $config.PrinterIPs) {
            try {
                $ping = Test-Connection -ComputerName $ip -Count 2 -Quiet -ErrorAction Stop

                if ($ping) {
                    Add-ReportLine "[OK] $ip is reachable"

                    if ($Detailed) {
                        $pingDetails = Test-Connection -ComputerName $ip -Count 2
                        $avgTime = ($pingDetails | Measure-Object -Property ResponseTime -Average).Average
                        Add-ReportLine "     Average response time: $([math]::Round($avgTime, 2)) ms"
                    }
                }
                else {
                    Add-ReportLine "[ERROR] $ip is NOT reachable"
                    $failed = $true
                }
            }
            catch {
                Add-ReportLine "[ERROR] $ip - $($_.Exception.Message)"
                $failed = $true
            }
        }

        if ($failed) {
            return $false
        }
        return $true
    }
    catch {
        Add-ReportLine "[ERROR] Failed to read config file"
        Add-ReportLine "        Error: $($_.Exception.Message)"
        return $false
    }
}

# Test 8: Windows Print Service
function Test-PrintService {
    Add-ReportSection "WINDOWS PRINT SERVICE CHECK"

    try {
        $spooler = Get-Service -Name Spooler -ErrorAction Stop

        Add-ReportLine "Print Spooler Service:"
        Add-ReportLine "  Status: $($spooler.Status)"
        Add-ReportLine "  Start Type: $($spooler.StartType)"

        if ($spooler.Status -ne "Running") {
            Add-ReportLine "[WARN] Print Spooler is not running!"
            return $false
        }

        Add-ReportLine "[OK] Print Spooler is running"
        return $true
    }
    catch {
        Add-ReportLine "[ERROR] Failed to check Print Spooler service"
        Add-ReportLine "        Error: $($_.Exception.Message)"
        return $false
    }
}

# Test 9: Internet Connectivity
function Test-InternetConnectivity {
    Add-ReportSection "INTERNET CONNECTIVITY TEST"

    $testUrls = @(
        "https://universalprint.windows.net",
        "https://graph.microsoft.com",
        "https://login.microsoftonline.com"
    )

    $allSucceeded = $true
    foreach ($url in $testUrls) {
        try {
            $response = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            Add-ReportLine "[OK] $url is reachable (Status: $($response.StatusCode))"
        }
        catch {
            Add-ReportLine "[ERROR] $url is NOT reachable"
            Add-ReportLine "        Error: $($_.Exception.Message)"
            $allSucceeded = $false
        }
    }

    return $allSucceeded
}

# Test 10: Validate Config File
function Test-ConfigFile {
    Add-ReportSection "CONFIGURATION FILE VALIDATION"

    Add-ReportLine "Config File: $ConfigFile"

    if (-not (Test-Path $ConfigFile)) {
        Add-ReportLine "[WARN] Config file not found"
        Add-ReportLine "       Script will attempt to use Microsoft Graph to discover printers"
        return $true
    }

    try {
        $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        Add-ReportLine "[OK] Config file is valid JSON"

        if ($config.PrinterShares) {
            Add-ReportLine "[OK] Found $($config.PrinterShares.Count) printer share(s) in config:"
            foreach ($share in $config.PrinterShares) {
                Add-ReportLine "     - $($share.DisplayName) (ID: $($share.Id))"
            }
        }
        else {
            Add-ReportLine "[WARN] No PrinterShares section in config"
        }

        if ($config.PrinterIPs) {
            Add-ReportLine "[INFO] Found $($config.PrinterIPs.Count) printer IP(s) for connectivity testing"
        }

        return $true
    }
    catch {
        Add-ReportLine "[ERROR] Config file is invalid"
        Add-ReportLine "        Error: $($_.Exception.Message)"
        return $false
    }
}

# Main Execution
function Start-Diagnostics {
    Add-ReportLine "Universal Print Diagnostic Report"
    Add-ReportLine "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

    $tests = @(
        @{ Name = "Environment"; Function = { Test-Environment } }
        @{ Name = "UPPrinterInstaller"; Function = { Test-UPPrinterInstaller } }
        @{ Name = "PowerShell Modules"; Function = { Test-PowerShellModules } }
        @{ Name = "Config File"; Function = { Test-ConfigFile } }
        @{ Name = "Print Service"; Function = { Test-PrintService } }
        @{ Name = "Internet Connectivity"; Function = { Test-InternetConnectivity } }
        @{ Name = "Microsoft Graph"; Function = { Test-GraphConnectivity } }
        @{ Name = "Printer Shares"; Function = { Test-PrinterShares } }
        @{ Name = "Current Printers"; Function = { Test-CurrentPrinters } }
        @{ Name = "Printer IP Connectivity"; Function = { Test-PrinterIPConnectivity } }
    )

    $results = @{}

    foreach ($test in $tests) {
        try {
            $results[$test.Name] = & $test.Function
        }
        catch {
            Add-ReportLine ""
            Add-ReportLine "[CRITICAL ERROR] Test '$($test.Name)' failed with exception:"
            Add-ReportLine "                 $($_.Exception.Message)"
            $results[$test.Name] = $false
        }
    }

    # Summary
    Add-ReportSection "DIAGNOSTIC SUMMARY"

    $passCount = ($results.Values | Where-Object { $_ -eq $true }).Count
    $failCount = ($results.Values | Where-Object { $_ -eq $false }).Count

    Add-ReportLine "Tests Passed: $passCount"
    Add-ReportLine "Tests Failed: $failCount"
    Add-ReportLine ""

    foreach ($test in $tests) {
        $status = if ($results[$test.Name]) { "[PASS]" } else { "[FAIL]" }
        Add-ReportLine "$status $($test.Name)"
    }

    # Recommendations
    Add-ReportSection "RECOMMENDATIONS"

    if (-not $results["UPPrinterInstaller"]) {
        Add-ReportLine "- UPPrinterInstaller.exe is missing. Ensure Windows 10/11 is updated."
        Add-ReportLine "  Universal Print support requires Windows 10 20H2+ or Windows 11."
    }

    if (-not $results["Microsoft Graph"]) {
        Add-ReportLine "- Install Microsoft Graph PowerShell SDK:"
        Add-ReportLine "  Install-Module Microsoft.Graph -Scope CurrentUser"
    }

    if (-not $results["Printer Shares"]) {
        Add-ReportLine "- Ensure Universal Print is configured in Microsoft 365 admin center"
        Add-ReportLine "- Verify your account has a Universal Print license"
        Add-ReportLine "- Check that printer shares are created and published"
    }

    # Save report
    $script:report | Out-File -FilePath $ReportPath -Encoding UTF8
    Add-ReportLine ""
    Add-ReportLine "Report saved to: $ReportPath"

    # Show report path
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Diagnostic Complete!" -ForegroundColor Green
    Write-Host "Report: $ReportPath" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Green
}

# Run diagnostics
Start-Diagnostics
