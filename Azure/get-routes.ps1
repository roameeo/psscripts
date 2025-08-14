# Variables
$resourceGroupName = "CiscoMerakiMon"
$routeTableName = "CisckoMerakiSCUS"
#$prefix = "VPN"  # change this to your specific prefix

# Get the route table
$routeTable = Get-AzRouteTable -ResourceGroupName $resourceGroupName -Name $routeTableName

# Filter routes where Name starts with $prefix
$filteredRoutes = $routeTable.Routes | Where-Object { $_.Name -like "$prefix*" }

# Select properties to export
$exportData = $filteredRoutes | Select-Object `
    Name,
    AddressPrefix,
    NextHopType,
    NextHopIpAddress

# Export to CSV
$exportPath = "C:\Temp\ExportedRoutesSCUS.csv"
$exportData | Export-Csv -Path $exportPath -NoTypeInformation

Write-Host "Exported routes to $exportPath"
