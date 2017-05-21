################# Input parameters #################
##### the script spin up a single Azure Scale Set 
$subscriptionName ="YOUR_AZURE_SUBSCRIPTION_NAME"
$location ="northeurope"
$destResourceGrp="RGtest8804"
$resourceGrpDeployment = "deployVMSSScale"
$pathFiles=Split-Path -Parent $PSCommandPath

####################################################
$templateFile   = "$pathFiles\azureVMSSdeploy.json"
$parametersFile = "$pathFiles\azureVMSSdeploy.parameters.json"

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

$TimeStart = Get-Date -format HH:mm:ss

Get-AzureRmSubscription -SubscriptionName $subscriptionName | Select-AzureRmSubscription 
New-AzureRmResourceGroup -Name $destResourceGrp -Location $location

write-host $templateFile
write-host $parametersFile
New-AzureRmResourceGroupDeployment -Name $resourceGrpDeployment -ResourceGroupName $destResourceGrp -TemplateFile $templateFile -TemplateParameterFile  $parametersFile -Verbose

$TimeEnd = Get-Date -format HH:mm:ss
diffTime $TimeStart $TimeEnd

