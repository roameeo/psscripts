Import-Module ActiveDirectory

$domain = "cjes.local"
$creds = Get-Credential -Message "Enter credentials for $domain"

$adminGroups = @(
    "Domain Admins",
    "Enterprise Admins",
    "Schema Admins",
    "Administrators",
    "Account Operators",
    "Backup Operators",
    "Group Policy Creator Owners"
)

$adminUsers = @{}

foreach ($group in $adminGroups) {
    try {
        $members = Get-ADGroupMember -Identity $group -Recursive -Server $domain -Credential $creds | Where-Object { $_.objectClass -eq "user" }
        foreach ($member in $members) {
            if (-not $adminUsers.ContainsKey($member.SamAccountName)) {
                $adminUsers[$member.SamAccountName] = [System.Collections.Generic.List[string]]::new()
            }
            $adminUsers[$member.SamAccountName].Add($group)
        }
    } catch {
        Write-Warning "Could not query group '$group': $_"
    }
}

$results = foreach ($sam in $adminUsers.Keys) {
    $user = Get-ADUser -Identity $sam -Server $domain -Credential $creds -Properties "DisplayName","UserPrincipalName","PasswordLastSet","Enabled","PasswordNeverExpires"
    [PSCustomObject]@{
        DisplayName          = $user.DisplayName
        SamAccountName       = $user.SamAccountName
        UserPrincipalName    = $user.UserPrincipalName
        AccountEnabled       = $user.Enabled
        PasswordLastSet      = $user.PasswordLastSet
        PasswordNeverExpires = $user.PasswordNeverExpires
        AdminGroups          = ($adminUsers[$sam] | Sort-Object -Unique) -join "; "
    }
}

$results | Sort-Object DisplayName | Format-Table -AutoSize

$results | Sort-Object DisplayName | Export-Csv -Path ".\CJES_AdminUsers_PasswordReport.csv" -NoTypeInformation
Write-Host "Exported to CJES_AdminUsers_PasswordReport.csv" -ForegroundColor Green