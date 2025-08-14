# Make sure you're logged in
# Connect-AzAccount

# Optional: Set the subscription context
# Set-AzContext -SubscriptionId "55e6995b-7646-44c3-8824-b63576c1b501"

# Create the output folder if it doesn't exist
$folder = "C:\Temp"
if (-not (Test-Path $folder)) {
    New-Item -Path $folder -ItemType Directory
}

# Get all VM names and export to vm_list.txt
Get-AzVM | Select-Object -ExpandProperty Name | Out-File -FilePath "$folder\vm_list.txt"

Write-Host "VM list exported to $folder\vm_list.txt" -ForegroundColor Green
