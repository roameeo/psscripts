# Set the variables
$resourceGroupName = "AZMONITOR-EASTUS-PROD"
$dcrName = "ServicesMonitor"
$location = "eastus"
$workspaceId = (Get-AzOperationalInsightsWorkspace -ResourceGroupName $resourceGroupName).ResourceId

#Verify the variables
$resourceGroupName
$dcrName
$location
$workspaceId

# Create the Data Collection Rule for Service State
$dcr = New-AzDataCollectionRule -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Name $dcrName `
    -DataFlow @(@{streams = @("Microsoft-Windows-Service"); destinations = @("ServiceStateLogs") }) `
    -DestinationLogAnalytic @(@{Name = "ServiceStateLogs"; WorkspaceResourceId = $workspaceId }) `
    -Description "Data Collection Rule for Windows Service State Monitoring"

# Verify DCR creation
$dcr