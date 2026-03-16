# Install if needed:
# Install-Module Microsoft.Graph -Scope CurrentUser

Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All", "RoleManagement.Read.Directory"

# Get all directory roles and their members
$adminUsers = @{}

$roles = Get-MgDirectoryRole -All

foreach ($role in $roles) {
    $members = Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id -All
    foreach ($member in $members) {
        if ($member.AdditionalProperties["@odata.type"] -eq "#microsoft.graph.user") {
            $userId = $member.Id
            if (-not $adminUsers.ContainsKey($userId)) {
                $adminUsers[$userId] = [System.Collections.Generic.List[string]]::new()
            }
            $adminUsers[$userId].Add($role.DisplayName)
        }
    }
}

# Pull user details including lastPasswordChangeDateTime
$results = foreach ($userId in $adminUsers.Keys) {
    $user = Get-MgUser -UserId $userId -Property "DisplayName,UserPrincipalName,LastPasswordChangeDateTime,AccountEnabled"
    [PSCustomObject]@{
        DisplayName           = $user.DisplayName
        UserPrincipalName     = $user.UserPrincipalName
        AccountEnabled        = $user.AccountEnabled
        LastPasswordReset     = $user.LastPasswordChangeDateTime
        AssignedAdminRoles    = ($adminUsers[$userId] | Sort-Object) -join "; "
    }
}

# Display and export
$results | Sort-Object DisplayName | Format-Table -AutoSize

# Optional: export to CSV
$results | Sort-Object DisplayName | Export-Csv -Path "C:\Temp\AdminUsers_PasswordReport-ULT.csv" -NoTypeInformation
Write-Host "Exported to AdminUsers_PasswordReport.csv" -ForegroundColor Green