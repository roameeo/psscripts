# Connect to Azure account (if not already connected)
Connect-AzAccount

# Set your subscription
Set-AzContext -Subscription "55e6995b-7646-44c3-8824-b63576c1b501"

# Read VM names from file
$vmNames = Get-Content -Path "C:\Temp\vm_list.txt"

# Prepare results collection
$results = @()

foreach ($vmName in $vmNames) {
    $vm = Get-AzVM -Name $vmName -Status -ErrorAction SilentlyContinue
    
    if ($null -eq $vm) {
        Write-Warning "VM '$vmName' not found."
        continue
    }

    # Get vCPU count from VM size details
    $vmSizeInfo = Get-AzVMSize -Location $vm.Location | Where-Object { $_.Name -eq $vm.HardwareProfile.VmSize }

    $results += [PSCustomObject]@{
        VMName     = $vm.Name
        VMSize     = $vm.HardwareProfile.VmSize
        vCPUCount  = $vmSizeInfo.NumberOfCores
        Location   = $vm.Location
        Status     = $vm.PowerState
    }
}

# Display results
$results | Format-Table -AutoSize

# Optionally, export results to CSV
$results | Export-Csv -Path ".\VM_vCPU_Counts.csv" -NoTypeInformation
