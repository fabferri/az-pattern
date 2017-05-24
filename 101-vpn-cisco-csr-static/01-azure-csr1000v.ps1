################# Input parameters #################
# subscriptionName : name of subscription when you
# $location1        : location of Azure datacenter for the first deployment
# $location2        : location of Azure datacenter for the second deployment
# $destResourceGrp1: Resource Group name for the deployment1 
# $destResourceGrp2: Resource Group name for the deployment2
#
# selection of the deployments; specify the following flag variables:
#    $true : to create the deployment
#    $false: to skip the deployment
#
$subscriptionName = "YOUR_AZURE_SUBSCRITION_NAME"
$location1        = "northeurope"
$location2        = "northeurope"
$destResourceGrp1 = "RG01-NVA"
$destResourceGrp2 = "RG02-NVA"
$resourceGrpDeployment = "deploymentCSR"
$deployment1      = $true
$deployment2      = $true


####################################################
$pathFiles=Split-Path -Parent $PSCommandPath
$templateFile    = "$pathFiles\azuredeploy.json"
$parametersFile1 = "$pathFiles\azuredeploy.parameters1.json"
$parametersFile2 = "$pathFiles\azuredeploy.parameters2.json"

function diffTime
{
    param(  [Parameter(Mandatory=$true)] [System.DateTime]$Time1,
            [Parameter(Mandatory=$true)] [System.DateTime]$Time2 )

    $TimeDiff = New-TimeSpan $Time1 $Time2
    if ($TimeDiff.Seconds -lt 0)
    {
	    $Hrs = ($TimeDiff.Hours) + 23
	    $Mins = ($TimeDiff.Minutes) + 59
	    $Secs = ($TimeDiff.Seconds) + 59
    }
    else
    {
	    $Hrs = $TimeDiff.Hours
	    $Mins = $TimeDiff.Minutes
	    $Secs = $TimeDiff.Seconds
    }
    $Difference = '{0:00}:{1:00}:{2:00}' -f $Hrs,$Mins,$Secs
    write-host -ForegroundColor Green  "Start time          : " $Time1
    write-host -ForegroundColor Green  "End time            : " $Time2
    write-host -ForegroundColor Yellow "Total Execution Time: " $Difference
}



$subscr=Get-AzureRmSubscription -SubscriptionName $subscriptionName
Select-AzureRmSubscription -SubscriptionId $subscr.Id

if ($deployment1 -eq $true) {
##################### Deployment CSR1 ######
New-AzureRmResourceGroup -Name $destResourceGrp1 -Location $location1
write-host "deployment-Template file: " $templateFile " -parameter file:" $parametersFile1
$TimeStart = Get-Date -format HH:mm:ss
New-AzureRmResourceGroupDeployment -Name $resourceGrpDeployment -ResourceGroupName $destResourceGrp1 -TemplateFile $templateFile -TemplateParameterFile  $parametersFile1 -Verbose
$TimeEnd = Get-Date -format HH:mm:ss
diffTime $TimeStart $TimeEnd
##################################################
}

if ($deployment2 -eq $true) {
##################### Deployment in CSR2 #######
New-AzureRmResourceGroup -Name $destResourceGrp2 -Location $location2
write-host "deployment-Template file: " $templateFile " -parameter file:" $parametersFile2
$TimeStart = Get-Date -format HH:mm:ss
New-AzureRmResourceGroupDeployment -Name $resourceGrpDeployment -ResourceGroupName $destResourceGrp2 -TemplateFile $templateFile -TemplateParameterFile  $parametersFile2 -Verbose
$TimeEnd = Get-Date -format HH:mm:ss
diffTime $TimeStart $TimeEnd
###################################################
}
