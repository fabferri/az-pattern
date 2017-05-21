################# Input parameters #################
##### Get the hostname and IP address of VMs in Scale Set deployments
#
#
$subscriptionName ="YOUR_AZURE_SUBSCRIPTION_NAME"
$location ="northeurope"
$ResourceGrpPrefix="RG-3"
$scaleSetPrefix ="azurd14"
$pathDesktop=[Environment]::GetFolderPath("Desktop")
$pathFolder=$pathdesktop+"\DeploymentNaming1"

Get-AzureRmSubscription -SubscriptionName $subscriptionName | Select-AzureRmSubscription 

#create a folder in the desktop
New-Item $pathFolder -type directory 


for($i=1; $i -le 11; $i++)
{
    $resourceGrp=$ResourceGrpPrefix+$i.ToString("00")
    $scaleSetName=$scaleSetPrefix+$i.ToString("00")
#    $namefile="./"+$scaleSetPrefix+$i.ToString("00")+".txt"
    $namefile="$pathFolder"+"\"+$scaleSetPrefix+$i.ToString("00")+".txt"
    write-host "Enumerating VM's from ScaleSet in Resource Group '"$resourceGrp "'"    
    $vmss = Get-AzureRmVmssVM -ResourceGroupName $resourceGrp -VMScaleSetName $scaleSetName

    Foreach($vm in $vmss)
    {
       $res =$scaleSetName+"/"+$vm.InstanceId.ToString()+"/"+$scaleSetName+"nic"
       $nic=Get-AzureRmResource -ResourceGroupName $resourceGrp -ResourceType Microsoft.Compute/virtualMachineScaleSets/virtualMachines/networkInterfaces -ResourceName $res -ApiVersion 2016-03-30

       $msg= $vm.Name +"--> "+ $nic.Properties.IpConfigurations[0].Properties.PrivateIPAddress 
       #  write-host -ForegroundColor Green $vm.Name "--> " $nic.Properties.IpConfigurations[0].Properties.PrivateIPAddress $msg
       
       $msg | Out-File $namefile -Append
    }
}

