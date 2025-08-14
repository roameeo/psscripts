# # === CONFIGURATION ===
$TargetUser     = "<username>@ulterra.com"        # OneDrive owner
$DelegateUser   = "<username>@ulterra.com"        # User to grant access
$TenantName     = "uconnect"                   # e.g., 'uconnect' for uconnect-admin.sharepoint.com

# # === STEP 1: Set up module path ===
 $ModulePath = "$env:USERPROFILE\PowerShellModules"
 if (-not (Test-Path $ModulePath)) {
     New-Item -ItemType Directory -Path $ModulePath -Force | Out-Null
 }

# # === STEP 2: Download the SPO module ===
 Save-Module -Name Microsoft.Online.SharePoint.PowerShell -Path $ModulePath -Force

# # === STEP 3: Import the module ===
 $Psd1Path = Get-ChildItem -Path "$ModulePath\Microsoft.Online.SharePoint.PowerShell" -Recurse -Filter *.psd1 | Select-Object -First 1

 if ($Psd1Path) {
    Import-Module $Psd1Path.FullName -Force
     Write-Host "✅ SharePoint module loaded from $($Psd1Path.FullName)"
 } else {
     Write-Error "❌ Could not find the SharePoint module .psd1 file."
     return
 }

# # === STEP 4: Connect to SPO admin center ===
 $AdminUrl = "https://$TenantName-admin.sharepoint.com"
 Connect-SPOService -Url $AdminUrl

# === STEP 5: Build OneDrive URL from user UPN ===
$OneDriveUserId = $TargetUser -replace "@", "_" -replace "\.", "_"
$OneDriveUrl = "https://$TenantName-my.sharepoint.com/personal/$OneDriveUserId"

# === STEP 6: Verify OneDrive and grant access ===
try {
    $site = Get-SPOSite -Identity $OneDriveUrl -ErrorAction Stop

    # Grant delegate user site collection admin access
    Set-SPOUser -Site $OneDriveUrl -LoginName $DelegateUser -IsSiteCollectionAdmin $true
    Write-Host "✅ Granted $DelegateUser access to $TargetUser's OneDrive at $OneDriveUrl"
}
catch {
    Write-Warning "⚠️ Could not find OneDrive site for $TargetUser. URL tried: $OneDriveUrl"
}
