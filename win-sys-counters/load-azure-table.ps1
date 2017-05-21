<#################################################################################
# Reference:
#   https://msdn.microsoft.com/en-us/library/microsoft.windowsazure.storage.table.entityproperty.aspx
#
#
#   Child function: GetStorageContext()   - get the storage context of Azure Storage account
#   Child function: DeleteTable()         - delete an Azure Table specified from the variable $table
#   Child function: AddTableEntries()     - add entry to the Azure Table
#   Child function: QueryTable()          - query the Azure table specified from the variable $table
#
# $hostname          : hostname to collect counters
# $folder            : folder where is stored the log file
# $choice            : it can take a set of alternative values: 'add', 'query', 'delete' 
# $k                 : it is an integer used to identify a single log file 
# $subscriptionName  : Azure subscription name
# $rsgGrpName        : name of the Azure Resource Group containing the Azure Storage Account
# $StorageAccountName: name of the Azure Storage Account define in the resource group
#
##################################################################################
#>
##################################################################################
##### INPUT VARIABLES:
#####    $hostname : string with name of the host
#####    $folder   : folder with logs files
$hostname = "h1"
$folder   = "C:\1\"
$k        = 0
#$choice   = 'add'
#$choice = 'query'
$choice = 'delete'

$subscriptionName   = "AZURE_SUBSCRITION_NAME"
$rsgGrpName         = "AZURE_RESOURCE_GROUP_NAME_CONTAINING_A_STORAGEACCOUNT"
$StorageAccountName = "AZURE_STORAGE_ACCOUNT_NAME"
##################################################################################



function GetStorageContext(){
    [CmdletBinding()]
    param( [String]$rsgGrpName,
           [String]$StorageAccountName)

    ######## Define the storage account and context.
    $StorageAccountKey = Get-AzureRmStorageAccountKey -ResourceGroupName $rsgGrpName -Name $StorageAccountName -Verbose
    $ctx = New-AzureStorageContext $StorageAccountName -StorageAccountKey $StorageAccountKey[$StorageAccountKey.KeyName.IndexOf("key1")].Value
    return $ctx
}


function DeleteTable() {
    [CmdletBinding()]
    param( [Microsoft.WindowsAzure.Commands.Common.Storage.AzureStorageContext]$ctx,
           [String]$TableName)
    
    $table = Get-AzureStorageTable -Name $TableName -Context $ctx -ErrorAction Ignore
    if ($table -ne $null)
    {
        Remove-AzureStorageTable –Name $TableName –Context $ctx
    }
}

function AddTableEntries(){
   [CmdletBinding()]
    param( [Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageBase]$table,
           [String]$File)

   ######## Create/Retrieve the table if it already exists.


   $data = Get-Content $File 
   write-host "total lines read from file:" $data.count 
   write-host "Azure Storage Table Name  :" $data.count
   foreach ($fileLine in $data)
   {
      write-host -ForegroundColor Cyan "value:" $fileLine
      $line=$fileLine.Split("`t")
      $sampleDatetime=[String]$line[0]
      $sysdate =[datetime]::ParseExact($line[0],'dd-MM-yyyy HH:mm:ss',[Globalization.CultureInfo]::InvariantCulture)
      $strcounterName=$line[1].replace(' ' , [String]::Empty).replace('%' , 'pct')
      $counterName=[System.Text.RegularExpressions.Regex]::Replace($strcounterName,"[^1-9a-zA-Z_]",[String]::Empty).ToLower()
      $counterValue=[System.Double]$line[2]


      if ($sysdate -eq $null)
      {
        write-out "Error in date converstion"
        Exit
      }
      write-host -ForegroundColor Yellow "value sample time:" $sampleDatetime
      write-host -ForegroundColor Yellow "value sys date   :" $sysdate
      write-host -ForegroundColor Yellow "counter Name     :" $counterName
      write-host -ForegroundColor Yellow "counter value    :" $counterValue

      $entity = New-Object -TypeName Microsoft.WindowsAzure.Storage.Table.DynamicTableEntity -ArgumentList $counterName, $sampleDatetime
      $entity.Properties.Add("sysTime", $sysdate)
      # 
      $entity.Properties.Add("counterValue", $counterValue) 
      $result = $table.CloudTable.Execute([Microsoft.WindowsAzure.Storage.Table.TableOperation]::Insert($entity))
 
   } 
}

function QueryTable()
{
    [CmdletBinding()]
    param( [Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageBase]$table)

    ######## Create a table query.
    $query = New-Object Microsoft.WindowsAzure.Storage.Table.TableQuery

    #Define columns to select.
    $list = New-Object System.Collections.Generic.List[string]
    $list.Add("PartitionKey")
    $list.Add("RowKey")
    $list.Add("sysTime")
    $list.Add("counterValue")

    #Set query details.
#    $query.FilterString = "counterValue gt 15"
    $query.FilterString = "sysTime gt datetime'2016-06-15T18:38:00'"
    $query.SelectColumns = $list
    $query.TakeCount = 50

    #Execute the query.
    $entities = $table.CloudTable.ExecuteQuery($query)

    $entities |Format-Table PartitionKey, @{ Label="sysTime"; Expression={$_.Properties["sysTime"].DateTime}}, @{ Label = "counterValue"; Expression={$_.Properties[“counterValue”].DoubleValue}} -AutoSize
}
function readTableNameFromFile(){
    param( [String]$File)
             
              $b=Test-Path $File
              if ($b -ne $true)
              {
                 Write-Output "file not found!"
                 Exit
              }
              ### Read the filename to acquired the hostname
              ### Read the first line of the file, to acquire the name of the windows counter
              $data = Get-Content $File -First 1
              write-host "Filename  :" $File
              write-host "First line:" $data
              $line=$data.Split("`t")

              ## get the name of the host from the file name
              ## get filename without extension
              $name=[System.IO.Path]::GetFileNameWithoutExtension($File)
              $pos = $name.IndexOf("-")
              if ($pos -gt 0)
              {
                   $hostname = $name.Substring(0, $pos)
                   write-host -ForegroundColor Yellow $pos
                   write-host -ForegroundColor Cyan "hostname:" $hostname
              }
              else
              { 
                   write-host -ForegroundColor Cyan "wrong file"
                   Exit
              }

              $strTableName = $hostname+$line[1].replace(' ' , [String]::Empty).replace('%' , 'pct')
              $TableName =[System.Text.RegularExpressions.Regex]::Replace($strTableName,"[^1-9a-zA-Z_]",[String]::Empty).ToLower(); 

              write-host -ForegroundColor Green "TableName:" $TableName
              return $TableName
}

##########  MAIN 

# Create an array of string $allFiles with the list of log files
$allFiles = @()
For ($i=0; $i -lt 22;$i++)
{
   $File=$folder+$hostName+"-"+$i.ToString("00")+".txt"
   $allFiles += ,@($File)
}
$File=$folder+$hostName+"-"+$k.ToString("00")+".txt"
#######################################################

######## Set the Azure subscription
Get-AzureRmSubscription -SubscriptionName $subscriptionName | Select-AzureRmSubscription 


######## Define the storage account and context.
$ctx = GetStorageContext $rsgGrpName $StorageAccountName

Switch($choice)
{
  'add'    {
              foreach ($singleFile in $allFiles)
              {
               $File=$singleFile.Item(0)
               # Name of the Azure Storage Table
               $TableName=readTableNameFromFile $File

               $table = Get-AzureStorageTable -Name $TableName -Context $ctx -ErrorAction Ignore
               if ($table -eq $null)
               {
                    $table = New-AzureStorageTable –Name $TableName -Context $ctx
               }
                    
               AddTableEntries $table $File; 
               
               }
               break;
           }
  'query'  {
               $TableName=readTableNameFromFile $File
               $table = Get-AzureStorageTable -Name $TableName -Context $ctx -ErrorAction Ignore
               if ($table -eq $null)
               {
                  Exit
               } 

               QueryTable $table; 
              break;
           }
  'delete' {
              $TableName=readTableNameFromFile $File
              DeleteTable $ctx $TableName;
              break;
           }

} ### end switch



