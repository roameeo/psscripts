Set-AzRecoveryServicesVaultContext -Vault (Get-AzRecoveryServicesVault -Name "AZEASTIMMUTABLEVAULT" -ResourceGroupName "AzureEastBRS")

$containers = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM | Where-Object { $_.RegistrationStatus -eq "Registered" }

foreach ($container in $containers) {
    $items = Get-AzRecoveryServicesBackupItem -Container $container -WorkloadType AzureVM
    foreach ($item in $items) {
        Write-Host "Item: $($item.Name)"
        try {
            $rp = Get-AzRecoveryServicesBackupRecoveryPoint -Item $item
            if ($rp.Count -eq 0) {
                Write-Host "   No recovery points found!"
            }
            else {
                $latest = $rp | Sort-Object -Property RecoveryPointTime -Descending | Select-Object -First 1
                Write-Host "   Found latest RP: $($latest.RecoveryPointTime) | Size: $($latest.Properties.CompressedSizeInGB) GB"
            }
        }
        catch {
            Write-Warning "   Failed to get recovery point for $($item.Name): $($_.Exception.Message)"
        }
    }
}

