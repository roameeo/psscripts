# Delete orphaned disks
$disksToDelete = @(
    @{ RG = "AzBRSTesting"; Name = "UDTDEVBRSSQL2025_disk1_0ba51b450dab4f43a590566a3b2c926b" },
    @{ RG = "UDTDevServers_RG"; Name = "udtdevctxapp03-osdisk-20240202-155909" },
    @{ RG = "UDTDevServers_RG"; Name = "UDTDEVCTXAPP03_OsDisk_1_d0bdbdf154054b7baa895bd6c8528acb" },
    @{ RG = "UDTDevServers_RG"; Name = "UDTDEVCTXCCC03_OsDisk_02022024" }
)

foreach ($disk in $disksToDelete) {
    Remove-AzDisk -ResourceGroupName $disk.RG -DiskName $disk.Name -Force
    Write-Host "Deleted disk: $($disk.Name)" -ForegroundColor Green
}

# Delete orphaned NICs
$nicsToDelete = @(
    @{ RG = "AzBRSTesting"; Name = "udtdevbrssql2025110" },
    @{ RG = "UDTDevServers_RG"; Name = "DevPatchTestEP.nic.51bc06ba-f3f8-4960-95d7-95e3c77a9ec4" },
    @{ RG = "UDTDevServers_RG"; Name = "tmpsqlsrv431" },
    @{ RG = "UDTDevServers_RG"; Name = "udtdevamishino994" }
)

foreach ($nic in $nicsToDelete) {
    Remove-AzNetworkInterface -ResourceGroupName $nic.RG -Name $nic.Name -Force
    Write-Host "Deleted NIC: $($nic.Name)" -ForegroundColor Green
}

Write-Host "`nDone. All orphaned disks and NICs removed." -ForegroundColor Cyan