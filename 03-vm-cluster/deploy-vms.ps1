############################### INPUT PARAMS ##############################
#
# Before running the script, set the params for your specific subscription and deployment!
#
$subscriptionName = "YOUR_AZURE_SUBSCRIPTION_NAME"      # Name of your Azure Subscription
$location         = "North Europe"                      # datacenter Location where you want to deploy the VM
$rsgGrpName       = "YOUR_RESOURCE_GROUP_NAME"          # name of the Resource Group
$rsgGrpDeployment = "deployVMs"                         # Name of the deployment
$armTemplate      = "deployVMs.json"                    # Name of the ARM template in your current folder
$armParams        = "deployVMs-parameters.json"         # Name of the ARM paramenter file in your current folder

###########################################################################
#
#
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

$pathFiles=(Get-Item -Path ".\" -Verbose).FullName
$templateFile ="$pathFiles\$armTemplate"
$parametersFile = "$pathFiles\$armParams"

Get-AzureRmSubscription -SubscriptionName $subscriptionName | Select-AzureRmSubscription
New-AzureRmResourceGroup -Name $rsgGrpName -Location $location


$TimeStart = Get-Date -format HH:mm:ss

write-host -ForegroundColor Yellow "ARM template: " $templateFile
write-host -ForegroundColor Yellow "ARM Params  : " $parametersFile
New-AzureRmResourceGroupDeployment -Name $rsgGrpDeployment -ResourceGroupName $rsgGrpName -TemplateFile $templateFile -TemplateParameterFile  $parametersFile -Verbose
Start-Sleep -Seconds 10

$TimeEnd = Get-Date -format HH:mm:ss
diffTime $TimeStart $TimeEnd
