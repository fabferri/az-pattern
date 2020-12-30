################# Input parameters #################
$subscriptionName1     = "AzDev"
$subscriptionName2     = "faber"
$location1             = "eastus"
$location2             = "eastus"
$resourceGrp1          = "RG-A"
$resourceGrp2          = "RG-B"
$resourceGrpDeploy1    = "deploy-vnet1"
$resourceGrpDeploy2    = "deploy-vnet2"
$resourceGrpDeploy3    = "peering-to-vnet2"
$resourceGrpDeploy4    = "peering-to-vnet1"
$armTemplateFile1      = "vnet-a.json"
$armTemplateFile2      = "vnet-b.json"
$armTemplateFile3      = "vnet-peering.json"
$vnet1Name             = "vnet1"
$vnet2Name             = "vnet2"

####################################################
$pathFiles      = Split-Path -Parent $PSCommandPath
$templateFile1  = "$pathFiles\$armTemplateFile1"
$templateFile2  = "$pathFiles\$armTemplateFile2"
$templateFile3  = "$pathFiles\$armTemplateFile3"

###################  Create vnet1
$subscr1=Get-AzSubscription -SubscriptionName $subscriptionName1
Select-AzSubscription -SubscriptionId $subscr1.Id

$parameters=@{ "location"=$location1;
               "vnetName"=$vnet1Name}


New-AzResourceGroup -Name $resourceGrp1 -Location $location1
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "ARM template: "$templateFile1 -ForegroundColor Cyan

try {
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGrp1 -Name $vnet1Name -ErrorAction Stop -WarningAction SilentlyContinue
    Write-Host 'VNet '$vnet1Name' already exists... skipping' -foregroundcolor Green 
} catch {
   $runTime=Measure-Command {
      New-AzResourceGroupDeployment  -Name $resourceGrpDeploy1 -ResourceGroupName $resourceGrp1 -TemplateFile $templateFile1 -TemplateParameterObject $parameters -Verbose
   } ## end measure-command
   Write-Host "runtime to create vnet1: "$runTime.ToString() -ForegroundColor Yellow
}



###################  Create vnet2
$subscr2=Get-AzSubscription -SubscriptionName $subscriptionName2
Select-AzSubscription -SubscriptionId $subscr2.Id

$parameters=@{ "location"=$location2;
               "vnetName"=$vnet2Name}
## Create vnet1

New-AzResourceGroup -Name $resourceGrp2 -Location $location2
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "ARM template: "$templateFile2 -ForegroundColor Cyan

try {
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGrp2 -Name $vnet2Name -ErrorAction Stop -WarningAction SilentlyContinue
    Write-Host 'VNet '$vnet2Name' already exists... skipping' -foregroundcolor Green 
} catch {
   $runTime=Measure-Command {
     New-AzResourceGroupDeployment  -Name $resourceGrpDeploy2 -ResourceGroupName $resourceGrp2 -TemplateFile $templateFile2 -TemplateParameterObject $parameters -Verbose
   }
   write-host "runtime to create vnet2: "$runTime.ToString() -ForegroundColor Yellow
}


###################  Create peering vnet1 to vnet2
$remoteSubscriptionId=Get-AzSubscription -SubscriptionName $subscriptionName2
$parameters=@{ "existingLocalVNetName"=$vnet1Name;
               "remoteSubscriptionId"=$remoteSubscriptionId.Id;
               "existingRemoteVNetName"=$vnet2Name;
               "existingRemoteVNetResourceGroupName"=$resourceGrp2; 
               "location"=$location1;
               "vnetpeeringName"= "peering-to-vnet2" }

               
$subscr1=Get-AzSubscription -SubscriptionName $subscriptionName1
Select-AzSubscription -SubscriptionId $subscr1.Id


$runTime=Measure-Command {
   Try {Get-AzResourceGroup -Name  $resourceGrp1 -ErrorAction Stop | Out-Null
        Write-Host (Get-Date)' - ' -NoNewline
        Write-Host "Create vnet peering in: "$vnet1Name -ForegroundColor Cyan
        New-AzResourceGroupDeployment  -Name $resourceGrpDeploy3 -ResourceGroupName $resourceGrp1 -TemplateFile $templateFile3 -TemplateParameterObject $parameters -Force -Mode Incremental
   }
   catch {
       Write-Host (Get-Date)' - ' -NoNewline
       Write-Host "Check if the vnet exists" -ForegroundColor Cyan
       Exit
   }
}
write-host "$vnet1Name -runtime to create vnet peering: "$runTime.ToString() -ForegroundColor Yellow
##
###################  Create peering vnet2 to vnet 1
$remoteSubscriptionId=Get-AzSubscription -SubscriptionName $subscriptionName1
$parameters=@{ "existingLocalVNetName"=$vnet2Name;
               "remoteSubscriptionId"=$remoteSubscriptionId.Id;
               "existingRemoteVNetName"=$vnet1Name;
               "existingRemoteVNetResourceGroupName"=$resourceGrp1; 
               "location"=$location2;
               "vnetpeeringName"= "peering-to-vnet1" }

$subscr2=Get-AzSubscription -SubscriptionName $subscriptionName2
Select-AzSubscription -SubscriptionId $subscr2.Id


$runTime=Measure-Command {
   try {Get-AzResourceGroup -Name  $resourceGrp2 -ErrorAction Stop | Out-Null
        Write-Host (Get-Date)' - ' -NoNewline
        Write-Host "Create vnet peering in: "$vnet2Name -ForegroundColor Cyan
        New-AzResourceGroupDeployment  -Name $resourceGrpDeploy4 -ResourceGroupName $resourceGrp2 -TemplateFile $templateFile3 -TemplateParameterObject $parameters -Force -Mode Incremental -Verbose
   }
   catch {
       Write-Host (Get-Date)' - ' -NoNewline
       Write-Host "Check if the vnet exists" -ForegroundColor Cyan
       Exit
   }
}

Write-Host "$vnet2Name -runtime to create vnet peering: "$runTime.ToString() -ForegroundColor Yellow