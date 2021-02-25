<properties
pageTitle= 'Deploy an ARM template in a PowerShell runbook'
description= "Deploy an ARM template in a PowerShell runbook"
documentationcenter: na
services=""
documentationCenter="na"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="na"
   ms.date="23/02/2021"
   ms.author="fabferri" />

# Deploy an ARM template in a PowerShell runbook
The article walks through the steps to deploy an ARM template through Azure Automation. The ARM template creates Azure VNet with single Azure VM.
The process can be extended to more complex deployments.

The overview diagram is reported below: 

[![1]][1]

The  PowerShell Runbook in Account Automation, makes the following actions:
* check the presence of Azure VM, NIC, VNet, NSG. 
* if an object in a specific resource group exists, an empty ARM template runs to delete the existing objects. The ARM template to delete resources is stored in azure storage container and exposed to internet with shared access signature (SAS).
* if the objects (VM, NIC, VNet, NSG) do not exist, it runs an ARM template to create the Azure VM runs. The ARM template to create Azure VM is stored in Azure storage container and exposed to internet with shared access signature (SAS).

The powershell Runbook can be started as a child runbook with **Start-AzAutomationRunbook**.

## List of files
| file                     | Description                                                           | 
| ------------------------ |---------------------------------------------------------------------- | 
| **ubuntuVM.json**        | ARM template to deploy an VNet with single ubuntu VM                  |
| **delete.json**          | ARM template (empty) to delete an existing deployment                 |
| **storage-account-sas.ps1** | powershell script to create a storage account with storage container and SAS|
| **start-job.ps1**        | powershell script to start an Azure automation job                    |
| **runbook-script.ps1**   | powerhell script to be associated with the runbook - it doesn't run in interactive powershell section, becausue it is based on service principle associated with Automation Account|
| **ubuntuVM.ps1**         | powershell script to deploy **ubuntuVM.json**; it is not a request file for our automation achievement  |
| **delete.ps1**           | powershell script to deploy **delete.json**; it is not a request file for our automation achievement    |

## Step1: Create a storage account to store the ARM templates
When Automation executes runbook, it loads the modules into sandboxes where the runbooks can run. 
To pass the ARM template file to the runbook, an Azure Storage is required as central repository.
The powershell **storage-account-sas.ps1** creates an Azure Storage account with storage container (named /home) with SAS.
The powershell **storage-account-sas.ps1** script copies the two ARM templates **ubuntuVM.json** and **delete.json** in the container: both 

[![2]][2]

<h3>
NOTE: At the end of run two the ARM templates <bold>ubuntuVM.json</bold> and <bold>delete.json<bold> are downloaded in the local script folder, renamed file1.json and file2.json 
</h3>

## Step2: Create an Azure Automation account by Azure Management portal
To create an Azure Automation account:
1.	Click the Create a resource button found in the upper left corner of Azure portal.
2.	Select **IT & Management Tools**, and then select **Automation**.

[![3]][3]

For **Create Azure Run As account**, leave the default option **Yes**. This will create a **Run As account** in the Automation account which are useful for authenticating with Azure to manage Azure resources from Automation runbooks. 

[![4]][4]

When you create an Automation account, the **Run As account** is created by default at the same time.

When you create a **Run As account**, it performs the following tasks:
* Creates an Azure AD application with a self-signed certificate, creates a service principal account for the application in Azure AD, and assigns the Contributor role for the account at the subscription level. The self-signed certificate that you have created for the **Run As account** expires one year from the date of creation.
* Creates an Automation certificate asset named **AzureRunAsCertificate** in the specified Automation account. The certificate asset holds the certificate private key that the Azure AD application uses.
* Creates an Automation connection asset named AzureRunAsConnection in the specified Automation account. The connection asset holds the application ID, tenant ID, subscription ID, and certificate thumbprint.

**Run As accounts** in Azure Automation provide authentication for managing resources on the ARM, using Automation runbooks. 

## Step3: Import modules in Azure automation
Azure Automation uses a number of PowerShell modules to enable cmdlets in runbooks. Automation doesn't import the root Az module automatically into any new or existing Automation accounts.

Let's import the following modules: **az.accounts, az.network, az.automation, az.profile, az.resources** and **az.compute**

* **az.resources** module is required to run the powershell command: New-AzResourceGroupDeployment 
* **az.Compute** module is requited to run the powershell command: Get-AzVM

In the **Automation Account** -> **Modules Gallery** search for **az.**:

[![5]][5]

than import the modules **az.accounts, az.network, az.automation, az.profile, az.resources, az.Compute**

[![6]][6]

An example of import of **Az.Accounts** modules:
[![7]][7]

[![8]][8]


The imported Az module are visible in **Automation Account** -> **Modules** in Azure portal:

[![9]][9]

The automation account is now ready to interpret the Azure powershell in runbook.



## Step4: Create a runbook
In **Automation Account** -> **Runbooks** click-on **Create a runbook**
[![10]][10]

Assign a name to the runbook and in _Runbook type_ select **Powershell**:

[![11]][11]

In **Edit PowerShell Rubook** paste in the powershell script you want to run:

[![12]][12]

Below the powershell associated with the Runbook:
```powershell
param (
    [Parameter( Mandatory = $false,  HelpMessage='username administrator VMs')]
    [string]$adminUsername = "ADMINISTRATOR_USERNAME",
 
    [Parameter(Mandatory = $false, HelpMessage='password administrator VMs')]
    [string]$adminPassword = "ADMINISTRATOR_PASSWORD",

    [Parameter(Mandatory = $false, HelpMessage='VM name')]
    [string]$vmName = "vm1",

    [Parameter(Mandatory = $false, HelpMessage='Create VM-URI')]
    [string]$templateCreateURI = "https://repo392aa1a5f0.blob.core.windows.net/home/ubuntuVM.json?sv=2019-07-07&sr=c&si=storage-policy&sig=CELTizVtnK0%2FB96JbFuCqhLF9BP78I8j1Ofcsr5wF4s%3D",

    [Parameter(Mandatory = $false, HelpMessage='delete VM-URI')]
    [string]$templateDeleteURI = "https://repo392aa1a5f0.blob.core.windows.net/home/delete.json?sv=2019-07-07&sr=c&si=storage-policy&sig=CELTizVtnK0%2FB96JbFuCqhLF9BP78I8j1Ofcsr5wF4s%3D"
    )

# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process | Out-Null

$subscriptionName = "AzDev" 
$location = "eastus"
$rgName = "Test-vm-00001"
$deploymentName = "vm-test"

$RGTagExpireDate =((Get-Date).AddMonths(1)).ToString('yyyy-MM-dd')
$RGTagContact = 'user1@contoso.com' 
$RGTagAlias = 'user1' 
$RGTagUsage = 'dev VM' 

$parameters=@{
              "adminUsername"= $adminUsername;
              "adminPassword"= $adminPassword;
              "vmName"=$vmName
              }

Try {

   $conn = Get-AutomationConnection -Name 'AzureRunAsConnection'
   while(!($connectionResult) -And ($logonAttempt -le 5))
   {
        $LogonAttempt++
        # Logging in to Azure...
        $connectionResult =  Connect-AzAccount `
                               -ServicePrincipal `
                               -ApplicationId $conn.ApplicationId `
                               -Tenant $conn.TenantId `
                               -CertificateThumbprint $conn.CertificateThumbprint `
                               -Subscription $conn.SubscriptionId `
                               -Environment AzureCloud 
                               
        Start-Sleep -Seconds 10
    }
} Catch {
    if (!$conn)
    {
        $ErrorMessage = "Service principal not found."
        throw $ErrorMessage
    } 
    else
    {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

# Get the name of the Azure subscription
$subscriptionName=(Get-AzSubscription -SubscriptionId $conn.SubscriptionId).Name

write-Output "$(Get-Date) - selection of the Azure subscription: $subscriptionName" 
Select-AzSubscription -SubscriptionId $conn.SubscriptionId | Out-Null


write-Output "$(Get-Date) - Creating Resource Group $rgName" 
Try {$rg = Get-AzResourceGroup -Name $rgName  -ErrorAction Stop
     write-Output "$(Get-Date) - Resource Group $rgName exists, skipping"}
Catch {$rg = New-AzResourceGroup -Name $rgName  -Location $location  
             write-Output "$(Get-Date) - set tags in Resource Group $rgName"
             Set-AzResourceGroup -Name $rgName `
             -Tag @{Expires=$RGTagExpireDate; Contacts=$RGTagContact; Owner=$RGTagAlias; Usage=$RGTagUsage} | Out-Null
}


write-Output ""
write-Output "$(Get-Date) - checking resources in resource group: $rgName"
Try {
       $numVM= @(Get-AzVM -ResourceGroupName $rgName).Count  
       $numNIC= @(Get-AzNetworkInterface -ResourceGroupName $rgName).Count 
       $numPubIP= @(Get-AzPublicIpAddress -ResourceGroupName $rgName).Count
       $numNSG= @(Get-AzNetworkSecurityGroup -ResourceGroupName $rgName).Count
       $numVNet= @(Get-AzVirtualNetwork -ResourceGroupName $rgName).Count
       write-Output "$(Get-Date) - number VMs: $numVM"
       write-Output "$(Get-Date) - number NICs: $numNIC"
       write-Output "$(Get-Date) - number pubIP: $numPubIP"
       write-Output "$(Get-Date) - number NSG: $numNSG"
       write-Output "$(Get-Date) - number VNet: $numVNet"
       if (( $numVM -gt 0) -or ($numNIC -gt 0) -or ($numPubIP -gt 0) -or ($numNSG -gt 0) -or ($numVNet -gt 0) )
       {
         write-Output "$(Get-Date) - running ARM template to delete resources: $templateDeleteURI"
         $runTimeDelete=Measure-Command {
            New-AzResourceGroupDeployment -Mode Complete -Name $deploymentName -ResourceGroupName $rgName -TemplateUri $templateDeleteURI -Verbose -Force -ErrorAction Stop
         }
         write-Output "$(Get-Date) - runtime resource deletion: $runTimeDelete" 
         write-Output "$(Get-Date) - deletion resources in resource group: $rgName completed!"
         write-Output "$(Get-Date) - sleeping for 45 sec"
         Start-Sleep -Seconds 45
      } 
    }
Catch { 
   write-Output "$(Get-Date) - Error in deployment the ARM template deletion!"
}
write-Output "$(Get-Date) - running ARM template: "$templateCreateURI
$runTime=Measure-Command {
    New-AzResourceGroupDeployment -Mode incremental -ResourceGroupName $rgName -Name $deploymentName -TemplateUri $templateCreateURI -TemplateParameterObject $parameters -verbose
}
write-Output "runtime VM creation: $runTime" 
write-Output "$(Get-Date) - end of VM creation"
```
<h2>[NOTE!]</h2>
<h3>
In the powershell script above, replace: 
<ul>
<li>"ADMINISTRATOR_USERNAME" with the administrator username of the VM</li>
<li>"ADMINISTRATOR_PASSWORD" with the administrator password of the VM</li>
<li>$templateCreateURI: URL to access to the ARM template to create the deployment. The template is stored in storage container</li>
<li>$templateDeleteURI:URL to access to the ARM template to delete the deployment. The template is stored in storage container</li>
</h3>

After the association of powershell script to the runbook is good practice verify the workflow run as expected.

In **Edit Powershell Runbook** select **Test pane**:
[![13]][13]

Click-on **Start** for starting the test.
[![14]][14]

when you are satify of outcome, click-on **Save** button and then **Publish** button:

[![15]][15]


## Step5: Submit a runbook job
If you want to start a runbook asynchronously from the PowerShell console or within a runbook, use the **Start-AzAutomationRunbook** cmdlet
* Input parameters to the runbook that is started by **Start-AzAutomationRunbook** are passed in a hashtable as key/value pairs.

Here a basic example to invoke the powershell Runbook:

```console
$subscriptionName = "AzDev"
$runbookName="createVM"
$automationAccountName= "automation1"
$rgName="rg-automation"
$vmName="vm1"

# select the Azure subscription
$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id 

$params = @{"adminUsername"="ADMINISTRATOR_USERNAME";"adminPassword"="ADMINISTRATOR_PASSWORD";"vmName"=$vmName}

$job=Start-AzAutomationRunbook -AutomationAccountName $automationAccountName -Name $runbookName -ResourceGroupName $rgName -Parameters $params -Verbose
```

The script **start-job.ps1** has more useful job control:
```
$subscriptionName = "AzDev"
$runbookName="createVM"
$automationAccountName= "automation1"
$rgName="rg-automation"
$adminUsername="edgeuser"
$adminPassword="workshop!!**101**"
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
                    $jobout = Get-AzureAutomationJobOutput `
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
``` 
Runbook jobs are visible inside the Rubook panel:

[![16]][16]

In this specific example the job is queued, before executing.

## Reference
[Azure Automation: Runbook Input, Output, and Nested Runbooks](https://azure.microsoft.com/en-gb/blog/azure-automation-runbook-input-output-and-nested-runbooks/)

<!--Image References-->
[1]: ./media/network-diagram.png "Create an Azure Automation account"
[2]: ./media/02.png "copy ARM templates into storage account"
[3]: ./media/03.png "Create an Azure Automation account"
[4]: ./media/04.png "Create Run As account"
[5]: ./media/05.png "Search az. modules in Modules Gallery "
[6]: ./media/06.png "import few az.modules from Module Gallery"
[7]: ./media/07.png "import Az.Accounts module from Module Gallery"
[8]: ./media/08.png "imported Az.Accounts module"
[9]: ./media/09.png "list of imported Az modules"
[10]: ./media/10.png "Create a Runbook"
[11]: ./media/11.png "select the Runbook type"
[12]: ./media/12.png "paste in the powershell script in Runbook"
[13]: ./media/13.png "Runbook Test pane"
[14]: ./media/14.png "start a Runbook test"
[15]: ./media/15.png "publish the Runbook"
[16]: ./media/16.png "track Runbook jobs in Azure management portal"
<!--Link References-->

