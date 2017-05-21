$instanceNumber= 49
$vmSize='Standard_DS14_v2'
$location= 'northeurope'
$azureSubscName='YOUR_AZURE_SUBSCRIPTION_NAME'
###########################################################
###########################################################
$args01=@{
    'subscriptionName'=$azureSubscName;
    'location'=$location;
    'vmssResourceGrp'='RG-301';
    'scaleSetName'='azurD1401';
    'scaleSetVMSize'=$vmSize; 
    'newScaleSetCapacity'= $instanceNumber;
}
$args02=@{
    'subscriptionName'= $azureSubscName;
    'location'= $location;
    'vmssResourceGrp'='RG-302';
    'scaleSetName'='azurD1402';
    'scaleSetVMSize'= $vmSize; 
    'newScaleSetCapacity'= $instanceNumber;
}
$args03=@{
    'subscriptionName'= $azureSubscName;
    'location'= $location;
    'vmssResourceGrp'='RG-303';
    'scaleSetName'='azurD1403';
    'scaleSetVMSize'= $vmSize; 
    'newScaleSetCapacity'= $instanceNumber;
}
$args04=@{
    'subscriptionName'= $azureSubscName;
    'location'= $location;
    'vmssResourceGrp'='RG-304';
    'scaleSetName'='azurD1404';
    'scaleSetVMSize'=$vmSize; 
    'newScaleSetCapacity'=$instanceNumber;
}
$args05=@{
    'subscriptionName'= $azureSubscName;
    'location'= $location;
    'vmssResourceGrp'='RG-305';
    'scaleSetName'='azurD1405';
    'scaleSetVMSize'=$vmSize; 
    'newScaleSetCapacity'=$instanceNumber;
}
$args06=@{
    'subscriptionName'= $azureSubscName;
    'location'= $location;
    'vmssResourceGrp'='RG-306';
    'scaleSetName'='azurD1406';
    'scaleSetVMSize'= $vmSize; 
    'newScaleSetCapacity'=$instanceNumber;
}
$args07=@{
    'subscriptionName'= $azureSubscName;
    'location'= $location;
    'vmssResourceGrp'='RG-307';
    'scaleSetName'='azurD1407';
    'scaleSetVMSize'= $vmSize; 
    'newScaleSetCapacity'=$instanceNumber;
}
$args08=@{
    'subscriptionName'= $azureSubscName;
    'location'= $location;
    'vmssResourceGrp'='RG-308';
    'scaleSetName'='azurD1408';
    'scaleSetVMSize'=$vmSize; 
    'newScaleSetCapacity'=$instanceNumber;
}
$args09=@{
    'subscriptionName'= $azureSubscName;
    'location'= $location;
    'vmssResourceGrp'='RG-309';
    'scaleSetName'='azurD1409';
    'scaleSetVMSize'=$vmSize; 
    'newScaleSetCapacity'=$instanceNumber;
}
$args10=@{
    'subscriptionName'= $azureSubscName;
    'location'= $location;
    'vmssResourceGrp'='RG-310';
    'scaleSetName'='azurD1410';
    'scaleSetVMSize'= $vmSize; 
    'newScaleSetCapacity'=$instanceNumber;
}

$args11=@{
    'subscriptionName'= $azureSubscName;
    'location'= $location;
    'vmssResourceGrp'='RG-311';
    'scaleSetName'='azurD1411';
    'scaleSetVMSize'=$vmSize; 
    'newScaleSetCapacity'=$instanceNumber;
}



.\04_ScaleExisting_args.ps1 @args07

