# Find all Recovery Services Vaults and their protected VMs
$vaults = Get-AzRecoveryServicesVault
foreach ($vault in $vaults) {
    Set-AzRecoveryServicesVaultContext -Vault $vault
    Write-Host "`n=== Vault: $($vault.Name) | RG: $($vault.ResourceGroupName) ===" -ForegroundColor Cyan
    
    $containers = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -ErrorAction SilentlyContinue
    foreach ($container in $containers) {
        Write-Host "  Protected VM: $($container.FriendlyName)"
    }
    
    # ASR replication items
    $fabric = Get-AzRecoveryServicesAsrFabric -ErrorAction SilentlyContinue
    foreach ($f in $fabric) {
        $protContainers = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $f -ErrorAction SilentlyContinue
        foreach ($pc in $protContainers) {
            $items = Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $pc -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                Write-Host "  ASR Protected: $($item.FriendlyName) | State: $($item.ReplicationState)" -ForegroundColor Yellow
            }
        }
    }
}