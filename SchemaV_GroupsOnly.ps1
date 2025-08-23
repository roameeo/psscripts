
$obj2 = New-Object -Type PSCustomObject
$obj2 | Add-Member -Type NoteProperty -Name "Anchor-ExchangeGuid|String" -Value "00000000-0000-0000-0000-000000000000"
$obj2 | Add-Member -Type NoteProperty -Name "DistinguishedName|String" -Value "CN=(GROUP) All Contractors,OU=PPPP.onmicrosoft.com,OU=Microsoft Exchange Hosted Organizations,DC=NAMPR10A010,DC=PROD,DC=OUTLOOK,DC=COM"
$obj2 | Add-Member -Type NoteProperty -Name "objectClass|String" -Value "Group"
$obj2 | Add-Member -Type NoteProperty -Name "PrimarySmtpAddress|String" -Value "myalias@smtpdomain.yooo"
$obj2 | Add-Member -Type NoteProperty -Name "Alias|String" -Value "myAlias"
$obj2 | Add-Member -Type NoteProperty -Name "DisplayName|String" -Value "myAlias"

$obj2 | Add-Member -Type NoteProperty -Name "RecipientTypeDetails|String" -Value "myAlias"
$obj2 | Add-Member -Type NoteProperty -Name "RecipientType|String" -Value "myAlias"
#$obj2 | Add-Member -Type NoteProperty -Name "WhenChanged|String" -Value ""
$obj2 | Add-Member -Type NoteProperty -Name "HiddenFromAddressListsEnabled|Boolean" -Value $False
$obj2 | Add-Member -Type NoteProperty -Name "ExternalDirectoryObjectID|String" -Value "00000000-0000-0000-0000-000000000000"
$obj2 | Add-Member -Type NoteProperty -Name "EmailAddresses|String[]" -Value ("myalias@smtpdomain.yooo","myalias2@smtpdomain.yooo")


$obj2



