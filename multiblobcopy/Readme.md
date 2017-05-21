<properties
   pageTitle="powershell script to replicate the content in Azure storage accounts"
   description="powershell script to replicate the same blob in Azure storage accounts"
   services=""
   documentationCenter="na"
   authors="fabferri"
   manager=""
   editor=""/>

<tags
   ms.service="Configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="na"
   ms.date="25/11/2016"
   ms.author="fabferri" />

#  Powershell script to copy the same blob in multiple target storage accounts
###List of files:
* **01_deploy_StorageAccounts.ps1**: the script run the ARM template to create the new target storage accounts. you do not need to run this script if you already have the target storage account in the same Azure Resource Group.
* **02_multiBlobCopy.ps1**         : it is the main script to copy the source blob to multiple target storage accounts. The script uses jobs to copy the same .VHD from a source storage account to multiple destination storage accounts.
The target storage accounts are defined in the same Resource Group. The script runs a cascade algorithm to increase the efficiency of the copy operations. When a target storage account acquires the content (.VHD), it becomes itself a source storage account to copy to other target storage accounts that do not have yet the content. The copy operation from source storage account to destination storage account run through azcopy. To run the script, you need to have azcopy installed on your local host. The script makes leverage on jobs to scale up the process to multiple storage accounts.
* **03_RemoveBlobContainersTargetStorageAccounts.ps1**: powershell script to remove the container from target storage accounts
* **CreateStorageAccountStandard.json**: ARM template to create the new target storage account. The template is called in 01_deploy_StorageAccounts.ps1
* **CreateStorageAccountStandard-parameters.json**: ARM file with set of input parameters for CreateStorageAccountStandard.json
* **pseudoLog.txt** : pseudo log (useful to explain the workflow of the script)

###INPUT VARIABLES:
- **$subscription**: Azure subscription name where are store the Azure target storage accounts
- **$rgGroup**     : Azure Resource Group where are defined a list of Azure target storage accounts
- **$fileExe**     : location of azcopy binary in your local laptop/desktop; default value is "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"
- **$Pattern**     : name of azure blob (.VHD) in source storage account
- **$logFile**     : log file of powershell script, with sequence of actions run in the script
- **$sourceContainerName**: blob container name of source storage account
- **$destContainerName**  : blob container name of target storage account

###NOTE:
* the azcopy journaling file is located by default in the folder: **%LocalAppData%\Microsoft\Azure\AzCopy**
* the azcopy in the script create a journaling file in local directory where the script run. The journaling file is automatically deleted if the operation copy is completed successful. 

