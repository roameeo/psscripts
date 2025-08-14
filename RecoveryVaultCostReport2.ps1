# Set your vault and resource group here
$vaultName = "AZEASTIMMUTABLEVAULT"
$resourceGroupName = "AzureEastBRS"

# Storage pricing estimates per GB/month (USD)
$storageRates = @{
    "LRS" = 0.021
    "ZRS" = 0.03
    "GRS" = 0.042
}

# Get the vault
$vault = Get-AzRecoveryServicesVault -Name $vaultName -ResourceGroupName $resourceGroupName
if (-not $vault) {
    Write-Host "❌ Vault not found: $vaultName" -ForegroundColor Red
    return
}

Set-AzRecoveryServicesVaultContext -Vault $vault
Write-Host "✅ Context set to vault '$vaultName'" -ForegroundColor Cyan

# Backup types to check
$managementTypes = @("AzureVM", "AzureWorkload", "AzureStorage", "MAB", "DPM")
$containers = @()

# Collect all containers across backup types
# Container types to query (adjust based on what you're using)
$containerTypes = @("AzureVM", "AzureSQL", "AzureFileShare", "MAB", "DPM")
$containers = @()

foreach ($type in $containerTypes) {
    try {
        $containers += Get-AzRecoveryServicesBackupContainer -ContainerType $type
    }
    catch {
        Write-Warning "Failed to query containers for type ${type}: $($_.Exception.Message)"
    }
}


# Filter to registered containers only
$containers = $containers | Where-Object { $_.RegistrationStatus -eq "Registered" }

# Collect protected items and cost info
$report = @()
foreach ($container in $containers) {
    $items = Get-AzRecoveryServicesBackupItem -Container $container
    foreach ($item in $items) {
        try {
            # Size estimate logic
            $sizeGB = switch ($item.WorkloadType) {
                "AzureVM"         { 50 }
                "AzureSQL"        { 20 }
                "AzureFileShare"  { 30 }
                default           { 20 }
            }

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
                EstimatedSizeGB     = $sizeGB
                EstimatedMonthlyUSD = $monthlyCost
            }
        }
        catch {
            Write-Warning "⚠️ Error processing item $($item.Name): $($_.Exception.Message)"
        }
    }
}

# Export to CSV
$outputPath = "C:\Temp\$($vault.Name)_BackupCostReport.csv"
$report | Export-Csv -Path $outputPath -NoTypeInformation
Write-Host "`n✅ Backup cost report saved to $outputPath" -ForegroundColor Green
