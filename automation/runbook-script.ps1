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
#$templateCreateURI = ""
#$templateDeleteURI = ""

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
