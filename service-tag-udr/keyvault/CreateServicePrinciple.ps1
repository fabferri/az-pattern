##############################################
### Description:
###  *** Create an Azure Active Directory Application in the tenant associated with the subscription
###  *** Associate the AAD application the a Service principle
###  *** Associate a Network Contributor role to the Service Principle  
###
#################PARAMENTERS ##########################
$subscriptionName = "Pathfinders"          ### Select the Azure subscription
$FileName         = "data.txt"             ### File with output: Service Priciple Name, Application ID, 
$adAppDisplayName = "ffDemoApp1"           ### Display name of the AAD application
$role             = "Contributor"          ### Role assigned to the service principle
$rgName           = "fab-servicetag1"      ### Existing resource group
###########################################
$homePage = "http://" + $adAppDisplayName  ### homepage of the AAD application
$identifierUri = $homePage                 ### URI of the AAD application


$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id

$pathFiles=Split-Path -Parent $PSCommandPath
#
# Getting Subscription Id and Tenant ID
$subscId=$subscr.SubscriptionId
$tenatnId=$subscr.TenantId
write-host  "Subscription ID:" $subscId -ForegroundColor Cyan
write-host  "Tenant       ID:" $tenatnId -ForegroundColor Cyan

###
###
### Generate a randon password for the AAD application
Add-Type -Assembly System.Web
$password = [System.Web.Security.Membership]::GeneratePassword(16,3)
Write-Host -ForegroundColor Yellow "Service Priciple password:" $password

$SecureStringPassword = ConvertTo-SecureString -String $password -AsPlainText -Force

#Create a new AD Application
Write-Output "Creating a new Application in AAD (App URI - $identifierUri)" -Verbose
$azureAdApplication = New-AzADApplication -DisplayName $adAppDisplayName -HomePage $homePage -IdentifierUris $identifierUri -Password $SecureStringPassword -Verbose
$appId = $azureAdApplication.ApplicationId
Write-Output "Azure AAD Application creation completed successfully (Application Id: $appId)" -Verbose
Start-Sleep 20

### Create a service principal for your application.
### The unique application id for a service principal in a tenant. 
### Once created this property cannot be changed. 
### If an application id is not specified, one will be generated.
$spn = New-AzADServicePrincipal -ApplicationId $appId 

### Get information about the service principal
$svcPrincipal = Get-AzADApplication -DisplayNameStartWith $adAppDisplayName


Write-Host "applicationID: "$svcPrincipal.ApplicationId -foregroundcolor Green
Write-Host "DislayName   : "$svcPrincipal.DisplayName -foregroundcolor Green
Write-Host "ObjectId     : "$svcPrincipal.ObjectId -foregroundcolor Green


Write-Output "Waiting 30 sec for Service Priciple creation to reflect in Azure Active Directory before Role assignment"
Start-Sleep 30


### Assing a role specificed in the variable $role to the service priciple 
New-AzRoleAssignment  -ServicePrincipalName $svcPrincipal.ApplicationId -RoleDefinitionName $role -ResourceGroupName $rgName

### scope the specific subscription
$scopeSubsc="/subscriptions/"+$subscr.Id
#### Get the Object ID associated with the role assigned to the service priciple
$roleObjId= Get-AzRoleAssignment -Scope $scopeSubsc -RoleDefinitionName $role 

$roleObjId.GetEnumerator() |  where {$_.DisplayName -eq $adAppDisplayName} 


#### Remove the role associated with the Service Principle 
#Remove-AzRoleAssignment -ObjectId $roleObjId.ObjectId -RoleDefinitionName $role

$str01= "SubscriptionID: "+$subscId
$str02= "TenantID      : "+$tenatnId
$str03= "============================================"
$str04= "applicationID (SrvPriciple Id): "+ $svcPrincipal.ApplicationId
$str05= "DislayName                    : "+ $svcPrincipal.DisplayName
$str06= "ObjectId                      : "+ $svcPrincipal.ObjectId
$str07= "Password SrvPrinciple         : "+ $password
$str08= "============================================"
$str09= "Role assignment" 
$str10= "RoleAssignmentId   : " + $roleObjId.RoleAssignmentId
$str11= "Scope              : " + $roleObjId.Scope
$str12= "DisplayName        : " + $roleObjId.DisplayName
$str13= "SignInName         : " + $roleObjId.SignInName
$str14= "RoleDefinitionName : " + $roleObjId.RoleDefinitionName
$str15= "RoleDefinitionId   : " + $roleObjId.RoleDefinitionId
$str16= "ObjectId           : " + $roleObjId.ObjectId
$str17= "ObjectType         : " + $roleObjId.ObjectType

Out-File -FilePath "$pathFiles\$FileName" -InputObject "" -Encoding ASCII 
Out-File -FilePath "$pathFiles\$FileName" -InputObject $str01 -Encoding ASCII -Append
Out-File -FilePath "$pathFiles\$FileName" -InputObject $str02 -Encoding ASCII -Append
Out-File -FilePath "$pathFiles\$FileName" -InputObject $str03 -Encoding ASCII -Append
Out-File -FilePath "$pathFiles\$FileName" -InputObject $str04 -Encoding ASCII -Append
Out-File -FilePath "$pathFiles\$FileName" -InputObject $str05 -Encoding ASCII -Append
Out-File -FilePath "$pathFiles\$FileName" -InputObject $str06 -Encoding ASCII -Append
Out-File -FilePath "$pathFiles\$FileName" -InputObject $str07 -Encoding ASCII -Append
Out-File -FilePath "$pathFiles\$FileName" -InputObject $str08 -Encoding ASCII -Append
Out-File -FilePath "$pathFiles\$FileName" -InputObject $str09 -Encoding ASCII -Append
Out-File -FilePath "$pathFiles\$FileName" -InputObject $str10 -Encoding ASCII -Append
Out-File -FilePath "$pathFiles\$FileName" -InputObject $str11 -Encoding ASCII -Append
Out-File -FilePath "$pathFiles\$FileName" -InputObject $str12 -Encoding ASCII -Append
Out-File -FilePath "$pathFiles\$FileName" -InputObject $str13 -Encoding ASCII -Append
Out-File -FilePath "$pathFiles\$FileName" -InputObject $str14 -Encoding ASCII -Append
Out-File -FilePath "$pathFiles\$FileName" -InputObject $str15 -Encoding ASCII -Append
Out-File -FilePath "$pathFiles\$FileName" -InputObject $str16 -Encoding ASCII -Append
Out-File -FilePath "$pathFiles\$FileName" -InputObject $str17 -Encoding ASCII -Append

Exit
### Deletes the azure active directory application.
## Remove-AzADApplication -ObjectId $s.ObjectId -Force -Verbose 


#### Updates the properties of an existing azure active directory application with objectId 
## Set-AzADApplication -ObjectId <ObjectID> -DisplayName "UpdatedAppName" -HomePage "http://www.microsoft.com" -IdentifierUris "http://UpdatedApp" -AvailableToOtherTenants $false

