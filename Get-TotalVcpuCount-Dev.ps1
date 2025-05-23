# Connect to Azure if not already connected
Connect-AzAccount

# Optional: set the desired subscription if needed
# Set-AzContext -Subscription "e5ece68c-5ab6-4e37-9c7f-098de4d8af8c"

# Ensure output folder exists
$csvPath = "C:\Temp\CoreCount-Dev.csv"
if (!(Test-Path -Path "C:\Temp")) {
    New-Item -Path "C:\Temp" -ItemType Directory | Out-Null
}

# Get all VMs in the current subscription
$vms = Get-AzVM

# Prepare array to store results
$results = @()

foreach ($vm in $vms) {
    # Get VM size info
    $vmSizeInfo = Get-AzVMSize -Location $vm.Location | Where-Object { $_.Name -eq $vm.HardwareProfile.VmSize }

    if ($vmSizeInfo) {
        $results += [PSCustomObject]@{
            VMName     = $vm.Name
            ResourceGroup = $vm.ResourceGroupName
            Location   = $vm.Location
            VMSize     = $vm.HardwareProfile.VmSize
            vCPUCount  = $vmSizeInfo.NumberOfCores
        }
    }
}

# Add total core count as a final row (blank fields where appropriate)
$totalCores = ($results | Measure-Object -Property vCPUCount -Sum).Sum
$results += [PSCustomObject]@{
    VMName       = "TOTAL"
    ResourceGroup = ""
    Location     = ""
    VMSize       = ""
    vCPUCount    = $totalCores
}

# Export to CSV
$results | Export-Csv -Path $csvPath -NoTypeInformation

Write-Host "vCPU report exported to $csvPath"
