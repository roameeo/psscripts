#Initial Server Setup script
#Written by Stormy Winters
#
#Version 1.0 - November 14, 2019
#Initial script for basic server setup

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null
$VenueNumber = [Microsoft.VisualBasic.Interaction]::InputBox("Enter the venue number", "Venue Number", "$env:VenueNumber")

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null
$ServerName = [Microsoft.VisualBasic.Interaction]::InputBox("Enter the venue designation", "Venue Name", "$env:VenueName")

#$input = Read-Host "Enter Server Name"

New-NetIPAddress -IPAddress 10.$VenueNumber.1.105 -InterfaceAlias "Ethernet" -DefaultGateway 10.$VenueNumber.1.1 -AddressFamily IPv4 -PrefixLength 24
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 10.$VenueNumber.1.2
Rename-Computer -Name $ServerName
Add-Computer topgolfusa.com
Restart-Computer

#Restart-Computer