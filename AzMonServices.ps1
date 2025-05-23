# List of specific services to monitor
$servicesToMonitor = @(
    "SLAgentSvc", "ADSService", "AFSService", "ADWS", "CertSvc", "NTDS", "adfssrv",
    "ANSYSLicensingTomcat", "OssecSvc", "nxlog", "AzureADConnectHealthAgent", 
    "AzureADConnectAgentUpdater", "ADSync", "RecoveryServicesManagementAgent", 
    "FileSyncSvc", "HybridConnectionManager", "DIAHostService", "Bit_Slapp_Poller",
    "CitrixWorkspaceCloudAgentSystem", "CoreSrvr", "CylanceSvc", "DAAdminSv",
    "Desktop Authority Manager Service", "DHCPServer", "DFS", "DNS", "DrillScan-rlm",
    "DptSecServiceWinService", "FedExAdminService", "GAGEmail.Service.12.0", "gpsvc",
    "HP UDA Service", "IISADMIN", "Jet Data Manager Server 20.10.26.64", "Jet.Services",
    "Active Directory Integration Sync Service", "Sense", "MSMQ", "ClusSvc",
    "SQLSERVERAGENT", "MSSQLSERVER", "MicrosoftDynamicsNavServer$AtlasProd",
    "MicrosoftDynamicsNavServer$DemoDB", "MicrosoftDynamicsNavServer$NAVThickClientProd",
    "MicrosoftDynamicsNavServer$NAVWEBClientProd", "MicrosoftDynamicsNavServer$RESCUE",
    "MicrosoftDynamicsNavServer$SSRSReportJetProd", "MicrosoftDynamicsNavServer$TESTATLAS01",
    "OneStreamSmartIntegration", "NPSrvHost", "IAS", "TermServiceLicensing", "Ccmexec",
    "Generic_Agent", "snc_mid_SNDiscoveryDev", "Siemens PLM License Server", "SMTPSVC",
    "ArchiveServerService", "ConisioDbServer", "SolidWorks SolidNetWork License Manager",
    "MsDtsServer110", "MsDtsServer130", "MsDtsServer140", "MsDtsServer150",
    "SQLServerReportingServices", "sms_executive", "sms_site_component_manager",
    "sms_site_sql_backup", "sms_site_vss_writer", "cmrcservice", 
    "configuration_manager_update", "wdsserver", "w3svc", "wsusservice", "Undelete",
    "VeeamBackupSvc", "VeeamTransportSvc", "VeeamDeploymentService", "VeeamWANSvc",
    "MSSQL$VEEAMSQL2012", "hasplms", "SentinelKeysServer", "MpsSvc", "Spooler", "XMCDR_01"
)

# Define the Log Analytics destination
$logAnalyticDestination = @{
    Name = "ServiceStateLogs"
    WorkspaceResourceId = $workspaceId
}

# Define the data flow
$dataFlow = @(
    @{
        Streams      = @("Microsoft-Windows-Service")
        Destinations = @("ServiceStateLogs")
    }
)

# Define the data source for Windows Service State
$dataSources = @(
    @{
        Name   = "ServiceStateSource"
        Kind   = "WindowsService"
        Streams = @("Microsoft-Windows-Service")
        Properties = @{
            ServiceNames = $servicesToMonitor
        }
    }
)

# Create the Data Collection Rule
$dcr = New-AzDataCollectionRule -Name ServicesMonitoring -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Name $dcrName `
    -DataSources $dataSources `
    -DataFlow $dataFlow `
    -DestinationLogAnalytic @($logAnalyticDestination) `
    -Description "DCR for Monitoring Specific Windows Services"

# Verify DCR creation
$dcr
