<#
.SYNOPSIS
  Discover disabled AD users, optionally export/snapshot, remove all direct AD group
  memberships, and (optionally) remove them from Exchange Online distribution lists.

.NOTES
  - AD step removes direct memberships (primary group like 'Domain Users' is unaffected).
  - EXO step removes from cloud-only Distribution Groups (skips Dynamic DLs).
  - Start with -WhatIf and consider using -SnapshotPath for rollback evidence.

#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param(
  # What to do
  [ValidateSet('ExportOnly','CleanOnly','Both')]
  [string]$Action = 'Both',

  # Discovery scope / DC targeting
  [string]$SearchBase,
  [string]$Server,

  # File paths
  [string]$OutputPath   = 'C:\Reports\DisabledADUsers.csv',               # list of disabled users
  [string]$LogPath      = 'C:\Reports\DisabledUsers_GroupRemovalLog.csv', # AD+EXO actions log
  [string]$InputPath,                                                     # optional input for CleanOnly
  [string]$SnapshotPath,                                                  # pre-change AD membership snapshot

  # Filters & safety rails for AD
  [switch]$SecurityGroupsOnly,         # only remove from AD security groups
  [string[]]$ExcludeGroupNames = @(),  # AD group names to skip
  [string[]]$ExcludeGroupDNs   = @(),  # AD group DNs to skip
  [string[]]$ExcludeUserSam    = @(),  # users (sAM) to skip
  [switch]$IncludeCriticalGroups,      # by default exclude privileged AD groups

  # Exchange Online cleanup (cloud-only DLs)
  [switch]$ExchangeDLCleanup,          # include Exchange DL removal (cloud-only)
  [string]$ExchangeAdminUpn            # optional UPN for Connect-ExchangeOnline
)

$PSDefaultParameterValues['*:ErrorAction'] = 'Stop'
Import-Module ActiveDirectory

# Highly privileged AD groups we avoid unless -IncludeCriticalGroups
$CriticalGroupNames = @(
  'Administrators','Domain Admins','Enterprise Admins','Schema Admins',
  'Account Operators','Backup Operators','Server Operators',
  'Print Operators','Group Policy Creator Owners','DnsAdmins','Cert Publishers'
)

function Get-DisabledUsers {
  param([string]$SearchBase,[string]$Server)
  $searchParams = @{}
  if ($SearchBase) { $searchParams.SearchBase = $SearchBase }
  if ($Server)     { $searchParams.Server     = $Server }

  $dns = Search-ADAccount -AccountDisabled -UsersOnly @searchParams |
         Select-Object -ExpandProperty DistinguishedName

  foreach ($dn in $dns) {
    Get-ADUser -Identity $dn -Properties SamAccountName,UserPrincipalName,mail,Enabled,MemberOf,WhenChanged,LastLogonDate,PasswordLastSet
  }
}

function Resolve-Group {
  param([string]$GroupDn,[string]$Server)
  $gp = @{}
  if ($Server) { $gp.Server = $Server }
  Get-ADGroup -Identity $GroupDn -Properties SamAccountName,DistinguishedName,GroupCategory,GroupScope @gp
}

function Remove-UserDirectMemberships {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][Microsoft.ActiveDirectory.Management.ADUser]$User,
    [string]$Server,
    [switch]$SecurityGroupsOnly,
    [string[]]$ExcludeGroupNames,
    [string[]]$ExcludeGroupDNs,
    [string[]]$CriticalGroupNames,
    [switch]$IncludeCriticalGroups
  )

  $results = New-Object System.Collections.Generic.List[Object]

  if (-not $User.Enabled -and $User.MemberOf) {
    $memberDns = @($User.MemberOf | Select-Object -Unique)

    $groups = foreach ($dn in $memberDns) {
      try { Resolve-Group -GroupDn $dn -Server $Server }
      catch {
        $results.Add([pscustomobject]@{ User=$User.SamAccountName; Step='ResolveGroup'; Target=$dn; Outcome='Error'; Reason=$_.Exception.Message })
        continue
      }
    }

    if ($SecurityGroupsOnly) { $groups = $groups | Where-Object { $_.GroupCategory -eq 'Security' } }
    if ($ExcludeGroupDNs)    { $groups = $groups | Where-Object { $_.DistinguishedName -notin $ExcludeGroupDNs } }
    if ($ExcludeGroupNames)  { $groups = $groups | Where-Object { $_.SamAccountName   -notin $ExcludeGroupNames } }
    if (-not $IncludeCriticalGroups) {
      $groups = $groups | Where-Object { $_.SamAccountName -notin $CriticalGroupNames }
    }

    foreach ($g in $groups) {
      $targetLabel = "$($g.SamAccountName) [$($g.DistinguishedName)]"
      if ($PSCmdlet.ShouldProcess($User.SamAccountName, "Remove from $targetLabel")) {
        try {
          $rmParams = @{ Identity = $g.DistinguishedName; Members = $User.DistinguishedName; Confirm = $false }
          if ($Server) { $rmParams['Server'] = $Server }
          Remove-ADGroupMember @rmParams
          $results.Add([pscustomobject]@{ User=$User.SamAccountName; Step='AD-Remove'; Target=$g.SamAccountName; Outcome='Removed'; Reason='' })
        } catch {
          $results.Add([pscustomobject]@{ User=$User.SamAccountName; Step='AD-Remove'; Target=$g.SamAccountName; Outcome='Error'; Reason=$_.Exception.Message })
        }
      } else {
        $results.Add([pscustomobject]@{ User=$User.SamAccountName; Step='AD-WhatIf'; Target=$g.SamAccountName; Outcome='Preview'; Reason='WhatIf' })
      }
    }
  } else {
    $reason = if ($User.Enabled) { 'User not disabled' } else { 'No direct group memberships' }
    $results.Add([pscustomobject]@{ User=$User.SamAccountName; Step='AD-Check'; Target=''; Outcome='Skip'; Reason=$reason })
  }

  return $results
}

# ---------- Exchange Online helpers (DL cleanup) ----------
function Ensure-ExchangeOnline {
  param([string]$AdminUpn)
  if (-not (Get-Module ExchangeOnlineManagement -ListAvailable)) {
    throw "ExchangeOnlineManagement module not found. Install-Module ExchangeOnlineManagement -Scope AllUsers"
  }
  if (-not (Get-ConnectionInformation)) {
    if ($AdminUpn) { Connect-ExchangeOnline -UserPrincipalName $AdminUpn -ShowBanner:$false }
    else { Connect-ExchangeOnline -ShowBanner:$false }
  }
}

function Get-EXOIdentityForUser {
  param([Microsoft.ActiveDirectory.Management.ADUser]$User)
  # Try AD 'mail' then UPN
  $candidates = @($User.mail, $User.UserPrincipalName) | Where-Object { $_ }
  foreach ($id in $candidates) {
    try {
      $r = Get-Recipient -Identity $id -ErrorAction Stop
      if ($r) { return $r }
    } catch { }
  }
  return $null
}

function Build-DLMembershipIndex {
  # Returns a Hashtable: key = member PrimarySmtpAddress (lower), value = list of DL identities
  $index = @{}
  # Exclude dynamic DLs (no direct members)
  $dls = Get-DistributionGroup -ResultSize Unlimited | Where-Object { $_.RecipientTypeDetails -ne 'DynamicDistributionGroup' }
  foreach ($dl in $dls) {
    try {
      $members = Get-DistributionGroupMember -Identity $dl.Identity -ResultSize Unlimited
    } catch {
      # Permission or transient error—skip indexing this DL
      continue
    }
    foreach ($m in $members) {
      $smtp = ($m.PrimarySmtpAddress -as [string])
      if (-not $smtp) { continue }
      $key = $smtp.ToLowerInvariant()
      if (-not $index.ContainsKey($key)) { $index[$key] = New-Object System.Collections.Generic.List[string] }
      $index[$key].Add($dl.Identity.ToString())
    }
  }
  return $index
}

function Remove-UserFromExchangeDLs {
  [CmdletBinding()]
  param(
    [Microsoft.ActiveDirectory.Management.ADUser]$User,
    $ExoRecipient,                   # result of Get-Recipient
    [hashtable]$DlIndex              # from Build-DLMembershipIndex
  )
  $results = New-Object System.Collections.Generic.List[Object]
  if (-not $ExoRecipient) {
    $results.Add([pscustomobject]@{ User=$User.SamAccountName; Step='EXO-Resolve'; Target=''; Outcome='Skip'; Reason='Recipient not found in EXO' })
    return $results
  }

  $smtp = ($ExoRecipient.PrimarySmtpAddress -as [string])
  if (-not $smtp) {
    $results.Add([pscustomobject]@{ User=$User.SamAccountName; Step='EXO-Check'; Target=''; Outcome='Skip'; Reason='No PrimarySmtpAddress' })
    return $results
  }

  $groups = @()
  $key = $smtp.ToLowerInvariant()
  if ($DlIndex.ContainsKey($key)) { $groups = $DlIndex[$key] }

  if (-not $groups -or $groups.Count -eq 0) {
    $results.Add([pscustomobject]@{ User=$User.SamAccountName; Step='EXO-Enumerate'; Target=''; Outcome='Skip'; Reason='No DL memberships (cloud-only)' })
    return $results
  }

  foreach ($dlId in $groups) {
    if ($PSCmdlet.ShouldProcess($User.SamAccountName, "Remove from EXO DL: $dlId")) {
      try {
        Remove-DistributionGroupMember -Identity $dlId -Member $smtp -BypassSecurityGroupManagerCheck -Confirm:$false
        $results.Add([pscustomobject]@{ User=$User.SamAccountName; Step='EXO-Remove'; Target=$dlId; Outcome='Removed'; Reason='' })
      } catch {
        $results.Add([pscustomobject]@{ User=$User.SamAccountName; Step='EXO-Remove'; Target=$dlId; Outcome='Error'; Reason=$_.Exception.Message })
      }
    } else {
      $results.Add([pscustomobject]@{ User=$User.SamAccountName; Step='EXO-WhatIf'; Target=$dlId; Outcome='Preview'; Reason='WhatIf' })
    }
  }
  return $results
}
# ---------- end Exchange helpers ----------

# 1) Discover disabled users unless CleanOnly with explicit input
$discoveredUsers = @()
if ($Action -ne 'CleanOnly' -or -not $InputPath) {
  $discoveredUsers = Get-DisabledUsers -SearchBase $SearchBase -Server $Server
}

# 2) Export list (if selected)
if ($Action -in @('ExportOnly','Both')) {
  $export = $discoveredUsers | Sort-Object SamAccountName | Select-Object `
    SamAccountName,UserPrincipalName,mail,DistinguishedName,Enabled,LastLogonDate,PasswordLastSet,WhenChanged

  $dir = Split-Path -Path $OutputPath -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }

  $export | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
  Write-Host "Exported $($export.Count) disabled users to $OutputPath"
}

# 3) Build work list for cleaning
$cleanList = @()
if ($Action -in @('CleanOnly','Both')) {
  if ($InputPath -and (Test-Path $InputPath)) {
    $csv = Import-Csv -Path $InputPath
    foreach ($row in $csv) {
      if (-not $row.SamAccountName) { continue }
      try {
        $cleanList += Get-ADUser -Identity $row.SamAccountName -Properties Enabled,MemberOf,DistinguishedName,SamAccountName,UserPrincipalName,mail
      } catch { Write-Warning "Could not load user $($row.SamAccountName): $($_.Exception.Message)" }
    }
  } else {
    $cleanList = $discoveredUsers
  }
}

# 4) OPTIONAL AD snapshot before changes
if ($Action -in @('CleanOnly','Both') -and $SnapshotPath) {
  $snapDir = Split-Path -Path $SnapshotPath -Parent
  if ($snapDir -and -not (Test-Path $snapDir)) { New-Item -ItemType Directory -Path $snapDir | Out-Null }

  $snapshot = New-Object System.Collections.Generic.List[Object]
  foreach ($u in $cleanList) {
    $memberDns = @($u.MemberOf | Select-Object -Unique)
    if (-not $memberDns) {
      $snapshot.Add([pscustomobject]@{ UserSam=$u.SamAccountName; UserUPN=$u.UserPrincipalName; UserDN=$u.DistinguishedName; GroupSam=''; GroupDN=''; GroupCategory=''; GroupScope=''; Note='No direct memberships' })
      continue
    }
    foreach ($dn in $memberDns) {
      try {
        $g = Resolve-Group -GroupDn $dn -Server $Server
        $snapshot.Add([pscustomobject]@{ UserSam=$u.SamAccountName; UserUPN=$u.UserPrincipalName; UserDN=$u.DistinguishedName; GroupSam=$g.SamAccountName; GroupDN=$g.DistinguishedName; GroupCategory=$g.GroupCategory; GroupScope=$g.GroupScope; Note='' })
      } catch {
        $snapshot.Add([pscustomobject]@{ UserSam=$u.SamAccountName; UserUPN=$u.UserPrincipalName; UserDN=$u.DistinguishedName; GroupSam='(resolve-error)'; GroupDN=$dn; GroupCategory=''; GroupScope=''; Note=$_.Exception.Message })
      }
    }
  }
  $snapshot | Export-Csv -Path $SnapshotPath -NoTypeInformation -Encoding UTF8
  Write-Host "Snapshot written to $SnapshotPath"
}

# 5) Perform cleanup (AD + optional EXO)
if ($Action -in @('CleanOnly','Both')) {
  $log = New-Object System.Collections.Generic.List[Object]
  $dir = Split-Path -Path $LogPath -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }

  # If Exchange DL cleanup requested, connect and pre-index DL memberships once
  $dlIndex = $null
  if ($ExchangeDLCleanup) {
    Ensure-ExchangeOnline -AdminUpn $ExchangeAdminUpn
    $dlIndex = Build-DLMembershipIndex
  }

  foreach ($u in $cleanList) {
    if ($ExcludeUserSam -and ($ExcludeUserSam -contains $u.SamAccountName)) {
      $log.Add([pscustomobject]@{ User=$u.SamAccountName; Step='AD-Check'; Target=''; Outcome='Skip'; Reason='Excluded user' })
      continue
    }

    # AD group cleanup
    $log.AddRange( (Remove-UserDirectMemberships -User $u -Server $Server `
      -SecurityGroupsOnly:$SecurityGroupsOnly -ExcludeGroupNames $ExcludeGroupNames `
      -ExcludeGroupDNs $ExcludeGroupDNs -CriticalGroupNames $CriticalGroupNames `
      -IncludeCriticalGroups:$IncludeCriticalGroups) )

    # Exchange DL cleanup (cloud-only)
    if ($ExchangeDLCleanup) {
      $exoRecip = $null
      try { $exoRecip = Get-EXOIdentityForUser -User $u } catch {}
      $log.AddRange( (Remove-UserFromExchangeDLs -User $u -ExoRecipient $exoRecip -DlIndex $dlIndex) )
    }
  }

  $log | Export-Csv -Path $LogPath -NoTypeInformation -Encoding UTF8
  Write-Host "Cleanup complete. Log written to $LogPath"
}
