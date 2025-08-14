# Connect to Graph
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All"

# Replace with your actual group object ID
$groupId = "e4a6b559-3f80-4a8b-b894-d86ccc413a80"

# Load CSV
$users = Import-Csv -Path "C:\Temp\ULT.AdobeSTD.users-ConvertToPro.csv"

foreach ($user in $users) {
    try {
        # Get the user's object ID
        $aadUser = Get-MgUser -UserId $user.UserPrincipalName -ErrorAction Stop

        # Add user to group using @odata.id reference
        New-MgGroupMemberByRef -GroupId $groupId -BodyParameter @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($aadUser.Id)"
        }

        Write-Host "✅ Added $($user.UserPrincipalName)" -ForegroundColor Green
    }
    catch {
        Write-Warning "❌ Failed to add $($user.UserPrincipalName): $_"
    }
}
