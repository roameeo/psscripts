
# Authenticate to Tenant B
$RemoteTenantId = "<tenantID>"
$RemoteSubId = "<subscriptionID>"

Connect-AzAccount -Tenant $RemoteTenantId -Subscription $RemoteSubId
Select-AzSubscription -SubscriptionId $RemoteSubId

# Define parameters
$ObjectId = "<ObjectID>" # Object ID of the user or service principal in Tenant B
$RoleName = "Network Contributor"
$Scope = "<Scope>" # e.g., "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}"

# Assign the role
New-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $RoleName -Scope $Scope
