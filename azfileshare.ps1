# Set variables
$storageAccountName = "marketingazfileshares"
$resourceGroup = "AzSystemsEastUS"

# Get values from Active Directory
$domainInfo = Get-ADDomain
$computerObject = Get-ADComputer -Identity "azfileshares"

$domainName        = $domainInfo.DNSRoot                      # e.g., rbi.local
$netBiosDomainName = $domainInfo.NetBIOSName                  # e.g., RBI
$forestName        = $domainInfo.Forest                       # e.g., rbi.local
$domainGuid        = $domainInfo.ObjectGUID
$domainSid         = $domainInfo.DomainSID.Value
$azureStorageSid   = $computerObject.SID.Value

# Print values (for verification)
Write-Output "`nUsing the following values:"
Write-Output "Domain Name:        $domainName"
Write-Output "NetBIOS Name:       $netBiosDomainName"
Write-Output "Forest Name:        $forestName"
Write-Output "Domain GUID:        $domainGuid"
Write-Output "Domain SID:         $domainSid"
Write-Output "Azure Storage SID:  $azureStorageSid"

# Convert to JSON for Azure CLI
$adProps = @{
    domainName       = $domainName
    netBiosDomainName= $netBiosDomainName
    forestName       = $forestName
    domainGuid       = $domainGuid.ToString()
    sid              = $domainSid
    azureStorageSid  = $azureStorageSid
}

$jsonProps = $adProps | ConvertTo-Json -Compress

# Update the Azure Storage Account
az storage account update `
  --name $storageAccountName `
  --resource-group $resourceGroup `
  --azure-files-identity-based-auth "AD" `
  --active-directory-properties $jsonProps
