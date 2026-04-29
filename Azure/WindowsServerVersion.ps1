Import-Module Az.Compute

# Connect to Azure (will prompt for Azure credentials)
# Connect-AzAccount

$exportPath = "C:\Temp\WindowsServers.csv"

# Get all Azure VMs and their OS info
Write-Host "Getting Azure VMs..." -ForegroundColor Cyan
$servers = Get-AzVM | Where-Object { $_.StorageProfile.ImageReference.Sku -like '*2016*' } |
    Select-Object `
        @{Name='Name'; Expression={$_.Name}},
        @{Name='ResourceGroup'; Expression={$_.ResourceGroupName}},
        @{Name='Location'; Expression={$_.Location}},
        @{Name='OperatingSystem'; Expression={$_.StorageProfile.ImageReference.Offer}},
        @{Name='OSVersion'; Expression={$_.StorageProfile.ImageReference.Sku}} |
    Sort-Object Name

$servers | Format-Table -AutoSize

# Export to CSV
if ($servers) {
    $servers | Export-Csv -Path $exportPath -NoTypeInformation
    Write-Host "Exported $($servers.Count) VM(s) to $exportPath" -ForegroundColor Green
} else {
    Write-Warning "No VMs found."
}
