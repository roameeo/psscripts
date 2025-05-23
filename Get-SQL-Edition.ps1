# Optional: install the SqlServer module if you don't already have it
# Install-Module -Name SqlServer -Scope CurrentUser -Force

# Load SMO
Import-Module SqlServer

# Read the list of server names
$serverList = Get-Content "C:\Temp\vm_list.txt"

# Output list
$results = @()

foreach ($serverName in $serverList) {
    try {
        $server = New-Object Microsoft.SqlServer.Management.Smo.Server $serverName

        $info = [PSCustomObject]@{
            ServerName     = $server.Name
            Edition        = $server.Edition
            Version        = $server.VersionString
            EngineEdition  = $server.EngineEdition
            ProductLevel   = $server.ProductLevel
            ConnectionStatus = "Success"
        }

        $results += $info
    }
    catch {
        $results += [PSCustomObject]@{
            ServerName     = $serverName
            Edition        = "N/A"
            Version        = "N/A"
            EngineEdition  = "N/A"
            ProductLevel   = "N/A"
            ConnectionStatus = "Failed: $($_.Exception.Message)"
        }
    }
}

# Export results
$results | Export-Csv -Path "C:\Temp\SQLVersions.csv" -NoTypeInformation

Write-Host "Done! Results exported to C:\Temp\SQLVersions.csv"
