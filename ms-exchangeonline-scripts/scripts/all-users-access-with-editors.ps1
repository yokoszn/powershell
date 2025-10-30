# Variables
$Calendar = "shared@domain.com:\Calendar"
$Editors = @(
    "usr1@domain.com",
    "usr2@domain.com",
    "usr3@domain.com"
)

# Connect
Connect-ExchangeOnline -ShowBanner:$false -ErrorAction SilentlyContinue

# Set Default permission (always exists, so always use Set)
Set-MailboxFolderPermission -Identity $Calendar -User Default -AccessRights Reviewer -Confirm:$false

# Handle editors - remove then add to avoid conflicts
foreach ($Editor in $Editors) {
    # Remove existing permission (ignore errors if doesn't exist)
    Remove-MailboxFolderPermission -Identity $Calendar -User $Editor -Confirm:$false -ErrorAction SilentlyContinue
    
    # Add fresh permission
    Add-MailboxFolderPermission -Identity $Calendar -User $Editor -AccessRights Editor -Confirm:$false
}

# Verify
Get-MailboxFolderPermission -Identity $Calendar | Format-Table User, AccessRights -AutoSize
