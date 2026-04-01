# This is per subscription, the customer has to set the az subscription before running this.
# az login
# az account set --subscription <subscription_id/subscription_name>
# This script uses parallel processing, modify the $parallelThrottleLimit parameter to either increase or decrease the number of parallel processes
# PS> .\LogAnalyticsAgentUninstallUtilityScript.ps1 GetInventory
# The above command will generate a csv file with the details of Vm's and Vmss and Arc servers that has log analyice Agent extension installed. 
# The customer can modify the the csv by adding/removing rows if needed
# Remove the log analytics agent by running the script again as shown below:
# PS> .\LogAnalyticsAgentUninstallUtilityScript.ps1 UninstallExtension

# This version of the script requires Powershell version >= 7 in order to improve performance via ForEach-Object -Parallel
# https://docs.microsoft.com/en-us/powershell/scripting/whats-new/migrating-from-windows-powershell-51-to-powershell-7?view=powershell-7.1
if ($PSVersionTable.PSVersion.Major -lt 7) 
{
 Write-Host "This script requires Powershell version 7 or newer to run. Please see https://docs.microsoft.com/en-us/powershell/scripting/whats-new/migrating-from-windows-powershell-51-to-powershell-7?view=powershell-7.1."
 exit 1
}

$parallelThrottleLimit = 16

function GetArcServersWithLogAnalyticsAgentExtensionInstalled {
 param (
     $fileName
 )
 
 $serverList = az connectedmachine list --query "[].{ResourceId:id, ResourceGroup:resourceGroup, ServerName:name}" | ConvertFrom-Json
 if(!$serverList)
 {
     Write-Host "Cannot get the Arc server list"
     return
 }

 $serversCount = $serverList.Length
 $vmParallelThrottleLimit = $parallelThrottleLimit
 if ($serversCount -lt $vmParallelThrottleLimit) 
 {
     $serverParallelThrottleLimit = $serversCount
 }

 $serverGroups = @()

 if($serversCount -eq 1)
 {
     $serverGroups += ,($serverList[0])
 }
 else
 {
     # split the list into batches to do parallel processing
     for ($i = 0; $i -lt $serversCount; $i += $vmParallelThrottleLimit) 
     { 
         $serverGroups += , ($serverList[$i..($i + $serverParallelThrottleLimit - 1)]) 
     }
 }

 Write-Host "Detected $serversCount Arc servers in this subscription."
 $hash = [hashtable]::Synchronized(@{})
 $hash.One = 1

 $serverGroups | Foreach-Object -ThrottleLimit $parallelThrottleLimit -Parallel {
     $len = $using:serversCount
     $hash = $using:hash
     $_ | ForEach-Object {
         $percent = 100 * $hash.One++ / $len
         Write-Progress -Activity "Getting Arc server extensions Inventory" -PercentComplete $percent
         $serverName = $_.ServerName
         $resourceGroup = $_.ResourceGroup
         $resourceId = $_.ResourceId
         Write-Debug "Getting extensions for Arc server: $serverName"
         $extensions = az connectedmachine extension list -g $resourceGroup --machine-name $serverName --query "[?contains(['MicrosoftMonitoringAgent', 'OmsAgentForLinux', 'AzureMonitorLinuxAgent', 'AzureMonitorWindowsAgent'], properties.type)].{type: properties.type, name: name}" | ConvertFrom-Json

         if (!$extensions) {
             return
         }
         $extensionMap = @{}
         foreach ($ext in $extensions) {
             $extensionMap[$ext.type] = $ext.name
         }
         if ($extensionMap.ContainsKey("MicrosoftMonitoringAgent")) {
             $extensionName = $extensionMap["MicrosoftMonitoringAgent"]
         }
         elseif ($extensionMap.ContainsKey("OmsAgentForLinux")) {
             $extensionName = $extensionMap["OmsAgentForLinux"]
         }
         if ($extensionName) {
             $amaExtensionInstalled = "False"
             if ($extensionMap.ContainsKey("AzureMonitorWindowsAgent") -or $extensionMap.ContainsKey("AzureMonitorLinuxAgent")) {
                 $amaExtensionInstalled = "True"
             }
             $csvObj = New-Object -TypeName PSObject -Property @{
                 'ResourceId'              = $resourceId
                 'Name'                    = $serverName
                 'Resource_Group'          = $resourceGroup
                 'Resource_Type'           = "ArcServer"
                 'Install_Type'            = "Extension"
                 'Extension_Name'          = $extensionName
                 'AMA_Extension_Installed' = $amaExtensionInstalled
             }
             $csvObj | Export-Csv $using:fileName -Append -Force | Out-Null
         }
         # az cli sometime cannot handle many requests at same time, so delaying next request by 2 milliseconds
         Start-Sleep -Milliseconds 2
     }
 }
}

function GetVmsWithLogAnalyticsAgentExtensionInstalled
{
 param(
     $fileName
 )
 
 $vmList = az vm list --query "[].{ResourceId:id, ResourceGroup:resourceGroup, VmName:name}" | ConvertFrom-Json
  
 if(!$vmList)
 {
     Write-Host "Cannot get the VM list"
     return
 }

 $vmsCount = $vmList.Length
 $vmParallelThrottleLimit = $parallelThrottleLimit
 if ($vmsCount -lt $vmParallelThrottleLimit) 
 {
     $vmParallelThrottleLimit = $vmsCount
 }

 if($vmsCount -eq 1)
 {
     $vmGroups += ,($vmList[0])
 }
 else
 {
     # split the vm's into batches to do parallel processing
     for ($i = 0; $i -lt $vmsCount; $i += $vmParallelThrottleLimit) 
     { 
         $vmGroups += , ($vmList[$i..($i + $vmParallelThrottleLimit - 1)]) 
     }
 }

 Write-Host "Detected $vmsCount Vm's in this subscription."
 $hash = [hashtable]::Synchronized(@{})
 $hash.One = 1

 $vmGroups | Foreach-Object -ThrottleLimit $parallelThrottleLimit -Parallel {
     $len = $using:vmsCount
     $hash = $using:hash
     $_ | ForEach-Object {
         $percent = 100 * $hash.One++ / $len
         Write-Progress -Activity "Getting VM extensions Inventory" -PercentComplete $percent
         $resourceId = $_.ResourceId
         $vmName = $_.VmName
         $resourceGroup = $_.ResourceGroup
         Write-Debug "Getting extensions for VM: $vmName"
         $extensions = az vm extension list -g $resourceGroup --vm-name $vmName --query "[?contains(['MicrosoftMonitoringAgent', 'OmsAgentForLinux', 'AzureMonitorLinuxAgent', 'AzureMonitorWindowsAgent'], typePropertiesType)].{type: typePropertiesType, name: name}" | ConvertFrom-Json
         
         if (!$extensions) {
             return
         }
         $extensionMap = @{}
         foreach ($ext in $extensions) {
             $extensionMap[$ext.type] = $ext.name
         }
         if ($extensionMap.ContainsKey("MicrosoftMonitoringAgent")) {
             $extensionName = $extensionMap["MicrosoftMonitoringAgent"]
         }
         elseif ($extensionMap.ContainsKey("OmsAgentForLinux")) {
             $extensionName = $extensionMap["OmsAgentForLinux"]
         }
         if ($extensionName) {
             $amaExtensionInstalled = "False"
             if ($extensionMap.ContainsKey("AzureMonitorWindowsAgent") -or $extensionMap.ContainsKey("AzureMonitorLinuxAgent")) {
                 $amaExtensionInstalled = "True"
             }
             $csvObj = New-Object -TypeName PSObject -Property @{
                 'ResourceId'              = $resourceId
                 'Name'                    = $vmName
                 'Resource_Group'          = $resourceGroup
                 'Resource_Type'           = "VM"
                 'Install_Type'            = "Extension"
                 'Extension_Name'          = $extensionName
                 'AMA_Extension_Installed' = $amaExtensionInstalled
             }
             $csvObj | Export-Csv $using:fileName -Append -Force | Out-Null
         }
         # az cli sometime cannot handle many requests at same time, so delaying next request by 2 milliseconds
         Start-Sleep -Milliseconds 2
     }
 }
}

function GetVmssWithLogAnalyticsAgentExtensionInstalled
{
 param(
     $fileName
 )

 # get the vmss list which are successfully provisioned
 $vmssList = az vmss list --query "[?provisioningState=='Succeeded'].{ResourceId:id, ResourceGroup:resourceGroup, VmssName:name}" | ConvertFrom-Json   

 $vmssCount = $vmssList.Length
 Write-Host "Detected $vmssCount Vmss in this subscription."
 $hash = [hashtable]::Synchronized(@{})
 $hash.One = 1

 $vmssList | Foreach-Object -ThrottleLimit $parallelThrottleLimit -Parallel {
     $len = $using:vmssCount
     $hash = $using:hash
     $percent = 100 * $hash.One++ / $len
     Write-Progress -Activity "Getting VMSS extensions Inventory" -PercentComplete $percent
     $resourceId = $_.ResourceId
     $vmssName = $_.VmssName
     $resourceGroup = $_.ResourceGroup
     Write-Debug "Getting extensions for VMSS: $vmssName"
     $extensions = az vmss extension list -g $resourceGroup --vmss-name $vmssName --query "[?contains(['MicrosoftMonitoringAgent', 'OmsAgentForLinux', 'AzureMonitorLinuxAgent', 'AzureMonitorWindowsAgent'], typePropertiesType)].{type: typePropertiesType, name: name}" | ConvertFrom-Json
     
     if (!$extensions) {
         return
     }
     $extensionMap = @{}
     foreach ($ext in $extensions) {
         $extensionMap[$ext.type] = $ext.name
     }
     if ($extensionMap.ContainsKey("MicrosoftMonitoringAgent")) {
         $extensionName = $extensionMap["MicrosoftMonitoringAgent"]
     }
     elseif ($extensionMap.ContainsKey("OmsAgentForLinux")) {
         $extensionName = $extensionMap["OmsAgentForLinux"]
     }
     if ($extensionName) {
         $amaExtensionInstalled = "False"
         if ($extensionMap.ContainsKey("AzureMonitorWindowsAgent") -or $extensionMap.ContainsKey("AzureMonitorLinuxAgent")) {
             $amaExtensionInstalled = "True"
         }
         $csvObj = New-Object -TypeName PSObject -Property @{
             'ResourceId'              = $resourceId
             'Name'                    = $vmssName
             'Resource_Group'          = $resourceGroup
             'Resource_Type'           = "VMSS"
             'Install_Type'            = "Extension"
             'Extension_Name'          = $extensionName
             'AMA_Extension_Installed' = $amaExtensionInstalled
         }
         $csvObj | Export-Csv $using:fileName -Append -Force | Out-Null
     }
     # az cli sometime cannot handle many requests at same time, so delaying next request by 2 milliseconds
     Start-Sleep -Milliseconds 2
 }
}

function GetInventory
{
 param(
     $fileName = "LogAnalyticsAgentExtensionInventory.csv"
 )

 # create a new file 
 New-Item -Name $fileName -ItemType File -Force

 Start-Transcript -Path $logFileName -Append
 GetVmsWithLogAnalyticsAgentExtensionInstalled $fileName
 GetVmssWithLogAnalyticsAgentExtensionInstalled $fileName
 GetArcServersWithLogAnalyticsAgentExtensionInstalled $fileName
 Stop-Transcript
}

function UninstallExtension
{
 param(
     $fileName = "LogAnalyticsAgentExtensionInventory.csv"
 )
 Start-Transcript -Path $logFileName -Append
 Import-Csv $fileName | ForEach-Object -ThrottleLimit $parallelThrottleLimit -Parallel {
     if ($_.Install_Type -eq "Extension") 
     {
         $extensionName = $_.Extension_Name
         $resourceName = $_.Name
         Write-Debug "Uninstalling extension: $extensionName from $resourceName"
         if ($_.Resource_Type -eq "VMSS") 
         {
             # if the extension is installed with a custom name, provide the name using the flag: --extension-instance-name <extension name>
             az vmss extension delete --name $extensionName --vmss-name $resourceName --resource-group $_.Resource_Group --output none --no-wait
         }
         elseif($_.Resource_Type -eq "VM")
         {
             # if the extension is installed with a custom name, provide the name using the flag: --extension-instance-name <extension name>
             az vm extension delete --name $extensionName --vm-name $resourceName --resource-group $_.Resource_Group --output none --no-wait
         }
         elseif($_.Resource_Type -eq "ArcServer")
         {
             az connectedmachine extension delete --name $extensionName --machine-name $resourceName --resource-group $_.Resource_Group --no-wait --output none --yes -y
         }
         # az cli sometime cannot handle many requests at same time, so delaying next delete request by 2 milliseconds
         Start-Sleep -Milliseconds 2
     }
 }
 Stop-Transcript
}

$logFileName = "LogAnalyticsAgentUninstallUtilityScriptLog.log"

switch ($args.Count)
{
 0 {
     Write-Host "The arguments provided are incorrect."
     Write-Host "To get the Inventory: Run the script as: PS> .\LogAnalyticsAgentUninstallUtilityScript.ps1 GetInventory"
     Write-Host "To uninstall Log Analytics Agent from Inventory: Run the script as: PS> .\LogAnalyticsAgentUninstallUtilityScript.ps1 UninstallExtension"
 }
 1 {
     if (-Not (Test-Path $logFileName)) {
         New-Item -Path $logFileName -ItemType File
     }
     $funcname = $args[0]
     Invoke-Expression "& $funcname"
 }
 2 {
     if (-Not (Test-Path $logFileName)) {
         New-Item -Path $logFileName -ItemType File
     }
     $funcname = $args[0]
     $funcargs = $args[1]
     Invoke-Expression "& $funcname $funcargs"
 }
}