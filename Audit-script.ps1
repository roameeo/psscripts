 $Report = @()
$Users = Get-ADUser -Filter * -Properties Name, LastLogonDate, Enabled, MemberOf, PwdLastSet, PasswordLastSet -ResultSetSize $Null
# Use ForEach loop, as we need group membership for every account that is collected.
# MemberOf property of User object has the list of groups and is available in DN format.
Foreach($User in $users){
$UserGroupCollection = $User.MemberOf
#This Array will hold Group Names to which the user belongs.
$UserGroupMembership = @()
#To get the Group Names from DN format we will again use Foreach loop to query every DN and retrieve the Name property of Group.
Foreach($UserGroup in $UserGroupCollection){
$GroupDetails = Get-ADGroup -Identity $UserGroup
#Here we will add each group Name to UserGroupMembership array
$UserGroupMembership += $GroupDetails.Name
}
#As the UserGroupMembership is array we need to join element with ‘,’ as the seperator
$Groups = $UserGroupMembership -join ", "
#Creating custom objects
$Out = New-Object PSObject
$Out | Add-Member -MemberType noteproperty -Name Name -Value $User.Name
$Out | Add-Member -MemberType noteproperty -Name Enabled -Value $User.Enabled
$Out | Add-Member -MemberType noteproperty -Name "Last Logon" -Value $User.lastlogonDate
$Out | Add-Member -MemberType noteproperty -Name PwdLastSet -Value $User.PasswordLastSet
$Out | Add-Member -MemberType noteproperty -Name Groups -Value $Groups

$Report += $Out
}
#Output to csv file.
$Report | Sort-Object Name | Export-Csv -Path "C:\IT\Audit Report 5-23-2023.csv" -NoTypeInformation
