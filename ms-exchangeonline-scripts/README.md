# ms-exchangeonline-scripts

## Connect to Exchange Online
```
Connect-ExchangeOnline -ShowBanner:$false
```
## Get ALL mailboxes (simplest)
```
Get-Mailbox -ResultSize Unlimited
```
### Get specific mailbox types
```
Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox
Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails SharedMailbox
Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails RoomMailbox
Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails EquipmentMailbox
```
