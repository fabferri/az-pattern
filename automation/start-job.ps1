$subscriptionName = "AzDev"
$runbookName="createVM"
$automationAccountName= "automation1"
$rgName="rg-automation"
$adminUsername="ADMINISTRATOR_USERNAME"
$adminPassword="ADMINISTRATOR_PASSWORD"
$vmName="vm1"

$WaitForJobCompletion = $true
$ReturnJobOutput = $true
$JobPollingIntervalInSeconds = 10
$JobPollingTimeoutInSeconds = 600

# Determine if parameter values are incompatible
if(!$WaitForJobCompletion -and $ReturnJobOutput) {
       $msg = "The parameters WaitForJobCompletion and ReturnJobOutput must both "
       $msg += "be true if you want job output returned."
       throw ($msg)
   }

# select the Azure subscription
$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id 

$params = @{"adminUsername"=$adminUsername;"adminPassword"=$adminPassword;"vmName"=$vmName}

$job=Start-AzAutomationRunbook -AutomationAccountName $automationAccountName -Name $runbookName -ResourceGroupName $rgName -Parameters $params -Verbose -ErrorAction "Stop"


 # Determine if there is a job and if the job output is wanted or not
 if ($job -eq $null) {
        # No job was created, so throw an exception
        throw ("No job was created for runbook: $runbookName.")
 }
 else {
        # There is a job
        
        # Log the started runbook’s job id for tracking
        Write-Verbose "Started runbook: $runbookName. Job Id: $job.JobId"
        
        if (-not $WaitForJobCompletion) {
            # Don't wait for the job to finish, just return the job id
            Write-Output $job.JobId
        }
        else {
            # Monitor the job until finish or timeout limit has been reached
            $maxDateTimeout = (Get-Date).AddSeconds($JobPollingTimeoutInSeconds)
            
            $doLoop = $true
            
            while($doLoop) {
                Write-Output "$(Get-Date) - sleeping (in sec): $JobPollingIntervalInSeconds"
                Start-Sleep -s $JobPollingIntervalInSeconds
                
                $job = Get-AzAutomationJob `
                    -Id $job.JobId `
                    -AutomationAccountName $automationAccountName `
                    -ResourceGroupName $rgName
                
                if ($maxDateTimeout -lt (Get-Date)) {
                    # timeout limit reached so exception
                    $msg = "The job for runbook $runbookName did not "
                    $msg += "complete within the timeout limit of "
                    $msg += "$JobPollingTimeoutInSeconds seconds, so polling "
                    $msg += "for job completion was halted. The job will "
                    $msg += "continue running, but no job output will be returned."
                    throw ($msg)
                }
                
                $doLoop = (($job.Status -notmatch "Completed") `
                          -and ($job.Status -notmatch "Failed") `
                          -and ($job.Status -notmatch "Suspended") `
                          -and ($job.Status -notmatch "Stopped"))
            }
            
            if ($job.Status -match "Completed") {
                if ($ReturnJobOutput) {
                    # Output
                    $jobout = Get-AzAutomationJobOutput `
                                    -Id $job.JobId `
                                    -AutomationAccountName $automationAccountName `
                                    -ResourceGroupName $rgName `
                                    -Stream Output 
                    if ($jobout) {Write-Output $jobout.Text}
                    
                    # Error
                    $jobout = Get-AzAutomationJobOutput `
                                    -Id $job.JobId `
                                    -AutomationAccountName $automationAccountName `
                                    -ResourceGroupName $rgName `
                                    -Stream Error
                    if ($jobout) {Write-Error $jobout.Text}
                    
                    # Warning
                    $jobout = Get-AzAutomationJobOutput `
                                    -Id $job.JobId `
                                    -AutomationAccountName $automationAccountName `
                                    -ResourceGroupName $rgName `
                                    -Stream Warning
                    if ($jobout) {Write-Warning $jobout.Text}
                    
                    # Verbose
                    $jobout = Get-AzAutomationJobOutput `
                                    -Id $job.JobId `
                                    -AutomationAccountName $automationAccountName `
                                    -ResourceGroupName $rgName `
                                    -Stream Verbose
                    if ($jobout) {Write-Verbose $jobout.Text}
                }
                else {
                    # Return the job id
                    Write-Output $job.JobId
                }
            }
            else {
                # The job did not complete successfully, so throw an exception
                $msg = "The child runbook job did not complete successfully."
                $msg += "  Job Status: " + $job.Status + "."
                $msg += "  Runbook: " + $runbookName + "."
                $msg += "  Job Id: " + $job.JobId + "."
                $msg += "  Job Exception: " + $job.Exception
                throw ($msg)
            }
        }
    }