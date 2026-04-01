
# Authenticate to Tenant B
$RemoteTenantId = "ffcdba76-444a-4e44-8c97-81cfe8d14cf2"
$RemoteSubId = "20874075-e0dc-4c82-b624-f442cf42c0d6"

Connect-AzAccount -Tenant $RemoteTenantId -Subscription $RemoteSubId
Select-AzSubscription -SubscriptionId $RemoteSubId

# Define parameters
$ObjectId = "7e25685b-a55e-411a-8e07-068a281dc75b"
$RoleName = "Network Contributor"
$Scope = "/subscriptions/20874075-e0dc-4c82-b624-f442cf42c0d6/resourceGroups/AZ-DataWarehouse-01/providers/Microsoft.Network/virtualNetworks/AZ-DATABASE-VN"

# Assign the role
New-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $RoleName -Scope $Scope
