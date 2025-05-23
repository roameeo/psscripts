Param(
    [parameter(Mandatory=$false)]
    [object] $WebhookData
)

Function Check-WebHookData {
    param($WBData)

    if (-Not $WBData.RequestBody){

        Write-Output -InputObject "No data passed in Webhook Body."

        return $Null
    }
    else{

        Write-Output -InputObject "Grabbing data from Webhook Body and formatting."

        $user = $WBData.RequestBody | ConvertFrom-Json

        $PrimarySMTP = ($user.email_proxies.Split(',') | ? {$_ -notmatch "(uconnect.mail.onmicrosoft.com|uconnect.onmicrosoft.com)"}).Replace("SMTP:ulterra.com")
        $RemoteRoutingAddress = ($user.email_proxies.Split(',') | ? {$_ -match "uconnect.mail.onmicrosoft.com"}).Replace("smtp:ulterra.com")

        $New_WBData = New-Object PSObject
        $New_WBData | Add-Member -MemberType NoteProperty "AD_DN" -Value $user.AD_DN
        $New_WBData | Add-Member -MemberType NoteProperty "PrimarySMTP" -Value $PrimarySMTP
        $New_WBData | Add-Member -MemberType NoteProperty "RemoteRoutingAddress" -Value $RemoteRoutingAddress

        return $New_WBData
    }

}

Function Create-HybridMailbox{
    param(
        $UserObject,
        $AD_Creds
        )

    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://mail.ulterra.com/PowerShell/ -Authentication Kerberos -Credential $AD_Creds #update with Ulterra hybrid server.
    $NoMessage = Import-PSSession $Session
    # Use Write-Host in this context since Write-Output will write to the Import-PSSession and not be visible to script output.

    try{

        $ad_user = Get-ADUser -Identity $UserObject.AD_DN -Properties mail,msDS-ExternalDirectoryObjectId,targetaddress

        Write-Host -Object "User found!"

    }
    catch{

        Write-Host -Object "User Not Found"
        $ad_user = "Not Found"

        return $Null
    }

    If(-Not $ad_user.targetaddress){

        Write-Host -Object ("No Hybrid mailbox for {0}" -f $ad_user.SamAccountName)
        Write-Host -Object "Creating"

        $Created = Enable-RemoteMailbox -Identity $ad_user.UserPrincipalName -PrimarySmtpAddress $UserObject.PrimarySMTP -RemoteRoutingAddress $UserObject.RemoteRoutingAddress

        Start-Sleep -Seconds 15

        $Archive = Enable-RemoteMailbox -Identity $UserObject.RemoteRoutingAddress -Archive #uncomment if you will enable remote archive.

        Start-Sleep -Seconds 15 #uncomment if you will enable remote archive.

        #Add-ADGroupMember -Identity "" -Members $UserObject.AD_DN #update with AD group if required. Comment out if not needed.

        return $Created
    }


    else{
        Write-Host -Object "Remote mailbox in AD....Checking if mailbox exists in Hybrid."
        try{

            $mailbox_check = Get-RemoteMailbox -Identity $ad_user.targetaddress.Split(":")[1] -ErrorAction Stop

            Write-Host -Object ("{0} Mailbox Exists" -f $ad_user.targetaddress.Split(":")[1])

            return $false

        }
        catch{

            Write-Host -Object ("Issues with mailbox for user: {0}" -f $ad_user.SamAccountName)

            return 0

        }


    }

    Remove-PSSession

}

Write-Output -InputObject "Starting"

Write-Output -InputObject $WebhookData.RequestBody

$Credentials = Get-AutomationPSCredential -Name 'OKTA365' #update with credential name in Azure Runbook.

$user_data = Check-WebHookData -WBData $WebhookData

if (-Not $user_data){

    Write-Output -InputObject "No Valid data"
    
}
else{

    Write-Output -InputObject $user_data

    $Create_result = Create-HybridMailbox -UserObject $user_data -AD_Creds $Credentials

    Write-Output -InputObject ("Created Mailbox for: {0} - PrimarySMTP: {1}" -f $Create_result.DisplayName,$Create_result.PrimarySmtpAddress)
    #Write-Output -InputObject "Assigned License Group: 'Add group user was added to here'" #comment if not needed.
}