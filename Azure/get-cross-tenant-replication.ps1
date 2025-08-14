# Connect to Azure if not already connected
# Connect-AzAccount

# Optional: To loop through all subscriptions
$subscriptions = "55e6995b-7646-44c3-8824-b63576c1b501"

# Store results here
$results = @()

foreach ($sub in $subscriptions) {
    Set-AzContext -SubscriptionId $sub.Id

    $storageAccounts = Get-AzStorageAccount

    foreach ($sa in $storageAccounts) {
        $replicationPolicy = $sa.EnableCrossTenantReplication

        if ($replicationPolicy -eq $true) {
            $results += [PSCustomObject]@{
                SubscriptionName     = $sub.Name
                ResourceGroupName    = $sa.ResourceGroupName
                StorageAccountName   = $sa.StorageAccountName
                Location             = $sa.Location
                Sku                  = $sa.Sku.Name
                Kind                 = $sa.Kind
                CrossTenantReplication = $replicationPolicy
            }
        }
    }
}

# Export to CSV
$results | Export-Csv -Path "C:\Temp\CrossTenantReplicationEnabled.csv" -NoTypeInformation

Write-Host "CSV Exported to C:\Temp\CrossTenantReplicationEnabled.csv"
