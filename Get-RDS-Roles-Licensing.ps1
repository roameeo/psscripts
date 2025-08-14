# Input: List of server names (one per line)
$servers = Get-Content -Path "C:\Temp\vm_list.txt"

# Output: Collect results
$results = @()

foreach ($server in $servers) {
    Write-Host "Scanning $server..." -ForegroundColor Cyan
    try {
        $session = New-PSSession -ComputerName $server -ErrorAction Stop

        $info = Invoke-Command -Session $session -ScriptBlock {
            $features = Get-WindowsFeature | Where-Object { $_.Installed -eq $true -and $_.Name -like "*RDS*" }
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\Licensing Core"
            $licMode = $null
            $licServers = $null
            if (Test-Path $regPath) {
                $reg = Get-ItemProperty -Path $regPath
                $licMode = $reg.LicensingMode
                $licServers = $reg.LServerList -join ", "
            }
            $tsConnections = (Get-WmiObject -Class Win32_TerminalServiceSetting -Namespace root\CIMV2\TerminalServices).AllowTSConnections

            return [PSCustomObject]@{
                RDSFeatures      = ($features.DisplayName -join "; ")
                LicensingMode    = $licMode
                LicenseServers   = $licServers
                AllowTSSessions  = $tsConnections
            }
        }

        Remove-PSSession -Session $session

        $results += [PSCustomObject]@{
            ServerName      = $server
            RDSFeatures     = $info.RDSFeatures
            LicensingMode   = $info.LicensingMode
            LicenseServers  = $info.LicenseServers
            AllowTSSessions = $info.AllowTSSessions
        }
    }
    catch {
        $results += [PSCustomObject]@{
            ServerName      = $server
            RDSFeatures     = "Error"
            LicensingMode   = "Error"
            LicenseServers  = "Error"
            AllowTSSessions = "Error"
        }
    }
}

# Export to CSV
$results | Export-Csv -Path "C:\Temp\RDS_Licensing_Report.csv" -NoTypeInformation

Write-Host "Scan complete. Output saved to C:\Temp\RDS_Licensing_Report.csv" -ForegroundColor Green
