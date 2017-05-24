################# Input parameters #################
$subscriptionName =""YOUR_AZURE_SUBSCRITION_NAME""
$location        = "northeurope"
$destResourceGrp = "RG-VMs"
$resourceGrpDeployment = "deployVMs"
$pathFiles=Split-Path -Parent $PSCommandPath

####################################################
$templateFile   = "$pathFiles\azure-vm.json"
$parametersFile1 = "$pathFiles\azure-vm1.parameters.json"
$parametersFile2 = "$pathFiles\azure-vm2.parameters.json"


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
New-AzureRmResourceGroup -Name $destResourceGrp -Location $location


############# Create first VM 
write-host -foregroundcolor cyan "template file: " $templateFile " - parameter files" $parametersFile1
$TimeStart = Get-Date -format HH:mm:ss
New-AzureRmResourceGroupDeployment -Name $resourceGrpDeployment -ResourceGroupName $destResourceGrp -TemplateFile $templateFile -TemplateParameterFile  $parametersFile1 -Verbose
$TimeEnd = Get-Date -format HH:mm:ss
diffTime $TimeStart $TimeEnd


############# Create second VM 
write-host -foregroundcolor cyan "template file: " $templateFile " - parameter files" $parametersFile2
$TimeStart = Get-Date -format HH:mm:ss
New-AzureRmResourceGroupDeployment -Name $resourceGrpDeployment -ResourceGroupName $destResourceGrp -TemplateFile $templateFile -TemplateParameterFile  $parametersFile2 -Verbose
$TimeEnd = Get-Date -format HH:mm:ss
diffTime $TimeStart $TimeEnd

