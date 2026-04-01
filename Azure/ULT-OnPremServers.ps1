Import-Module ActiveDirectory
Import-Module Az.Compute

# Specify your domain controller and get credentials
$domainController = "IDC2ADS04.rbi.local"  # Change this to your DC name or IP
$credential = Get-Credential -Message "Enter domain credentials (DOMAIN\username)"

# Connect to Azure (will prompt for Azure credentials)
# Write-Host "Connecting to Azure..." -ForegroundColor Cyan
# Connect-AzAccount

# Get all Azure VM names
Write-Host "Getting Azure VMs..." -ForegroundColor Cyan
$azureVMs = Get-AzVM | Select-Object -ExpandProperty Name

# Get AD computers and filter to only On-Prem servers (NOT in Azure)
Write-Host "Getting On-Prem AD computers..." -ForegroundColor Cyan
$servers = Get-ADComputer -Filter "OperatingSystem -like '*Windows Server*'" -Properties OperatingSystem -Server $domainController -Credential $credential |
	Where-Object { $azureVMs -notcontains $_.Name } |
	Select-Object Name, OperatingSystem |
	Sort-Object OperatingSystem, Name

$servers | Format-Table -AutoSize

# Export to CSV:
$servers | Export-Csv -Path "C:\Temp\OnPremWindowsServers.csv" -NoTypeInformation
