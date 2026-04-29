# Script to get all Windows Server 2016 VMs in Azure subscription
# Author: Generated for Azure VM inventory
# Date: April 29, 2026

# Connect to Azure (will prompt for credentials if not already connected)
Write-Host "Connecting to Azure..." -ForegroundColor Cyan
try {
    $context = Get-AzContext
    if (-not $context) {
        Connect-AzAccount
    } else {
        Write-Host "Already connected to Azure subscription: $($context.Subscription.Name)" -ForegroundColor Green
    }
} catch {
    Write-Host "Error connecting to Azure: $_" -ForegroundColor Red
    exit
}

# Get all VMs with full details (single query for better performance)
Write-Host "`nGetting all VMs in subscription..." -ForegroundColor Cyan
$allVMs = Get-AzVM

# Get VM status separately
Write-Host "Getting VM power states..." -ForegroundColor Cyan
$vmStatuses = Get-AzVM -Status

# Filter for Windows Server 2016 VMs
Write-Host "Filtering for Windows Server 2016 VMs..." -ForegroundColor Cyan
$server2016VMs = $allVMs | Where-Object {
    $_.StorageProfile.ImageReference.Offer -like '*WindowsServer*' -and
    $_.StorageProfile.ImageReference.Sku -like '*2016*'
}

# Create output object with relevant details
$results = foreach ($vm in $server2016VMs) {
    # Get power state
    $vmStatus = $vmStatuses | Where-Object { $_.Id -eq $vm.Id }
    $powerState = if ($vmStatus.PowerState) { 
        ($vmStatus.PowerState -split ' ')[1] 
    } else { 
        'Unknown' 
    }
    
    # Get private IP(s)
    $privateIPs = @()
    foreach ($nicRef in $vm.NetworkProfile.NetworkInterfaces) {
        $nicId = $nicRef.Id
        $nic = Get-AzNetworkInterface | Where-Object { $_.Id -eq $nicId }
        if ($nic) {
            $privateIPs += $nic.IpConfigurations.PrivateIpAddress
        }
    }
    
    [PSCustomObject]@{
        VMName           = $vm.Name
        ResourceGroup    = $vm.ResourceGroupName
        Location         = $vm.Location
        PowerState       = $powerState
        VMSize           = $vm.HardwareProfile.VmSize
        OSVersion        = $vm.StorageProfile.ImageReference.Sku
        Publisher        = $vm.StorageProfile.ImageReference.Publisher
        Offer            = $vm.StorageProfile.ImageReference.Offer
        OSDiskType       = $vm.StorageProfile.OsDisk.ManagedDisk.StorageAccountType
        PrivateIP        = $privateIPs -join ', '
    }
}

# Display results
if ($results) {
    Write-Host "`nFound $($results.Count) Windows Server 2016 VM(s):" -ForegroundColor Green
    $results | Format-Table -AutoSize
    
    # Export to CSV
    if (-not (Test-Path -Path "C:\Temp")) {
        New-Item -ItemType Directory -Path "C:\Temp" | Out-Null
    }
    $exportPath = "C:\Temp\WindowsServer2016VMs_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $results | Export-Csv -Path $exportPath -NoTypeInformation
    Write-Host "`nResults exported to: $exportPath" -ForegroundColor Green
} else {
    Write-Host "`nNo Windows Server 2016 VMs found in the subscription." -ForegroundColor Yellow
}

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total Server 2016 VMs: $($results.Count)" -ForegroundColor White
