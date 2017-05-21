############################### INPUT PARAMS ##############################
#
# Before running the script, set the params for your specific subscription and deployment!
#
###########################################################################
#
#
param(
    [Parameter(Mandatory=$true)]
    [string]$subscriptionName,
    [Parameter(Mandatory=$true)]
    [string]$location,
    [Parameter(Mandatory=$true)]
    [string]$vmssResourceGrp,
    [Parameter(Mandatory=$true)]   
    [string]$scaleSetName,
    [Parameter(Mandatory=$true)]
    [string]$scaleSetVMSize,
    [Parameter(Mandatory=$true)]
    [int]$newScaleSetCapacity
)     

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

$rsgGrpDeployment = "VMScaleSet"                           # Name of the deployment
$armTemplate      = "ScalingExistingVMSS.json"             # Name of the ARM template in your current folder
$armParams        = "ScalingExistingVMSS.parameters.json"  # Name of the ARM paramenter file in your current folder

$pathFiles=Split-Path -Parent $PSCommandPath
$templateFile   = "$pathFiles\$armTemplate"
$parametersFile = "$pathFiles\$armParams"

Get-AzureRmSubscription -SubscriptionName $subscriptionName | Select-AzureRmSubscription

$TimeStart = Get-Date -format HH:mm:ss

write-host -ForegroundColor Yellow "ARM template: " $templateFile
write-host -ForegroundColor Yellow "ARM Params  : " $parametersFile

$parameters=@{"existingVMSSName"=$scaleSetName;
              "vmSize"=$scaleSetVMSize;
              "newCapacity"=$newScaleSetCapacity;
              }

New-AzureRmResourceGroupDeployment -Name $vmssResourceGrp -ResourceGroupName $vmssResourceGrp -TemplateFile $templateFile -TemplateParameterObject $parameters -Verbose

$TimeEnd = Get-Date -format HH:mm:ss
diffTime $TimeStart $TimeEnd
