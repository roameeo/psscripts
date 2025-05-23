# Import the Az module
Import-Module Az.Accounts
Import-Module Az.Automation

# Variables - Replace with your details
$resourceGroupName = "OktaWorkflow_RG"
$automationAccountName = "oktawf"

# Login to Azure (if not already logged in)
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

# Get all jobs in a suspended state
$suspendedJobs = Get-AzAutomationJob -ResourceGroupName $resourceGroupName `
                                      -AutomationAccountName $automationAccountName |
                  Where-Object { $_.Status -eq 'Suspended' }

# Check if there are any suspended jobs
if ($suspendedJobs.Count -eq 0) {
    Write-Output "No suspended jobs found."
} else {
    # Stop each suspended job
    foreach ($job in $suspendedJobs) {
        Write-Output "Stopping suspended job: $($job.JobId)"
        Stop-AzAutomationJob -ResourceGroupName $resourceGroupName `
                             -AutomationAccountName $automationAccountName `
                             -Id $job.JobId
    }
    Write-Output "All suspended jobs have been stopped."
}
