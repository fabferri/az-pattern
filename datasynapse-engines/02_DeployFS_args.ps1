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
    [string]$VNetResourceGrp,
    [Parameter(Mandatory=$true)]
    [string]$virtualNetworkName,
    [Parameter(Mandatory=$true)]
    [string]$subnetName,
    [Parameter(Mandatory=$true)]
    [string]$vmssResourceGrp,
    [Parameter(Mandatory=$true)]   
    [string]$scaleSetName,
    [Parameter(Mandatory=$true)]
    [string]$scaleSetVMSize,
    [Parameter(Mandatory=$true)]
    [string]$storageAccountTypeScaleSet, 
    [Parameter(Mandatory=$true)]
    [int]$scaleSetInstanceCount,
    [Parameter(Mandatory=$true)]
    [string]$adminUser,
    [Parameter(Mandatory=$true)]
    [string]$adminPwd,
    [Parameter(Mandatory=$true)]
    [string]$fileSrvIPAddress,
    [Parameter(Mandatory=$true)]
    [string]$fileSrvName, 
    [Parameter(Mandatory=$true)]
    [string]$fileSrvVmSize, 
    [Parameter(Mandatory=$true)]
    [string]$fileSrvStorageAccountType
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

$rsgGrpDeployment = "FileServerDeployment"             # Name of the deployment
$armTemplate      = "azureFSdeploy.json"               # Name of the ARM template in your current folder
$armParams        = "azureFSdeploy.parameters.json"    # Name of the ARM paramenter file in your current folder
$secpassword = convertto-securestring $adminPwd -asplaintext -force
$vmAdminCreds = New-Object System.Management.Automation.PSCredential($adminUser, $secpassword)


$pathFiles=Split-Path -Parent $PSCommandPath
$templateFile ="$pathFiles\$armTemplate"
$parametersFile = "$pathFiles\$armParams"

Get-AzureRmSubscription -SubscriptionName $subscriptionName | Select-AzureRmSubscription
New-AzureRmResourceGroup -Name $vmssResourceGrp -Location $location

###

$TimeStart = Get-Date -format HH:mm:ss

write-host -ForegroundColor Yellow "ARM template: " $templateFile
write-host -ForegroundColor Yellow "ARM Params  : " $parametersFile

$parameters=@{
              "vmName"=$fileSrvName;
              "vmSize"=$fileSrvVmSize;
              "storageAccountType"=$fileSrvStorageAccountType;
              "resourceGroupVNet"=$VNetResourceGrp;
              "virtualNetworkName"=$virtualNetworkName;
              "subnetName"=$subnetName;
              "privNicIPAddress"=$fileSrvIPAddress;  
 #            "adminUsername"=$scaleSetVMCredentials.UserName;
 #            "adminPassword"=$scaleSetVMCredentials.GetNetworkCredential().Password
              "adminUsername"=$vmAdminCreds.UserName;
              "adminPassword"=$vmAdminCreds.GetNetworkCredential().Password;  
              }
#New-AzureRmResourceGroupDeployment -Name $rsgGrpDeployment -ResourceGroupName $destResourceGrp -TemplateFile $templateFile -TemplateParameterFile  $parametersFile -Verbose
New-AzureRmResourceGroupDeployment -Name $rsgGrpDeployment -ResourceGroupName $vmssResourceGrp -TemplateFile $templateFile -TemplateParameterObject $parameters  -Verbose

$TimeEnd = Get-Date -format HH:mm:ss
diffTime $TimeStart $TimeEnd
