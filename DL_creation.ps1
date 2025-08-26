# --- Configure these three values ---
$GroupName = "BoxMigration"
$Alias     = "BoxMigration"
$Primary   = "boxmigration@patenergy.com"  # change to your domain
$CsvPath   = "C:\Temp\members.csv"

# Ensure connected
Import-Module ExchangeOnlineManagement
if (-not (Get-ConnectionInformation)) { Connect-ExchangeOnline }

# Create the DL if missing
$dg = Get-DistributionGroup -Identity $Primary -ErrorAction SilentlyContinue
if (-not $dg) {
  $dg = New-DistributionGroup -Name $GroupName -Alias $Alias -PrimarySmtpAddress $Primary -Type Distribution
  Write-Host "Created: $($dg.PrimarySmtpAddress)"
} else {
  Write-Host "Exists:  $($dg.PrimarySmtpAddress)"
}

# Build a hash of existing members
$existing = @{}
Get-DistributionGroupMember -Identity $dg.Identity -ResultSize Unlimited |
  ForEach-Object { $existing[$_.PrimarySmtpAddress.ToString().ToLower()] = $true }

# Add members from CSV (only adds missing)
Import-Csv -Path $CsvPath | ForEach-Object {
  $id = ($_.Email).Trim()
  if (-not $id) { return }

  $recip = Get-Recipient -Identity $id -ErrorAction SilentlyContinue
  if (-not $recip) { Write-Warning "Recipient not found: $id"; return }

  $addr = $recip.PrimarySmtpAddress.ToString().ToLower()
  if ($existing.ContainsKey($addr)) {
    Write-Host "Already member: $addr"
  } else {
    Add-DistributionGroupMember -Identity $dg.Identity -Member $recip.Identity -ErrorAction Stop
    Write-Host "Added:         $addr"
    $existing[$addr] = $true
  }
}

# Verify
Get-DistributionGroupMember -Identity $dg.Identity | Select DisplayName,PrimarySmtpAddress
