param (
	$Username,
	$Password,
	$OperationType="Delta",
	[bool] $usepagedimport=$true,
	$pagesize=5,
    $Schema
	,$ConfigurationParameter
)

#UPDATED 02/15/2022 v2.0 - implement Only Mailbox Information
#UPDATED 10/27/2022 v2.1 - updated to use Connect-ExchangeOnline v2.0.4
#UPDATED 10/27/2022 v2.2 - updated to use certificate and app registration authentication, combo exo and get-mailbox on each mailbox - sigh
#Import-Module -Name exchangeonlinemanagement -MaximumVersion 2.0.4
import-module exchangeonlinemanagement -MinimumVersion 3.1.0
# enforce the use of TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#Connect-ExchangeOnline -CertificateThumbPrint "79ce6510afb8fab3371219a4f3e15de9225c2225".ToUpper() -AppID "dcdde44c-c868-4a40-9dce-3a28d4f8b05a" -Organization "patenergy.com" 

#Connect-ExchangeOnline -CertificateThumbPrint "92980B4AF06B22923466D4F987B96EE5DE08372E" -AppID b5757667-ef4b-4e8c-9953-fe03947d48e2 -Organization "NexTierOFS.com" 

#uses exchange online app registration / certificate authentication
#Azure App Registration - "GalSync Reader"
<#
$AppId="b5757667-ef4b-4e8c-9953-fe03947d48e2"
$Thumbprint = "92980B4AF06B22923466D4F987B96EE5DE08372E"
$org="NexTierOFS.com"
#>
<#
$AppId="dcdde44c-c868-4a40-9dce-3a28d4f8b05a"
$Thumbprint = "79ce6510afb8fab3371219a4f3e15de9225c2225"
$org="patenergy.com"
#>
$AppId=$ConfigurationParameter["AppId"]
$Thumbprint=$ConfigurationParameter["Thumbprint"]
$org=$ConfigurationParameter["org"]
$Debug = $false
$ParentDir = $PSScriptRoot
    if (!$ParentDir){if ($psISE){$ParentDir = Split-Path -Parent -Path $psISE.CurrentFile.FullPath}}

$DebugDir = "$ParentDir\Debug"
$DebugFilePath = "$DebugDir\Import.txt"
$TimestampPath = "$ParentDir\Timestamp_$org.txt"

$UTC_format  = "yyyyMMddTHHmmss"

if(!(Test-Path $DebugDir)){New-Item -Path $DebugDir -ItemType Directory}

if(!(Test-Path $DebugFilePath)){
	$DebugFile = New-Item -Path $DebugFilePath -ItemType File
}else{
	$DebugFile = Get-Item -Path $DebugFilePath
}

Function LogThis {
	[CmdletBinding()]
    param(
		$String,
        $ForegroundColor="White"
	)
	$LogString = (Get-Date).ToString() + "|" + $String
	$LogString | Out-File $DebugFilePath -Append
	
    if($Debug -eq $true){
        Write-host $LogString -ForegroundColor $ForegroundColor
    }else{
        Write-verbose $LogString
    }
}

LogThis -String "--------------------------------------------------" -Verbose
LogThis -String "Starting Import as: $OperationType" -Verbose
LogThis -String "Paged Import : $usepagedimport" -Verbose
LogThis -String "PageSize : $pagesize" -Verbose
LogThis -String "RunningAs : $env:username" -Verbose
LogThis -String "AppID : $AppId" -Verbose
LogThis -String "Thumbprint : $Thumbprint" -Verbose
LogThis -String "org : $org" -Verbose
LogThis -String "--------------------------------------------------"
#$Credentials = New-Object System.Management.Automation.PSCredential $Username,$AZPassword

Function Put-EventLog {
	param(
		$Message,
		$EventType="Information",
		$EventID
	)
	[System.Diagnostics.EventLog]$EventLog = Get-EventLog -list | Where-Object {$_.Log -eq "Forefront Identity Manager Management Agent"}
	$EventLog.MachineName = "."
	$EventLog.Source = "FIM Sync Agent"
	$EventLog.WriteEntry($Message, $EventType, $EventID)
}

# $Global:Objects=$null

Function Get-Objects {
    param(
        $OperationType,
        $LastImportUTC
    )
    #$TestUTC = $LastImportUTC.AddHours(-1)

   
    
    switch($OperationType){
        "Full"{
            LogThis -String "Getting mailboxes for OperationType $OperationType" -Verbose
         #  $objects =  Get-EXORecipient -Filter "RecipientType -ne 'UserMailbox'  -and RecipientType -ne 'MailContact'" -ResultSize Unlimited  -Properties WhenChangedUTC,HiddenFromAddressListsEnabled,ExchangeObjectId,DistinguishedName,PrimarySmtpAddress,Alias,RecipientTypeDetails,RecipientType,DisplayName,ExternalDirectoryObjectID,EmailAddresses
		$objects = Get-EXORecipient -ResultSize Unlimited  `
			-Filter "( RecipientType -eq 'Group' -or RecipientType -eq 'MailUniversalSecurityGroup' -or RecipientType -eq 'MailUniversalDistributionGroup' -or RecipientType -eq 'DynamicDistributionGroup')  " `
			-Properties WhenSoftDeleted,WhenChangedUTC,HiddenFromAddressListsEnabled,ExchangeObjectId,DistinguishedName,PrimarySmtpAddress,Alias,RecipientTypeDetails,RecipientType,DisplayName,ExternalDirectoryObjectID,EmailAddresses 
			
			LogThis -String "Retrieved $($objects.Count) Group recipients for OperationType $OperationType" -Verbose
			#$Objects | export-csv "FullImport.csv"
	
          #  Get-EXORecipient  -filter {HiddenFromAddressListsEnabled -eq $false}   -Properties HiddenFromAddressListsEnabled,    -ResultSize 2  
            }
        "Delta"{
            LogThis -String "Getting mailboxes for OperationType $OperationType with LastImportUTC $LastImportUTC" -Verbose
            #Include Soft Delete objects 10/20/2023
            #WhenSoftDeleted
            # $objects = Get-EXORecipient -Filter "RecipientType -ne 'UserMailbox' -and RecipientType -ne 'MailContact' -and WhenChangedUTC -gt '$LastImportUTC'" -IncludeSoftDeletedRecipients -Properties WhenSoftDeleted,WhenChangedUTC,HiddenFromAddressListsEnabled,ExchangeObjectId,DistinguishedName,PrimarySmtpAddress,Alias,RecipientTypeDetails,RecipientType,DisplayName,ExternalDirectoryObjectID,EmailAddresses
			$objects = Get-EXORecipient -Filter "( RecipientType -eq 'Group' -or RecipientType -eq 'MailUniversalSecurityGroup' -or RecipientType -eq 'MailUniversalDistributionGroup' -or RecipientType -eq 'DynamicDistributionGroup') -and WhenChangedUTC -gt '$LastImportUTC' " `
			-IncludeSoftDeletedRecipients -Properties WhenSoftDeleted,WhenChangedUTC,HiddenFromAddressListsEnabled,ExchangeObjectId,DistinguishedName,PrimarySmtpAddress,Alias,RecipientTypeDetails,RecipientType,DisplayName,ExternalDirectoryObjectID,EmailAddresses `
			-ResultSize Unlimited 
   
			#($objects.Count )
			#$Objects | export-csv "C:\PTEN_PSMA\GroupsOnly\Debug\DeltaImport.csv" 
		}
        default{}
    }
	
	LogThis -String "Retrieved $($objects.Count) non-mailbox recipients for OperationType $OperationType" -Verbose
	
	
	
	if (  [string]::IsNullOrEmpty( $PSScriptRoot ) )
		{ $excludeFilePath = join-path  $($PWD.Path) "ExcludedEmails.csv"}
	else { $excludeFilePath = join-path $PSScriptRoot  "ExcludedEmails.csv"}
	
	$exclude = get-content -Path $excludeFilePath  -ErrorAction Continue
	$objects = $objects | Where {$_.primarysmtpaddress -notin $exclude} 
    LogThis -String "Retrieved $($objects.Count) mailboxes for OperationType $OperationType" -Verbose
    $objects
    
}

# Know where we are at in relation to the pagesize from the Run Profile
[int]$objectpagecount = 0

Function Get-MaObject {
    param(
        $mailbox
    )
    # $mailbox = $redirected
    # $mailbox = $Global:Objects[0]
    $UserObj = @{}
    if ($Mailbox.RecipientType.ToLower() -Like "*group*")
    {
         $UserObj.add("objectClass", "Group")
    }
    # else
    # {
        # $UserObj.add("objectClass", "User")
    # }
    
    $UserObj.add("ExchangeGuid", $mailbox.ExchangeObjectId.ToString())

    if ($Mailbox.WhenSoftDeleted -gt '1/1/2001') #always false during a full since we are not including this property
    {
        $UserObj.add("[ChangeType]", "Delete") 
    }
    else
    {
        #Minimum
        $UserObj.add("PrimarySmtpAddress", $mailbox.PrimarySmtpAddress) 
	    $UserObj.add("RecipientType", $mailbox.RecipientType) 
	    $UserObj.add("RecipientTypeDetails", $mailbox.RecipientTypeDetails) 
    
	   
	    $UserObj.add("Alias", $mailbox.Alias) 
	    $UserObj.add("DisplayName", $mailbox.DisplayName)
   
        
        $UserObj.add("DistinguishedName", $mailbox.DistinguishedName)  
    
	   	
	    #AddressList	
	    $UserObj.add("HiddenFromAddressListsEnabled", $mailbox.HiddenFromAddressListsEnabled) #[boolean]
		#ExternalDirectoryObjectID,EmailAddresses
		$UserObj.add("ExternalDirectoryObjectID", $mailbox.ExternalDirectoryObjectID)  
		 if ($mailbox.EmailAddresses){
		$Addresses = @()
		foreach($Address in $mailbox.EmailAddresses) {
			$Addresses += $Address
		}
		$UserObj.Add("EmailAddresses",($Addresses))
	}
	}
    
	#end mailbox attributes

	# Pass the User Object back
    $UserObj
}

Function Full-Import {
	$objectpagecount =0
    Foreach ($Global:Object in $Global:Objects) {
        # continue from where we go to from the previous page of objects processed
        # $Global:Object = $Global:Objects[0]
        #$Object = $Global:Objects[$global:objectsImported + 1]
		$Object = $Global:Objects[$global:objectsImported]
        # if we are at the end then set MoreToImport to False and quit
        #if (!$Global:Object -or ($global:objectsImported +1 -eq $Global:Objects.count)) {
		if (!$Global:Object -or ($global:objectsImported  -eq $Global:Objects.count)) {
            # nothing left to process
            $global:MoreToImport = $false
            #Remove-PSSession -Name $Global:PSSessionName
            Add-Content -Path $TimestampPath -Value $TodayImportStartUTC
            #Disconnect-ExchangeOnline -Confirm:$false
            break
        }
        
        #redirect to the nth object in $Global:Objects
        #$redirected = $Global:Objects[$global:objectsImported + 1]
		$redirected = $Global:Objects[$global:objectsImported]
        
        $MaObject = Get-MaObject -mailbox $redirected

        #Return the object for the function
        $MaObject

        # Increase the object count
        $objectpagecount++
        # for logging how many we've processed
        $global:objectsImported++
        if($Debug -eq $false){
            LogThis -String "PageCount $objectpagecount/$pagesize : Total $($global:objectsImported)/$($Global:Objects.count) : $($redirected.alias) $($redirected.ExchangeObjectId)" -Verbose
        }

        if ($objectpagecount -eq $pagesize){ 
            $global:MoreToImport = $true
            LogThis -String "More to Import: $($objectpagecount)" -Verbose
            break
        }
	}	
}

Function Delta-Import {
    param(
        $LastImportUTC
    )
    # continue from where we go to from the previous page of objects processed
    LogThis -String "Performing Delta Import" -Verbose
	$objectpagecount=0
    foreach($Global:Object in $Global:Objects){
        # $Global:Object = $Global:Changed[0]
        # if we are at the end then set MoreToImport to False and quit
        if (!$Global:Object -or ($global:objectsImported -eq $Global:Objects.count)) {
            # nothing left to process
            $global:MoreToImport = $false
            LogThis -String "Hit the Delta-Import break" -Verbose
            
            break
        }

        $redirected = $Global:Objects[$global:objectsImported ]

        $MaObject = Get-MaObject -mailbox $redirected
        $MaObject

        # Increase the object count
        $objectpagecount++
        # for logging how many we've processed
        $global:objectsImported++

        if($Debug -eq $false){
            LogThis -String "PageCount $objectpagecount/$pagesize : Total $($global:objectsImported)/$($Global:Objects.count) : $redirected" -Verbose
        }
    
        if ($objectpagecount -eq $pagesize){ 
            $global:MoreToImport = $true
            LogThis -String "More to Import: $($objectpagecount)" -Verbose
            break
        }
    }
}
	
$TodayImportStartUTC = (Get-Date).ToUniversalTime().ToString($UTC_format)
$DefaultStart = "19700321T000000"
if (!$global:objectsImported )
{
	$global:objectsImported = 0
}
if(test-path $TimestampPath){
    $LastLine = get-content -Path $TimestampPath -Tail 1
    try{
        #$LastLine = "20200922T140951"
        $LastImportUTC = [datetime]::ParseExact($LastLine,$UTC_format,$null)
        LogThis -String "     Using datestamp $LastLine " -Verbose
    }catch{
        $LastImportUTC = [datetime]::ParseExact($DefaultStart,$UTC_format,$null)
        LogThis -String "     Could not use datestamp $LastLine, using 19700321T000000" -Verbose
    }
}else{
    LogThis -String "     No Delta File Found " -Verbose
    #Resetting from Delta to Full
    $OperationType = "Full"
    LogThis -String "     Setting $OperationType to Full" -Verbose
}

if($Global:Objects){
	LogThis -String "     We have our objects to process " -Verbose
}else{
    LogThis -String "Opening a new Connect-ExchangeOnline session" -Verbose
    Connect-ExchangeOnline -AppId $AppId -CertificateThumbprint $Thumbprint -Organization $org #-ConnectionUri https://ps.outlook.com/powershell -ShowBanner:$false

    $Global:Objects = Get-Objects -OperationType $OperationType -LastImportUTC $LastImportUTC
    Disconnect-ExchangeOnline -Confirm:$false
}
if($Global:Objects){
    switch($OperationType){
        "Full"{
            $Results = Full-Import
            #return the objects to the MA
            $Results
            $SwitchMessage = "Full Import Page Complete"
            
        }
        "Delta"{
            $Results = Delta-Import -LastImportUTC $LastImportUTC
            #return the objects to the MA
            $Results
            $SwitchMessage = "Delta Import Page Complete"
        }
        default{
            $SwitchMessage = "Unknown OperationType $OperationType"
        }
    }
    LogThis -String $SwitchMessage -Verbose
}else{
    LogThis -String "Could not obtain mailboxes from Get-ExoMailbox" -Verbose
}

if($global:MoreToImport -ne $true){
    try{
        LogThis -String "MoreToImport not true, setting Timestamp to $TodayImportStartUTC"
        Add-Content -Path $TimestampPath -Value $TodayImportStartUTC
        
    }catch{
        $String = $_.Exception.Message
        LogThis -String $String -Verbose
    }
}else{
    LogThis -String "MoreToImport = true"
    
}
$String = "global:MoreToImport is $($global:MoreToImport)"
LogThis -String $String -Verbose
