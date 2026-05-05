$rgs = @("UDTDevNetwork_RG", "UDTDevServers_RG", "UDTDevClients_RG", "UDTDevAppServers_RG")

foreach ($rg in $rgs) {
    Write-Host "`n=== $rg ===" -ForegroundColor Cyan
    
    $disks = Get-AzDisk -ResourceGroupName $rg
    foreach ($d in $disks) {
        $attached = if ($d.ManagedBy) { "Attached to: $($d.ManagedBy.Split('/')[-1])" } else { "UNATTACHED" }
        Write-Host "  DISK: $($d.Name) | $attached" -ForegroundColor Yellow
    }
    
    $nics = Get-AzNetworkInterface -ResourceGroupName $rg
    foreach ($n in $nics) {
        $attached = if ($n.VirtualMachine) { "Attached to: $($n.VirtualMachine.Id.Split('/')[-1])" } else { "UNATTACHED" }
        Write-Host "  NIC:  $($n.Name) | $attached" -ForegroundColor Green
    }
}