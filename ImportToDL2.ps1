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

# Build a hash of existing members (by primary SMTP)
$existing = @{}
Get-DistributionGroupMember -Identity $dg.Identity -ResultSize Unlimited |
  ForEach-Object {
    if ($_.PrimarySmtpAddress) {
      $existing[$_.PrimarySmtpAddress.ToString().ToLower()] = $true
    }
  }

# Add members from CSV using ONLY the email string (no Get-Recipient)
Import-Csv -Path $CsvPath | ForEach-Object {
  $email = ($_.Email).ToString().Trim().ToLower()
  if (-not $email) { return }

  if ($existing.ContainsKey($email)) {
    Write-Host "Already member: $email"
  } else {
    try {
      # Let Exchange resolve the SMTP string to a mail-enabled object
      Add-DistributionGroupMember -Identity $dg.Identity -Member $email -ErrorAction Stop -Confirm:$false
      Write-Host "Added:         $email"
      $existing[$email] = $true
    }
    catch {
      Write-Warning "Could not add '$email' (not found or not mail-enabled). If external, create a MailContact first."
    }
  }
}

# Verify
Get-DistributionGroupMember -Identity $dg.Identity | Select DisplayName,PrimarySmtpAddress
