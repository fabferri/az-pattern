###
###
$args01=@{
    'subscriptionName'='YOUR_AZURE_SUBSCRIPTION_NAME';
    'location'='northeurope';
    'VNetResourceGrp'='VNetsRG';
    'virtualNetworkName'='VNet01';
    'subnetName'='Subnet1';
    'vmssResourceGrp'='RG-301';
    'scaleSetName'='azurD1401';
    'scaleSetVMSize'='Standard_DS14_v2'; 
    'storageAccountTypeScaleSet'='Premium_LRS';   
    'scaleSetInstanceCount'= 49; 
    'adminUser' = 'ADMINISTRATOR_USERNAME'; 
    'adminPwd'  = 'ADMINISTRATOR_PASSWORD';
    'fileSrvIPAddress' = '10.217.48.254';   
    'fileSrvName' = 'fsvnet01';
    'fileSrvVmSize' = 'Standard_DS1_V2'; 
    'fileSrvStorageAccountType' = 'Premium_LRS'
}
#
$args02=@{
    'subscriptionName'='YOUR_AZURE_SUBSCRIPTION_NAME';
    'location'='northeurope';
    'VNetResourceGrp'='VNetsRG';
    'virtualNetworkName'='VNet02';
    'subnetName'='Subnet1';
    'vmssResourceGrp'='RG-302';
    'scaleSetName'='azurD1402';
    'scaleSetVMSize'='Standard_DS14_v2'; 
    'storageAccountTypeScaleSet'='Premium_LRS';   
    'scaleSetInstanceCount'= 49; 
    'adminUser' = 'ADMINISTRATOR_USERNAME'; 
    'adminPwd'  = 'ADMINISTRATOR_PASSWORD';
    'fileSrvIPAddress' = '10.217.49.254';   
    'fileSrvName' = 'fsvnet02';
    'fileSrvVmSize' = 'Standard_DS1_V2'; 
    'fileSrvStorageAccountType' = 'Premium_LRS'
}
#
$args03=@{
    'subscriptionName'='YOUR_AZURE_SUBSCRIPTION_NAME';
    'location'='northeurope';
    'VNetResourceGrp'='VNetsRG';
    'virtualNetworkName'='VNet03';
    'subnetName'='Subnet1';
    'vmssResourceGrp'='RG-303';
    'scaleSetName'='azurD1403';
    'scaleSetVMSize'='Standard_DS14_v2'; 
    'storageAccountTypeScaleSet'='Premium_LRS';   
    'scaleSetInstanceCount'= 49; 
    'adminUser' = 'ADMINISTRATOR_USERNAME'; 
    'adminPwd'  = 'ADMINISTRATOR_PASSWORD';
    'fileSrvIPAddress' = '10.217.50.254';   
    'fileSrvName' = 'fsvnet03';
    'fileSrvVmSize' = 'Standard_DS1_V2'; 
    'fileSrvStorageAccountType' = 'Premium_LRS'
}
#
$args04=@{
    'subscriptionName'='YOUR_AZURE_SUBSCRIPTION_NAME';
    'location'='northeurope';
    'VNetResourceGrp'='VNetsRG';
    'virtualNetworkName'='VNet04';
    'subnetName'='Subnet1';
    'vmssResourceGrp'='RG-304';
    'scaleSetName'='azurD1404';
    'scaleSetVMSize'='Standard_DS14_v2'; 
    'storageAccountTypeScaleSet'='Premium_LRS';   
    'scaleSetInstanceCount'= 49; 
    'adminUser' = 'ADMINISTRATOR_USERNAME'; 
    'adminPwd'  = 'ADMINISTRATOR_PASSWORD';
    'fileSrvIPAddress' = '10.217.51.254';   
    'fileSrvName' = 'fsvnet04';
    'fileSrvVmSize' = 'Standard_DS1_V2'; 
    'fileSrvStorageAccountType' = 'Premium_LRS'
}
#
$args05=@{
    'subscriptionName'='YOUR_AZURE_SUBSCRIPTION_NAME';
    'location'='northeurope';
    'VNetResourceGrp'='VNetsRG';
    'virtualNetworkName'='VNet05';
    'subnetName'='Subnet1';
    'vmssResourceGrp'='RG-305';
    'scaleSetName'='azurD1405';
    'scaleSetVMSize'='Standard_DS14_v2'; 
    'storageAccountTypeScaleSet'='Premium_LRS';   
    'scaleSetInstanceCount'= 49; 
    'adminUser' = 'ADMINISTRATOR_USERNAME'; 
    'adminPwd'  = 'ADMINISTRATOR_PASSWORD';
    'fileSrvIPAddress' = '10.217.52.254';   
    'fileSrvName' = 'fsvnet05';
    'fileSrvVmSize' = 'Standard_DS1_V2'; 
    'fileSrvStorageAccountType' = 'Premium_LRS'
}
#
$args06=@{
    'subscriptionName'='YOUR_AZURE_SUBSCRIPTION_NAME';
    'location'='northeurope';
    'VNetResourceGrp'='VNetsRG';
    'virtualNetworkName'='VNet06';
    'subnetName'='Subnet1';
    'vmssResourceGrp'='RG-306';
    'scaleSetName'='azurD1406';
    'scaleSetVMSize'='Standard_DS14_v2'; 
    'storageAccountTypeScaleSet'='Premium_LRS';   
    'scaleSetInstanceCount'= 49; 
    'adminUser' = 'ADMINISTRATOR_USERNAME'; 
    'adminPwd'  = 'ADMINISTRATOR_PASSWORD';
    'fileSrvIPAddress' = '10.217.53.254';   
    'fileSrvName' = 'fsvnet06';
    'fileSrvVmSize' = 'Standard_DS1_V2'; 
    'fileSrvStorageAccountType' = 'Premium_LRS'
}
#
$args07=@{
    'subscriptionName'='YOUR_AZURE_SUBSCRIPTION_NAME';
    'location'='northeurope';
    'VNetResourceGrp'='VNetsRG';
    'virtualNetworkName'='VNet07';
    'subnetName'='Subnet1';
    'vmssResourceGrp'='RG-307';
    'scaleSetName'='azurD1407';
    'scaleSetVMSize'='Standard_DS14_v2'; 
    'storageAccountTypeScaleSet'='Premium_LRS';   
    'scaleSetInstanceCount'= 49; 
    'adminUser' = 'ADMINISTRATOR_USERNAME'; 
    'adminPwd'  = 'ADMINISTRATOR_PASSWORD';
    'fileSrvIPAddress' = '10.217.54.254';   
    'fileSrvName' = 'fsvnet07';
    'fileSrvVmSize' = 'Standard_DS1_V2'; 
    'fileSrvStorageAccountType' = 'Premium_LRS'
}
#
$args08=@{
    'subscriptionName'='YOUR_AZURE_SUBSCRIPTION_NAME';
    'location'='northeurope';
    'VNetResourceGrp'='VNetsRG';
    'virtualNetworkName'='VNet08';
    'subnetName'='Subnet1';
    'vmssResourceGrp'='RG-308';
    'scaleSetName'='azurD1408';
    'scaleSetVMSize'='Standard_DS14_v2'; 
    'storageAccountTypeScaleSet'='Premium_LRS';   
    'scaleSetInstanceCount'= 49; 
    'adminUser' = 'ADMINISTRATOR_USERNAME'; 
    'adminPwd'  = 'ADMINISTRATOR_PASSWORD';
    'fileSrvIPAddress' = '10.217.56.254';   
    'fileSrvName' = 'fsvnet08';
    'fileSrvVmSize' = 'Standard_DS1_V2'; 
    'fileSrvStorageAccountType' = 'Premium_LRS'
}
#
$args09=@{
    'subscriptionName'='YOUR_AZURE_SUBSCRIPTION_NAME';
    'location'='northeurope';
    'VNetResourceGrp'='VNetsRG';
    'virtualNetworkName'='VNet09';
    'subnetName'='Subnet1';
    'vmssResourceGrp'='RG-309';
    'scaleSetName'='azurD1409';
    'scaleSetVMSize'='Standard_DS14_v2'; 
    'storageAccountTypeScaleSet'='Premium_LRS';   
    'scaleSetInstanceCount'= 49; 
    'adminUser' = 'ADMINISTRATOR_USERNAME'; 
    'adminPwd'  = 'ADMINISTRATOR_PASSWORD';
    'fileSrvIPAddress' = '10.217.57.254';   
    'fileSrvName' = 'fsvnet09';
    'fileSrvVmSize' = 'Standard_DS1_V2'; 
    'fileSrvStorageAccountType' = 'Premium_LRS'
}
#
$args10=@{
    'subscriptionName'='YOUR_AZURE_SUBSCRIPTION_NAME';
    'location'='northeurope';
    'VNetResourceGrp'='VNetsRG';
    'virtualNetworkName'='VNet10';
    'subnetName'='Subnet1';
    'vmssResourceGrp'='RG-310';
    'scaleSetName'='azurD1410';
    'scaleSetVMSize'='Standard_DS14_v2'; 
    'storageAccountTypeScaleSet'='Premium_LRS';   
    'scaleSetInstanceCount'= 49; 
    'adminUser' = 'ADMINISTRATOR_USERNAME'; 
    'adminPwd'  = 'ADMINISTRATOR_PASSWORD';
    'fileSrvIPAddress' = '10.217.58.254';   
    'fileSrvName' = 'fsvnet10';
    'fileSrvVmSize' = 'Standard_DS1_V2'; 
    'fileSrvStorageAccountType' = 'Premium_LRS'
}
$args11=@{
    'subscriptionName'='YOUR_AZURE_SUBSCRIPTION_NAME';
    'location'='northeurope';
    'VNetResourceGrp'='VNetsRG';
    'virtualNetworkName'='VNet11';
    'subnetName'='Subnet1';
    'vmssResourceGrp'='RG-311';
    'scaleSetName'='azurD1411';
    'scaleSetVMSize'='Standard_DS14_v2'; 
    'storageAccountTypeScaleSet'='Premium_LRS';   
    'scaleSetInstanceCount'= 49; 
    'adminUser' = 'ADMINISTRATOR_USERNAME'; 
    'adminPwd'  = 'ADMINISTRATOR_PASSWORD';
    'fileSrvIPAddress' = '10.217.59.254';   
    'fileSrvName' = 'fsvnet11';
    'fileSrvVmSize' = 'Standard_DS1_V2'; 
    'fileSrvStorageAccountType' = 'Premium_LRS'
}
#### Run Deployment in VNet01
.\02_DeployFS_args.ps1 @args01
.\03_DeployVMSS_args.ps1 @args01

#### Run Deployment in VNet02
.\02_DeployFS_args.ps1 @args02
.\03_DeployVMSS_args.ps1 @args02

