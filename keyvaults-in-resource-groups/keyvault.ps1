### Run keyvault.ps1 with two numbers:
### the first number is the start-pod-Id 
### the second number is the end-pod-Id
###
### i.e. to create keyvaults for the pod from 20 to 30 use the command:
### keyvault.ps1 20 30
###
### To create the keyvault for a single pod use the same number two times:
### keyvault.ps1 20 20
###
[CmdletBinding()]
param (
    [Parameter(ValueFromPipeline=$true, HelpMessage='Enter start pod ID', Mandatory=$true)]
    [ValidateRange(10,99)]
    [int]$podId_Start,
    [Parameter(ValueFromPipeline=$true, HelpMessage='Enter end pod ID', Mandatory=$true)]
    [ValidateRange(10,99)]
    [int]$podId_End,
    [switch]$DeleteEnvironment=$false)

$subscriptionName='AzDev'
$objectId ='GEN-AZUREAD-OBJECTID'
$location = 'westus2'

$pathDir = Split-Path -Parent $PSCommandPath
$armTemplateFile = 'keyvault.json'
$templateFile = "$pathDir\$armTemplateFile"

if ($podId_Start -gt  $podId_End) 
{
   Write-Host "start input parameter $podId_Start cannot be highter then end input parameter $podId_End"
   Exit
}

function LabCreate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline=$true, HelpMessage='Enter pod ID')]
        [int]$podIdStart,
        [Parameter(Mandatory = $true, ValueFromPipeline=$true, HelpMessage='Enter pod ID')]
        [int]$podIdEnd)
 
    # 1. Initialize
    # 2. Create Resource group, Key Vault, Secret, and set permissions through ARM template

    # 1. Initialize
    $StartTime = Get-Date

    $RegEx='^(?=\P{Ll}*\p{Ll})(?=\P{Lu}*\p{Lu})(?=\P{N}*\p{N})(?=[\p{L}\p{N}]*[^\p{L}\p{N}])[\s\S]{12,}$'

    # VM User 1, VM User 2, VM User 3
    $User01Name = 'User01'
    $User02Name = 'User02'
    $User03Name = 'User03'
    
    # initialize  an array to store the user's password
    $arrayPass = @()
    ## each compnay has three users, then are required a number of passwords equal to three times the number companies
    $numElements= 3*(($podIdEnd-$podIdStart)+1)

    # write the password in a file. 
    # This is not essential; remove this section if you do not want to keep the password in a file
    $fileName='password.txt'
    if (Test-Path "$pathDir\$fileName") {
          Remove-Item "$pathDir\$fileName"
    }

    foreach ($i in 1..$numElements)
    {
       Do {$UserPass = ([char[]](Get-Random -Input $(40..44 + 46..59 + 63..91 + 95..122) -Count 20)) -join ""}
       While ($UserPass -cnotmatch $RegEx)
       $UserSecPass = ConvertTo-SecureString $UserPass -AsPlainText -Force
       $arrayPass += $UserPass

       # write the password in a file. Remove this line if you do not want it
       Out-File -FilePath "$pathDir\$fileName" -Encoding  utf8 -Append -inputobject $UserPass
    }
    
    # 2. Create Key Vault, Secret, and set permissions
    $rgDeployment='podGen'

    $parameters=@{
              "podIdStart"   = $podIdStart;
              "podIdEnd"     = $podIdEnd;
              "location"     = $location;
              "objectId"     = $objectId;
              "secretName1"  = $User01Name;
              "secretName2"  = $User02Name;
              "secretName3"  = $User03Name;
              "arraySecrets" = [array]$arrayPass
              }

     Write-Host "podId_Start:"$podId_Start
     Write-Host "podId_End  :"$podId_End

     Write-Host (Get-Date)' - ' -NoNewline -ForegroundColor Yellow
     Write-Host "running ARM template:"$templateFile -ForegroundColor Yellow
     New-AzDeployment -Name $rgDeployment -TemplateFile $templateFile -TemplateParameterObject $parameters -Location $location
    

    # End nicely
    $EndTime = Get-Date
    $TimeDiff = New-TimeSpan $StartTime $EndTime
    $Mins = $TimeDiff.Minutes
    $Secs = $TimeDiff.Seconds
    $RunTime = '{0:00}:{1:00} (M:S)' -f $Mins,$Secs
    Write-Host (Get-Date)' - ' -NoNewline
    Write-Host "Companies $podId_Start-$podId_End completed successfully" -ForegroundColor Green
    Write-Host "Time to create: $RunTime"
    Write-Host
}


# Login and permissions check
Write-Host (Get-Date)' - ' -NoNewline
Write-Host "Checking login and permissions" -ForegroundColor Cyan

# Login and set subscription for ARM
$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id
Try {$Sub = (Set-AzContext -Subscription $subscr.Id -ErrorAction Stop).Subscription}
Catch {Write-Host "Logging in to ARM"
       Connect-AzAccount | Out-Null
       $Sub = (Set-AzContext -Subscription $subscr.Id -ErrorAction Stop).Subscription}
If ($subscr.Id -ne $Sub.Id) {Write-Warning "Logging in or setting context on subscription failed, please troubleshoot and retry."
                         Return}
Else {Write-Host "Current Sub:",$Sub.Name,"(",$Sub.Id,")"}

LabCreate -podIdStart $podID_Start -podIdEnd $podID_End
