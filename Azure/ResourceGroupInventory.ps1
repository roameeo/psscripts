Get-AzResourceGroup | Select-Object `
    ResourceGroupName, `
    Location, `
    Tags `
| Export-Csv -Path "C:\Scripts\ResourceGroups_Inventory.csv" -NoTypeInformation