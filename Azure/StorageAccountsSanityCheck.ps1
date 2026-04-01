# StorageAccountsSanityCheck.ps1
# Checks storage account existence, tags, and blob activity
# Handles missing accounts gracefully without context bleed-over

$accounts = @(
    @{ Name = "migratersa288157062";      RG = "AzEastUSProduction" },
    @{ Name = "thic6guateasttasrcache";   RG = "UAT-CENTRALUS-ASR" },
    @{ Name = "yx1nlquateasttasrcache";   RG = "UAT-CENTRALUS-ASR" }
)

foreach ($acct in $accounts) {
    Write-Host "`n=== $($acct.Name) ===" -ForegroundColor Cyan

    # Attempt to get the storage account - skip everything if not found
    try {
        $sa = Get-AzStorageAccount -Name $acct.Name -ResourceGroupName $acct.RG -ErrorAction Stop
    } catch {
        Write-Host "  NOT FOUND - account does not exist or was deleted." -ForegroundColor Red
        continue
    }

    # Tags
    if ($sa.Tags -and $sa.Tags.Count -gt 0) {
        Write-Host "  Tags: $($sa.Tags | ConvertTo-Json -Compress)"
    } else {
        Write-Host "  Tags: None"
    }

    # Get storage context from the account itself - no bleed-over risk
    $ctx = $sa.Context

    # Container and blob summary
    try {
        $containers = Get-AzStorageContainer -Context $ctx -ErrorAction Stop
    } catch {
        Write-Host "  Could not retrieve containers: $($_.Exception.Message)" -ForegroundColor Yellow
        continue
    }

    if ($containers) {
        foreach ($container in $containers) {
            try {
                $blobs = Get-AzStorageBlob -Container $container.Name -Context $ctx -ErrorAction Stop
                $totalSize = ($blobs | Measure-Object -Property Length -Sum).Sum
                $lastMod   = ($blobs | Sort-Object LastModified -Descending | Select-Object -First 1).LastModified
                if ($totalSize) { $sizeDisplay = "$([math]::Round($totalSize / 1MB, 2)) MB" } else { $sizeDisplay = "0 MB" }
                if ($lastMod)   { $lastDisplay = $lastMod.ToString() }                        else { $lastDisplay = "N/A" }
                Write-Host "  Container: $($container.Name) | Blobs: $($blobs.Count) | Size: $sizeDisplay | Last Modified: $lastDisplay"
            } catch {
                Write-Host "  Container: $($container.Name) | Could not read blobs: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  No containers found"
    }
}

Write-Host "`nDone." -ForegroundColor Green
