<#
Description:
   the script use powershell jobs to copy the same .VHD from a source storage account to multiple destination storage accounts.
   Teh target storage accounts are defined in the same Resource Group.
   The powershell script use a cascade algorith to increase the efficiency of the copy operations. 
   the mechanims is based on the fact that when a Target Storage account have acquired the content (.VHD),
   it becomes itself a source storage account to copy to other target storage accounts that do not have yet the content.
   the copy operation from source storage account to destination storage account run through azcopy.
   to run the script you need to have azcopy installed on your local host.

   The script use powershell jobs and scale up to multiple storage accounts

INPUT VARIABLES:
    $subscription: Azure subscription name where are store the Azure target storage accounts
    $rgGroup     : Azure Resource Group where are defined a list of Azure target storage accounts
    $fileExe     : location of azcopy binary in your local laptop/desktop; default vaule is "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"
    $Pattern     : name of azure blob (.VHD) in source storage account
    $logFile     : log file of powershell script, with sequence of actions run in the script
    $sourceContainerName: blob container name of source storage account
    $destContainerName  : blob container name of target storage account
NOTE:
    the azcopy journaling file is located by default in the folder: %LocalAppData%\Microsoft\Azure\AzCopy
    the sazcopy in the script create a local journaling file in local directory where the script run. 
    The journaling file is automatically deleted if the operation copy is completed successful. 

#>

##### Input parameters ###############################################
$subscription        = "AZURE_SUBSCRITIONNAME_TARGET_STORAGE_ACCOUNT"
$rgGroup             = "RESOURCE_GROUP_TARGET_STORAGE_ACCOUNT"
$sourceAccountName   = "SOURCE_STORAGE_ACCOUNT_NAME"
$sourceAccountKey    = "SOURCE_STORAGE_ACCOUNT_KEY"
$Pattern             = "samplevhd101.vhd"
$sourceContainerName = "vhds"
$destContainerName   = "vhds"
######################################################################

# define empty arrays
[System.Collections.ArrayList]$targetStorage=@()     ## List of storage account without content
[System.Collections.ArrayList]$sourceStorage=@()     ## List of storage account with content available to be copied
[System.Collections.ArrayList]$deststorage=@()       ## List of storage account with content

$sourceStorage += ,@($sourceAccountName,$sourceAccountKey)
$fileExe        = "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy.exe"


$pathFiles = Split-Path -Parent $PSCommandPath
$time=(Get-Date -format yyyyMMddHHmmss).ToString()
$logFile = "$pathFiles\"+$time+"-OutputLog.txt"



function writeLog
{
    param([Parameter(Mandatory=$true)] [System.String]$str)
    $time=(Get-Date -format yyyy-MM-dd:HH:mm:ss).ToString()
    $str=$time+$str
    write-host -foregroundcolor Cyan $str
    Out-File -FilePath $Global:logfile -Encoding  utf8 -Append -inputobject $str;
}

function logJobStart
{
      param([Parameter(Mandatory=$true)] [System.Collections.ArrayList]$source,
            [Parameter(Mandatory=$true)] [System.Collections.ArrayList]$destination)

      $str = "#### START A NEW COPY ###################################"
      writeLog $str
      
      $str = "#### job: " + $singleJob.Name
      writeLog $str

      $str= "#### Source Storage-name     :" +$source[0]
      writeLog $str

      $str= "#### Source Storage-key      :" +$source[1]
      writeLog $str

      $str= "#### Destination Storage-name:" +$destination[0] 
      writeLog $str

      $str= "#### Destination Storage-key :" +$destination[1]
      writeLog $str

      $str= " " 
      writeLog $str

}

function logJobTracking
{
    param([Parameter(Mandatory=$true)] [System.Collections.ArrayList]$j)
       $str = "+++++++++ Job tracking"
       writeLog $str
       $str="++++ JobID:"+ $j[0].Id +" ¦ "+ "JobName:" +$j[0].Name+ " ¦ "+ "JobState: " +$j[0].State
       writeLog $str

       $str="+++++++++ JobList value1:" + $j[1]
       writeLog $str

       $str="+++++++++ JobList value2:" + $j[2]
       writeLog $str
       $str="++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
       writeLog $str
}

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

function statusJobs
{
    param(  [Parameter(Mandatory=$true)] [System.Collections.ArrayList]$Jobs )

     $str="----- JOB STATUS -----------------------------------------"
     writeLog $str

     $numRunningJob=0
     ForEach ($j in $Jobs)
     {
      try {
          if ($j.State -eq "Completed") 
          {             
             $str="-----JobID:"+[string]$j.Id +"¦" +"JobName:" +$j.Name +"¦" +"JobState: " +$j.State
             writeLog $str
          }
          if ($j.State -eq "Running") 
          {
             $numRunningJob++
             $str = "-----JobID:"+[string]$j.Id +"¦" +"JobName:"+ $j.Name +"¦" +"JobState: "+ $j.State
             writeLog $str
          }
          if ($j[0].State -eq "Failed") 
          {              
               $str=$j[0].ChildJobs[0].JobStateInfo.Reason
               writeLog $str
          }
          }
          catch {
               $ErrorMessage = $_.Exception.Message
               $FailedItem = $_.Exception.ItemName
               write-host "Error Message:" $ErrorMessage
               write-host "Failed Item  :" $FailedItem
               write-host "catch error-sleep 3 sec"
               Start-Sleep -Seconds 3
               Continue
               }
     }
     $str="----------------------------------------------------------"
     writeLog $str
     return $numRunningJob
}


function submitNewJob 
{
    param(  [Parameter(Mandatory=$true)] [System.Collections.ArrayList]$sourStorage,
            [Parameter(Mandatory=$true)] [System.Collections.ArrayList]$targStorage,
            [Parameter(Mandatory=$true)] [System.String]$fileExe,
            [Parameter(Mandatory=$true)] [System.String]$sourceContainerName,
            [Parameter(Mandatory=$true)] [System.String]$destContainerName,
            [Parameter(Mandatory=$true)] [System.String]$Pattern)
      
      $list  = @($sourStorage[0],$sourStorage[1],$targStorage[0], $targStorage[1])
      $pathFiles = Split-Path -Parent $PSCommandPath 
      $time=(Get-Date -format yyyyMMddHHmmss).ToString()
      $journalFolder = $pathFiles+"\"+$time+"-job"+"\"

      $str=" "
      Write-host $str
            
      $str="================================== SUBMIT JOB =================================="
      Write-host $str

      $str="-----inside submit job-source    :" + $sourStorage[0]
      Write-host $str

      $str="-----inside submit job-sourcekey :" + $sourStorage[1]
      Write-host $str

      $str="-----inside submit job-target    :" + $targStorage[0]
      Write-host $str

      $str="-----inside submit job-targetKey :" + $targStorage[1]
      Write-host $str

      $singleJob=Start-Job -ScriptBlock { 
          param ( [String[]] $list, $fileExe, $sourceContainerName, $destContainerName, $Pattern, $journalFolder )
          $list | % { $_ }

          $source   = $list[0]
          $sourceKey= $list[1]
          $dest     = $list[2]
          $destkey  = $list[3]
          # 
          Write-host ">>>> source         :" $source
          Write-host ">>>> sourcekey      :" $sourceKey
          Write-host ">>>> dest           :" $dest
          Write-host ">>>> destkey        :" $destkey
          write-host ">>>> sourceContainer:" $sourceContainerName
          write-host ">>>> destContainer  :" $destContainerName
          
 
          $Pattern="`""+$Pattern+"`""
          $sourceAz= "https://"+$source+".blob.core.windows.net/"+$sourceContainerName
          $destAz  = "https://"+$dest+".blob.core.windows.net/"+$destContainerName
          $cmd     = " /source:$sourceAz /Dest:$destAz /SourceKey:$sourceKey /DestKey:$destkey /Pattern:$Pattern /Z:$journalFolder"
          Write-host ">>>> sourceAz     : " $sourceAz
          Write-host ">>>> destAz       : " $destAz
          Write-host ">>>> azcommand    : " $cmd
          Write-host ">>>> fileexec     : " $fileExe
          Write-host ">>>> pattern      : " $Pattern
          Write-host ">>>> journalfolder: " $journalFolder

#          & $fileExe /source:$sourceAz  /Dest:$destAz  /SourceKey:$sourceKey /DestKey:$destkey /Pattern:$Pattern 
          & $fileExe /source:$sourceAz  /Dest:$destAz  /SourceKey:$sourceKey /DestKey:$destkey /Pattern:$Pattern /Y /Z:$journalFolder
          Write-host "--------------------------------------------------------------------"
      } -ArgumentList ($list, $fileExe, $sourceContainerName, $destContainerName, $Pattern, $journalFolder) 
      return $singleJob
}




function GetListStorageAccounts 
{
    param(  [Parameter(Mandatory=$true)] [System.String]$subscriptiom,
            [Parameter(Mandatory=$true)] [System.String]$rg)
       
    Get-AzureRmSubscription -SubscriptionName $subscriptiom |Select-AzureRmSubscription
    $StorageAccountList=Get-AzureRmStorageAccount -ResourceGroupName $rg
    foreach ($StorageAccount in $StorageAccountList) { 
         $StorageAccountName = $StorageAccount.StorageAccountName
         $StorageAccountKey = Get-AzureRmStorageAccountKey -ResourceGroupName $rg -Name $StorageAccountName  
        
         write-host -foregroundcolor yellow "dest-Name:" $StorageAccountName
         write-host -foregroundcolor Green  "dest-Key:"  $StorageAccountKey[$StorageAccountKey.KeyName.IndexOf("key1")].Value

         $storageList          += ,@($StorageAccountName, $StorageAccountKey[$StorageAccountKey.KeyName.IndexOf("key1")].Value)
         $global:targetStorage += ,@($StorageAccountName, $StorageAccountKey[$StorageAccountKey.KeyName.IndexOf("key1")].Value)
         $global:deststorage   += ,@($StorageAccountName, $StorageAccountKey[$StorageAccountKey.KeyName.IndexOf("key1")].Value)
        }
}


function JobControl 
{
    param(  [Parameter(Mandatory=$true)] [System.Collections.ArrayList]$sourceStorage,
            [Parameter(Mandatory=$true)] [System.Collections.ArrayList]$targetStorage,
            [Parameter(Mandatory=$true)] [System.String]$fileExe,
            [Parameter(Mandatory=$true)] [System.String]$sourceContainerName,
            [Parameter(Mandatory=$true)] [System.String]$destContainerName,
            [Parameter(Mandatory=$true)] [System.String]$Pattern)


  [System.Collections.ArrayList]$currentStorage=@()
  [System.Collections.ArrayList]$Jobs = @()
  $numRunningJob=0


  While ($targetStorage.count -gt 0) 
  {
     if (($sourceStorage.count -gt 0) -and ($targetStorage.Count -gt 0))
     {
        $singleJob= submitNewJob $sourceStorage[0] $targetStorage[0] $fileExe $sourceContainerName $destContainerName $Pattern

        $currentStorage += ,@($singleJob,$sourceStorage[0],$targetStorage[0])
        $Jobs += @($singleJob)      

        logJobStart $sourceStorage[0] $targetStorage[0]
      
        $targetStorage.Removeat(0)
        $sourceStorage.RemoveAt(0)  
     }

     $numRunningJob= statusJobs $Jobs

     $str="-----TOTAL NUMBER OF RUNNING JOBS:" +$numRunningJob.ToString()
     writeLog $str

     for ($i=0; $i -lt $currentStorage.Count; $i++)
     {
       $j=$currentStorage[$i]

       try {
              if ($j[0].State -eq "Completed" ) 
              {
                  $sourceStorage.Add($j[1])
                  $sourceStorage.Add($j[2])
                  $index = $currentStorage.IndexOf($j)
                  $currentStorage.RemoveAt($index)
                  $i=$i-1
                  
                  logJobTracking $j
              }

              if ($j[0].State -eq "Running") 
              {
                  
                  logJobTracking $j
              }
              if ($j[0].State -eq "Failed") 
              {
                  $str ="+++++++++++++++++++++++ Job tracking"
                  writeLog $str
                  $str = "job in failure-Reson:"+$j[0].ChildJobs[0].JobStateInfo.Reason
                  writeLog $str
              }
            }
        catch {
                 $ErrorMessage = $_.Exception.Message
                 $FailedItem = $_.Exception.ItemName
                 write-host "Error Message:" $ErrorMessage
                 write-host "Failed Item  :" $FailedItem
                 write-host "catch error-sleep 3 sec"
                 Start-Sleep -Seconds 3
                 Continue
              }   
     }
     start-sleep -Seconds 5
  }

  
 Do {
       $numRunningJob= statusJobs $Jobs
       start-sleep -Seconds 5
    } while ($numRunningJob -ge 1)

  foreach($job in $Jobs){
    Receive-Job -Name $job.Name | Out-File $logFile -Encoding  utf8 -Append 
  }
  start-sleep -Seconds 5
#  $Jobs | Remove-Job -Force
  return $Jobs
}

###################################### MAIN program ######################################

GetListStorageAccounts $subscription $rgGroup 

$str = "========================= List of destination Storage account ========================="
writeLog  $str
ForEach ($k in $targetStorage)
{  
    $str="  ---> destination storage: "+$k[0].ToString() +" - "+ $k[1].ToString()
    writeLog $str   
}
$str = "======================================================================================="
writeLog  $str

$Jobs = @()
$TimeStart = Get-Date -format HH:mm:ss
$Jobs = JobControl $sourceStorage $targetStorage $fileExe $sourceContainerName $destContainerName $Pattern


$str= " _____________________________________________________________________"
writeLog $str
$str= "|--------------------- Copy operation completed ----------------------|"
writeLog $str
$str= " _____________________________________________________________________"
writeLog $str


$TimeEnd = Get-Date -format HH:mm:ss
diffTime $TimeStart $TimeEnd
