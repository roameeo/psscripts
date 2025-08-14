# Variables
$resourceGroupName = "CiscoMerakiMon"  # <<-- Change this to your actual RG name
$routeTableName = "CisckoMerakiSCUS"
$excelPath = "C:\Temp\missed-routes.xlsx"

# Install and import ImportExcel module if not already installed
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Install-Module -Name ImportExcel -Force
}
Import-Module ImportExcel

# Import routes from Excel
$routes = Import-Excel -Path $excelPath

# Get the existing route table
$routeTable = Get-AzRouteTable -ResourceGroupName $resourceGroupName -Name $routeTableName

# Loop through and add each route
foreach ($route in $routes) {
    Write-Host "Adding route: $($route.Name)..."

    # Add the route to the route table config
    Add-AzRouteConfig -Name $route.Name `
                      -AddressPrefix $route.AddressPrefix `
                      -NextHopType $route.NextHopType `
                      -NextHopIpAddress $route.NextHopIpAddress `
                      -RouteTable $routeTable | Out-Null

    # Save (commit) the updated table
    $routeTable = Set-AzRouteTable -RouteTable $routeTable
}

Write-Host "All routes have been added to route table '$routeTableName'."
