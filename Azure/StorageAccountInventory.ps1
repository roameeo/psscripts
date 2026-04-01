Get-AzStorageAccount | Select-Object `
    StorageAccountName, `
    ResourceGroupName, `
    Location, `
    Kind, `
    @{N="SkuName";E={$_.Sku.Name}}, `
    @{N="AccessTier";E={$_.AccessTier}}, `
    Tags `
| Export-Csv -Path "C:\Scripts\StorageAccounts_Inventory.csv" -NoTypeInformation