# CreateStorageResourceGroups.ps1
# Creates all target resource groups for the storage account reorganization
# Tags based on Azure Tag Library standard
# Run Date: 2026-03-20

# ---------------------------------------------------------------
# UPDATE THESE VALUES BEFORE RUNNING
# ---------------------------------------------------------------
$buildBy    = "Stormy Winters"   # Who is deploying
$buildDate  = (Get-Date -Format "yyyy-MM-dd") # Auto-set to today
$owner      = "Cloud Admins"   # Lifecycle owner
$contact    = "Cloud Admins"     # Support contact
$costCenter = "9400"                             # e.g. IT-1001 - fill in before running
# ---------------------------------------------------------------

if (-not $costCenter) {
    Write-Host "ERROR: CostCenter tag is required. Please set the `$costCenter variable before running." -ForegroundColor Red
    exit 1
}

$rgs = @(
    # East US - Citrix / VDI
    @{
        Name        = "RG-Citrix-EastUS"
        Location    = "eastus"
        Function    = "Citrix and VDI storage"
        Environment = "Prod"
    },
    # East US - File Shares
    @{
        Name        = "RG-FileShares-EastUS"
        Location    = "eastus"
        Function    = "Azure File Shares - user and department shares"
        Environment = "Prod"
    },
    # East US - Backup
    @{
        Name        = "RG-Backup-EastUS"
        Location    = "eastus"
        Function    = "Rubrik and Veeam backup storage"
        Environment = "Prod"
    },
    # East US - Rubrik Restore Testing
    @{
        Name        = "RG-Rubrik-RestoreTest-EastUS"
        Location    = "eastus"
        Function    = "Rubrik restore test workloads - isolated from production"
        Environment = "Test"
    },
    # East US - SQL
    @{
        Name        = "RG-SQL-EastUS"
        Location    = "eastus"
        Function    = "SQL witnesses and database backups"
        Environment = "Prod"
    },
    # East US - Diagnostics
    @{
        Name        = "RG-Diagnostics-EastUS"
        Location    = "eastus"
        Function    = "VM and resource diagnostics storage"
        Environment = "Prod"
    },
    # East US - Monitoring
    @{
        Name        = "RG-Monitoring-EastUS"
        Location    = "eastus"
        Function    = "Network flow logs and monitoring workbooks"
        Environment = "Prod"
    },
    # East US - SFTP
    @{
        Name        = "RG-SFTP-EastUS"
        Location    = "eastus"
        Function    = "SFTP endpoints"
        Environment = "Prod"
    },
    # East US - Production Apps
    @{
        Name        = "RG-Production-EastUS"
        Location    = "eastus"
        Function    = "Production application storage"
        Environment = "Prod"
    },
    # East US - Dev
    @{
        Name        = "RG-Dev-EastUS"
        Location    = "eastus"
        Function    = "Dev and test workloads"
        Environment = "Dev"
    },
    # Central US - Backup
    @{
        Name        = "RG-Backup-CentralUS"
        Location    = "centralus"
        Function    = "Rubrik backup storage - Central US"
        Environment = "Prod"
    },
    # South Central US - Backup
    @{
        Name        = "RG-Backup-SouthCentralUS"
        Location    = "southcentralus"
        Function    = "Rubrik backup storage - South Central US"
        Environment = "Prod"
    },
    # South Central US - Marketing
    @{
        Name        = "RG-Marketing-SouthCentralUS"
        Location    = "southcentralus"
        Function    = "Marketing VM disk and storage - South Central US"
        Environment = "Prod"
    },
    # Central US - Dev
    @{
        Name        = "RG-Dev-CentralUS"
        Location    = "centralus"
        Function    = "Dev and test workloads - Central US"
        Environment = "Dev"
    }
)

Write-Host "`nCreating $($rgs.Count) resource groups..." -ForegroundColor Cyan
Write-Host "Build By:    $buildBy"
Write-Host "Build Date:  $buildDate"
Write-Host "Owner:       $owner"
Write-Host "Cost Center: $costCenter`n"

$success = 0
$failed  = 0

foreach ($rg in $rgs) {
    $tags = @{
        BuildBy     = $buildBy
        BuildDate   = $buildDate
        Function    = $rg.Function
        Environment = $rg.Environment
        Owner       = $owner
        Contact     = $contact
        CostCenter  = $costCenter
    }

    try {
        New-AzResourceGroup -Name $rg.Name -Location $rg.Location -Tag $tags -ErrorAction Stop | Out-Null
        Write-Host "  [OK] $($rg.Name) ($($rg.Location))" -ForegroundColor Green
        $success++
    } catch {
        Write-Host "  [FAILED] $($rg.Name) - $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

Write-Host "`n--- Summary ---"
Write-Host "Created:  $success" -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "Failed:   $failed" -ForegroundColor Red
}
Write-Host "Done." -ForegroundColor Cyan