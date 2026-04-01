# Requires Az.RecoveryServices
# Install-Module -Name Az.RecoveryServices -Force -AllowClobber

$outputPath = "C:\Temp\RecoveryVaultBackupCosts.csv"

# Estimated storage pricing per GB/month
$storageRates = @{
    "LRS" = 0.021
    "ZRS" = 0.03
    "GRS" = 0.042
}

$report = @()

# Get all Recovery Services Vaults
$vaults = Get-AzRecoveryServicesVault

foreach ($vault in $vaults) {
    Write-Host "Checking vault: $($vault.Name)" -ForegroundColor Cyan
    Set-AzRecoveryServicesVaultContext -Vault $vault

    # Get all containers (filter for AzureVM or remove to get all)
    $containers = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM

    foreach ($container in $containers) {
        if ($container.RegistrationStatus -ne "Registered") {
            continue  # Skip unregistered containers
        }

        $items = Get-AzRecoveryServicesBackupItem -Container $container

        foreach ($item in $items) {
            try {
                $sizeGB = if ($item.WorkloadType -eq "AzureVM") { 50 } else { 20 }
                $baseCost = if ($sizeGB -le 50) { 5 } else { 10 }

                $storageType = $vault.Sku.Name
                $rate = if ($storageRates.ContainsKey($storageType)) { $storageRates[$storageType] } else { 0.042 }
                $monthlyCost = [math]::Round($baseCost + ($sizeGB * $rate), 2)

                $report += [pscustomobject]@{
                    VaultName           = $vault.Name
                    ResourceGroup       = $vault.ResourceGroupName
                    ProtectedItem       = $item.Name
                    WorkloadType        = $item.WorkloadType
                    BackupStatus        = $item.BackupState
                    StorageType         = $storageType
                    BackupSizeGB        = $sizeGB
                    EstimatedMonthlyUSD = $monthlyCost
                }
            }
            catch {
                Write-Warning "Failed to process $($item.Name): $($_.Exception.Message)"
            }
        }
    }
}

$report | Export-Csv -Path $outputPath -NoTypeInformation
Write-Host "Report saved to $outputPath" -ForegroundColor Green
