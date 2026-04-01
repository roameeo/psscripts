# FindOrphanedStorageAccounts.ps1
# Subscription-wide sweep to identify unused or orphaned storage accounts
# Run Date: (Get-Date auto-set at runtime)
#
# ORPHAN CRITERIA USED:
#   - No containers at all
#   - Containers exist but zero blobs across all of them
#   - Zero transactions in Azure Monitor over $inactiveDaysThreshold days
#   - Storage account resource unchanged more than $inactiveDaysThreshold days ago

# ---------------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------------
$inactiveDaysThreshold = 90     # Days of no activity = considered inactive
$exportCsv             = $true
$csvPath               = "C:\Temp\OrphanedStorageAccounts_$(Get-Date -Format 'yyyy-MM-dd').csv"
# ---------------------------------------------------------------

$cutoffDate  = (Get-Date).AddDays(-$inactiveDaysThreshold)
$metricStart = (Get-Date).AddDays(-$inactiveDaysThreshold).ToUniversalTime()
$metricEnd   = (Get-Date).ToUniversalTime()
$results     = [System.Collections.Generic.List[PSObject]]::new()

Write-Host "`nFetching all storage accounts in subscription..." -ForegroundColor Cyan
$allAccounts = Get-AzStorageAccount
Write-Host "Found $($allAccounts.Count) storage accounts. Evaluating...`n" -ForegroundColor Cyan

foreach ($sa in $allAccounts) {
    $flags          = [System.Collections.Generic.List[string]]::new()
    $transactions   = $null
    $blobCapacityMB = $null
    $changedTime    = $null

    Write-Host "  Checking $($sa.StorageAccountName)..." -ForegroundColor DarkGray

    # --- Resource-level change time ---
    try {
        $resource    = Get-AzResource -Name $sa.StorageAccountName -ResourceGroupName $sa.ResourceGroupName -ErrorAction Stop
        $changedTime = $resource.ChangedTime
        if ($changedTime -and $changedTime -lt $cutoffDate) {
            $flags.Add("ResourceUnchangedOver${inactiveDaysThreshold}Days")
        }
    } catch {
        $changedTime = $null
        $flags.Add("CouldNotReadResourceMeta")
    }

    # --- Azure Monitor: Transaction count over threshold window ---
    try {
        $txMetric = Get-AzMetric -ResourceId $sa.Id `
            -MetricName "Transactions" `
            -StartTime $metricStart `
            -EndTime $metricEnd `
            -TimeGrain 1.00:00:00 `
            -AggregationType Total `
            -ErrorAction Stop
        $transactions = ($txMetric.Data | Measure-Object -Property Total -Sum).Sum
        if ($transactions -eq 0) {
            $flags.Add("ZeroTransactionsOver${inactiveDaysThreshold}Days")
        }
    } catch {
        $transactions = $null
        $flags.Add("CouldNotReadMetrics")
    }

    # --- Azure Monitor: Blob capacity (current size, no enumeration needed) ---
    try {
        $capMetric = Get-AzMetric -ResourceId "$($sa.Id)/blobServices/default" `
            -MetricName "BlobCapacity" `
            -StartTime (Get-Date).AddDays(-3).ToUniversalTime() `
            -EndTime $metricEnd `
            -TimeGrain 1.00:00:00 `
            -AggregationType Average `
            -ErrorAction Stop
        $latestCap = ($capMetric.Data | Where-Object { $_.Average -ne $null } | Sort-Object TimeStamp -Descending | Select-Object -First 1).Average
        if ($latestCap) { $blobCapacityMB = [math]::Round($latestCap / 1MB, 2) }
    } catch {
        $blobCapacityMB = $null
    }

    # --- Container existence check (fast, no blob enumeration) ---
    $ctx = $sa.Context
    try {
        $containers = Get-AzStorageContainer -Context $ctx -MaxCount 1 -ErrorAction Stop
        if (-not $containers -or $containers.Count -eq 0) {
            $flags.Add("NoContainers")
        } elseif ($blobCapacityMB -eq 0 -or $blobCapacityMB -eq $null) {
            $flags.Add("NoBlobs")
        }
    } catch {
        $flags.Add("CannotReadContainers")
    }

    # --- Status label ---
    $isOrphaned = $flags.Count -gt 0

    if ($flags -contains "NoContainers" -or $flags -contains "NoBlobs") {
        $status = "EMPTY"
    } elseif ($flags | Where-Object { $_ -like "ZeroTransactions*" -or $_ -like "ResourceUnchanged*" }) {
        $status = "INACTIVE"
    } elseif ($isOrphaned) {
        $status = "REVIEW"
    } else {
        $status = "OK"
    }

    # --- Console output ---
    $color = switch ($status) {
        "EMPTY"    { "Red" }
        "INACTIVE" { "Yellow" }
        "REVIEW"   { "Yellow" }
        "OK"       { "Green" }
    }

    Write-Host "[$status] $($sa.StorageAccountName) | RG: $($sa.ResourceGroupName) | Location: $($sa.Location)" -ForegroundColor $color
    if ($flags.Count -gt 0) {
        Write-Host "        Flags: $($flags -join ' | ')" -ForegroundColor DarkYellow
    }
    Write-Host "        Transactions(${inactiveDaysThreshold}d): $(if ($transactions -ne $null) { $transactions } else { 'N/A' }) | BlobCapacity: $(if ($blobCapacityMB -ne $null) { "$blobCapacityMB MB" } else { 'N/A' })"

    # --- Collect result ---
    $results.Add([PSCustomObject]@{
        StorageAccountName  = $sa.StorageAccountName
        ResourceGroup       = $sa.ResourceGroupName
        Location            = $sa.Location
        Kind                = $sa.Kind
        SkuName             = $sa.Sku.Name
        Status              = $status
        Flags               = $flags -join " | "
        Transactions90Days  = if ($transactions -ne $null) { $transactions } else { "N/A" }
        BlobCapacityMB      = if ($blobCapacityMB -ne $null) { $blobCapacityMB } else { "N/A" }
        ResourceChangedTime = if ($changedTime) { $changedTime.ToString() } else { "N/A" }
        Tags                = if ($sa.Tags -and $sa.Tags.Count -gt 0) { $sa.Tags | ConvertTo-Json -Compress } else { "None" }
    })
}

# --- Summary ---
Write-Host "`n========== SUMMARY ==========" -ForegroundColor Cyan
Write-Host "Total Accounts Scanned: $($results.Count)"
Write-Host "  EMPTY    (no containers or blobs): $(($results | Where-Object Status -eq 'EMPTY').Count)"    -ForegroundColor Red
Write-Host "  INACTIVE (no activity >$inactiveDaysThreshold days): $(($results | Where-Object Status -eq 'INACTIVE').Count)" -ForegroundColor Yellow
Write-Host "  REVIEW   (other flags):            $(($results | Where-Object Status -eq 'REVIEW').Count)"   -ForegroundColor Yellow
Write-Host "  OK       (no issues found):        $(($results | Where-Object Status -eq 'OK').Count)"       -ForegroundColor Green

# --- Export ---
if ($exportCsv) {
    $results | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "`nResults exported to: $csvPath" -ForegroundColor Cyan
}

Write-Host "`nDone." -ForegroundColor Green
