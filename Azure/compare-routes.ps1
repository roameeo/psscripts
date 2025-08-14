# Variables
$existingRoutesPath = "C:\Temp\ExportedRoutesEUS.xlsx"  # Routes from original route table
$newRoutesPath      = "C:\Temp\ExportedRoutesSCUS.xlsx"       # Routes from new route table
$outputPath         = "C:\Temp\missed-routes.xlsx"   # Output file for missing routes

# Install and import ImportExcel module if not already installed
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Install-Module -Name ImportExcel -Force
}
Import-Module ImportExcel

# Import data from both spreadsheets
$existingRoutes = Import-Excel -Path $existingRoutesPath
$newRoutes      = Import-Excel -Path $newRoutesPath

# Compare using Name as key (you can change to AddressPrefix or both)
$missingRoutes = $existingRoutes | Where-Object {
    $prefix = $_.AddressPrefix
    -not ($newRoutes.AddressPrefix -contains $prefix)
}

# Export missing routes to new file
$missingRoutes | Export-Excel -Path $outputPath -WorksheetName "MissedRoutes" -AutoSize

Write-Host "✅ Missing routes exported to $outputPath"
