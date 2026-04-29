$keyVaults = Get-AzKeyVault
$certName = "Bluekango"

foreach ($vault in $keyVaults) {
    $certificate = Get-AzKeyVaultCertificate -VaultName $vault.VaultName -Name $certName -ErrorAction SilentlyContinue
    
    if ($certificate) {
        Write-Host "Certificate found in Key Vault: $($vault.VaultName)"
    } else {
        Write-Host "Certificate not found in Key Vault: $($vault.VaultName)"
    }
}