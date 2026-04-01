$accounts = @(
    @{ Name = "migratersa288157062";      RG = "AzEastUSProduction" },
    @{ Name = "thic6guateasttasrcache";   RG = "UAT-CENTRALUS-ASR" },
    @{ Name = "yx1nlquateasttasrcache";   RG = "UAT-CENTRALUS-ASR" },
    @{ Name = "c0f385azsqlbackuasrcache"; RG = "azcendevusrg1" },
    @{ Name = "mcpa29azsqlbackuasrcache"; RG = "azcendevusrg1" },
    @{ Name = "cldestvmstorage01";        RG = "azurecentralusrg1" },
    @{ Name = "storageaccountazcen95df";  RG = "AzCenDevAngular" }
)

foreach ($acct in $accounts) {
    Write-Host "`n=== $($acct.Name) ===" -ForegroundColor Cyan
    
    $sa = Get-AzStorageAccount -Name $acct.Name -ResourceGroupName $acct.RG
    $ctx = $sa.Context
    
    # Tags
    Write-Host "Tags: $(if ($sa.Tags.Count -gt 0) { $sa.Tags | ConvertTo-Json -Compress } else { 'None' })"
    
    # Created / Last Modified from resource
    $resource = Get-AzResource -Name $acct.Name -ResourceGroupName $acct.RG
    Write-Host "Changed Time: $($resource.ChangedTime)"
    
    # Container and blob summary
    $containers = Get-AzStorageContainer -Context $ctx -ErrorAction SilentlyContinue
    if ($containers) {
        foreach ($container in $containers) {
            $blobs = Get-AzStorageBlob -Container $container.Name -Context $ctx -ErrorAction SilentlyContinue
            $totalSize = ($blobs | Measure-Object -Property Length -Sum).Sum
            $lastModified = ($blobs | Sort-Object LastModified -Descending | Select-Object -First 1).LastModified
            Write-Host "  Container: $($container.Name) | Blobs: $($blobs.Count) | Size: $([math]::Round($totalSize/1MB,2)) MB | Last Modified: $lastModified"
        }
    } else {
        Write-Host "  No containers found"
    }
}