Get-AzResource -ResourceGroupName "UDTDevServers_RG" | Where-Object { 
    $_.Name -like "VMToAzure1638*" -or 
    $_.Name -like "UDTDev2AzureTest*" -or 
    $_.Name -like "migrate*" 
} | Select-Object Name, ResourceType | Format-Table -AutoSize