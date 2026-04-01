# Set your vault and resource group
$vaultName = "AZEASTIMMUTABLEVAULT"
$resourceGroupName = "AzureEastBRS"

# Storage cost estimates per GB/month
$storageRates = @{
    "LRS" = 0.021
    "ZRS" = 0.03
    "GRS" = 0.042
}

# Set vault context
$vault = Get-AzRecoveryServicesVault -Name $vaultName -ResourceGroupName $resourceGroupName
Set-AzRecoveryServicesVaultContext -Vault $vault

# Get registered AzureVM containers
$containers = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM | Where-Object {
    $_.RegistrationStatus -eq "Registered"
}

$report = @()

foreach ($container in $containers) {
    $items = Get-AzRecoveryServicesBackupItem -Container $container -WorkloadType AzureVM

    foreach ($item in $items) {
        try {
            # Get the latest recovery point
            $rp = Get-AzRecoveryServicesBackupRecoveryPoint -Item $item |
                Sort-Object -Property RecoveryPointTime -Descending |
                Select-Object -First 1

            # Backup size in GB from recovery point
            $sizeGB = [math]::Round($rp.Properties.CompressedSizeInGB, 2)

            # Estimate cost
            $baseCost = if ($sizeGB -le 50) { 5 } else { 10 }
            $storageType = $vault.Sku.Name
            $rate = $storageRates[$storageType] | ForEach-Object { if ($_ -ne $null) { $_ } else { 0.042 } }
            $monthlyCost = [math]::Round($baseCost + ($sizeGB * $rate), 2)

            $report += [pscustomobject]@{
                VaultName           = $vault.Name
                ResourceGroup       = $vault.ResourceGroupName
                ContainerName       = $container.Name
                ProtectedItem       = $item.Name
                WorkloadType        = $item.WorkloadType
                BackupStatus        = $item.BackupState
                StorageType         = $storageType
                ActualBackupSizeGB  = $sizeGB
                EstimatedMonthlyUSD = $monthlyCost
            }
        }
        catch {
            Write-Warning "Failed to process $($item.Name): $($_.Exception.Message)"
        }
    }
}

# Export report to CSV
$outputPath = "C:\Temp\RSV_BackupSizeReport.csv"
$report | Export-Csv -Path $outputPath -NoTypeInformation
Write-Host "Report saved to $outputPath" -ForegroundColor Green
