<properties
pageTitle= 'Azure NetApp Files service'
description= "Azure NetApp Files service"
documentationcenter: na
services=""
documentationCenter="github"
authors="fabferri"
manager=""
editor=""/>

<tags
   ms.service="howto-Azure-examples"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="na"
   ms.workload="NetApp"
   ms.date="22/09/2022"
   ms.review=""
   ms.author="fabferri" />

# Azure NetApp Files service
The article describes a scenario with Azure NetApp Files service configured with a NFS volumes (NFS stands for **N**ew **F**ile **S**ystem).
An Azure Netapp Files storage account is deployed in a Resource Group and attached to a vnet.<br>
Inside the Netapp Files storage account are created NFS volumes in a dedicate subnet. Each Volumes takes the first available IP address of the NetApp subnet. <br>
Below the network diagram:

[![1]][1]

* the vnet1 is configured with three subnets: appsubnet, afnsubnet, AzureBastionSubnet, AzureFirewallSubnet
* vnet1 and vnet2 are in peering
* UDRs are set in appsubnets and afnsubnet to force the NFS traffic to transit through the Azure firewall
* each Ubuntu VM mounts automatically the volumes through cloud-init
* the windows VM need to mount the NFS volume manually 
* anfSubnet must have a **'Microsoft.NetApp/volumes'** delegation:
  ```json
  "delegations": [
      {
        "name": "NetAppDelegation",
        "properties": {
            "serviceName": "Microsoft.NetApp/volumes"
        }
      }
    ]
  ```
* the ARM template create a log analytics in the same region of the vnets and define the Azure firewall diagnostics logs to be sent to the log analytics  

Azure NetApp File has a storage hierarchy:

 [![2]][2]

Inside an Azure subscription you can define an Azure Netapp Account stored within a region. Underneath a NetApp account you have one or more capacity pools. On the capacity pool you define the amount of storage (minimum 4 TB – maximum 500 TB) and the performance you want on the pool of storage.
The performance tier is split into three different options based upon **service level**:
* **Standard** 16 MiB/s (~ 16.7 MB/s) throughput per 1 TB of capacity provisioned
* **Premium**  64 MiB/s (~ 67 MB/s) throughput per 1 TB of capacity provisioned
* **Ultra**  128 MiB/s (~ 134 MB/s) throughput per 1 TB of capacity provisioned

[MiB: it represents 1024 * 1024 bytes]<br>
[MB: it represents 1000 * 1000 bytes]

A Volume is the actual mount point which can be accessed and where we configure which protocol to be used. When configuring a volume, you need to specify a subnet where the mount point will be accessible. To use a subnet for NetApp volumes, you need to delegate NetApp Service to the subnet. <br>
ANFT network features can takes two values: **Standard** or **Basic**.
* **Standard**

    This setting enables VNet features for the volume.
    If you need higher IP limits or VNet features such as network security groups, user-defined routes, or additional connectivity patterns, you should set Network Features to Standard.
    Volume with Standard network features cannot be created without registration to **SDN Appliance AFEC feature**
    ```powershell
    Register-AzProviderFeature -ProviderNamespace Microsoft.NetApp -FeatureName ANFSDNAppliance
    Register-AzProviderFeature -ProviderNamespace Microsoft.Network -FeatureName AllowPoliciesOnBareMetal
    ```
    Check the status of registration by commad:
    ```powershell
    Get-AzProviderFeature -ProviderNamespace Microsoft.NetApp -FeatureName ANFSDNAppliance
    Get-AzProviderFeature -ProviderNamespace Microsoft.Network -FeatureName AllowPoliciesOnBareMetal
    ```
* **Basic**

    This setting provides reduced IP limits (<1000) and <ins> no additional VNet features </ins> for the volumes. You should set Network Features to Basic if you <ins>do not</ins> require VNet features.

Azure NetApp Files supports **NFSv3** and **NFSv4.1**. <br>
To mount an NFS volume successfully, ensure that the following NFS ports are open between the client and the NFS volumes:
* **111 TCP/UDP** = RPCBIND/Portmapper
* **635 TCP/UDP** = mountd
* **2049 TCP/UDP** = nfs
* **4045 TCP/UDP** = nlockmgr (NFSv3 only)
* **4046 TCP/UDP** = status (NFSv3 only)

The NFS ports are being specified in the network rule of Azure firewall. <br>
The NetApp configuration deployed from the ARM template is shown below:

[![3]][3]

## <a name="list of files"></a>1. File list

| File name                 | Description                                                                             |
| ------------------------- | --------------------------------------------------------------------------------------- |
| **init.json**             | define the value of input variables required for the full deployment                    |
| **netapp-anf.json**       | ARM template to deploy ANF account, volumes, vnets, vnet peering, VMs, azure firewall, log analytics, Azure firewall diagnostic settings, Azure Bastion  |
| **netapp-anf.ps1**        | powershell script to deploy **netapp-anf.json**                                         |
| **nfs.sh**                | bash script to mount manually the NFS volumes                                           |


To run the project, follow the steps in sequence:
1. change/modify the value of input variables in the file **init.json**
2. run the powershell script **netapp-anf.ps1** to execute the deployment.


The meaning of input variables in **init.json** are shown below:
```json
{
    "subscriptionName": "NAME_OF_AZURE_SUBSCRIPTION",
    "ResourceGroupName": "NAME_OF_RESOURCE_GROUP",
    "location": "AZURE_LOCATION_VNET_ANFS",
    "adminUsername": "ADMINISTRATOR_USERNAME",
    "adminPassword": "ADMINISTRATOR_PASSWORD",
    "mngIP": "PUBLIC_IP_ADDRESS_TO_FILTER_SSH_ACCESS_TO_VMS - it can be empty string, if you do not want to lock SSH access to a specific IP by NSG!"
}
```

## <a name="remote NFS volume in Linux"></a>2. Mounting the remote NFS volume in Linux
In linux VM, an NFS client is required to mount NFS volumes:
```console
sudo apt update
sudo apt-get -y install nfs-common
```

Before mounting an NFS partition, identify the existing partitions:
```console
sudo parted -l
sudo fdisk -l
sudo fdisk -l | grep NFS
sudo blkid
```
blkid shows the volume's UUID. 

In Azure VM, create a new directory:
```
sudo mkdir -p <nameNetApplVolume>
```

The structure of mount command: **sudo mount -t _type device dir_** <br>
This tells the kernel to attach the filesystem found on device (which is of type **_type_**) at the directory **_dir_**.<br>
For remote NFS:
```console
sudo mount -t nfs {IP of NFS server}:{folder path on server} [mount point]
```

In our case we create the directory:
```console
sudo mkdir -p /mnt/nfs1
```
Since we're creating it with sudo, the directory is owned by the host’s root user:
```
ls -la /mnt/nfs1
```

The target IP is 10.0.0.4, and the mount of the file system NFS (ver 4.1 and ver 3):
```console
sudo mount -t nfs -o rw,hard,rsize=65536,wsize=65536,sec=sys,vers=4.1,tcp 10.1.0.4:/netappVol1 /mnt/nfs1
sudo mount -t nfs -o rw,hard,rsize=65536,wsize=65536,sec=sys,vers=4.1,tcp 10.1.0.4:/netappVol2 /mnt/nfs2
sudo mount -t nfs -o rw,hard,rsize=65536,wsize=65536,sec=sys,vers=3,tcp 10.1.0.4:/netappVol3 /mnt/nfs3
```

The mount command options are specified with a **-o** flag followed by a comma separated string of options.
* **rw**: read-write mode
* two mount options can be selected: **software** vs **hard** mouting. In **hard** mounting, the program accessing a file on a NFS mounted file system will hang when the server crashes. The process cannot be interrupted or killed (except by a "sure kill") unless you also specify **intr**. When the NFS server is back online the program will continue undisturbed from where it was.
* The **rsize** and **wsize** specify the size of the chunks of data that the client and server pass back and forth to each other. If no rsize and wsize options are specified, the default varies by which version of NFS we are using. The most common default is 4K (4096 bytes). <br> Using an **rsize** or **wsize** larger than your network's MTU (often set to 1500, in many networks) will cause IP packet fragmentation when using NFS over UDP. IP packet fragmentation and reassembly require a significant amount of CPU resource at both ends of a network connection. In addition, packet fragmentation also exposes your network traffic to greater unreliability, since a complete RPC request must be retransmitted if a UDP packet fragment is dropped for any reason. Any increase of RPC retransmissions, along with the possibility of increased timeouts, are the single worst impediment to performance for NFS over UDP.
* **tcp** or **udp**. Using TCP has a distinct advantage and disadvantage over UDP. The advantage is that it works far better than UDP on lossy networks. When using TCP, a single dropped packet can be retransmitted, without the retransmission of the entire RPC request, resulting in better performance on lossy networks. In addition, TCP will handle network speed differences better than UDP, due to the underlying flow control at the network level. <br> The disadvantage of using TCP is that it is not a stateless protocol like UDP. If your server crashes in the middle of a packet transmission, the client will hang and any shares will need to be unmounted and remounted. [see the document](http://nfs.sourceforge.net/nfs-howto/ar01s05.html)
 * **sec**: it specifies the type of security to utilize when authenticating an NFS connection. **sec=sys** is the default setting, which uses local UNIX UIDs and GIDs by means of AUTH_SYS to authenticate NFS operations.

To verify that the NFS share is mounted successfully, run the **df -h** command":
```
sudo df -hT
```
To find out which processes are accessing the NFS share, use the fuser command:
```
fuser -m MOUNT_POINT
```

Copy a file (i.e. syslog) to the destination volume:
```bash
cp /var/log/dmesg /mnt/nfs1/
```

To **unmount** the NFS remote share:
```
sudo umount /mnt/nfs1
```

### <a name="remote NFS volume in Linux"></a>2.1 Mounting the remote NFS volumes at boot
**fstab** is a system's filesystem table designed to ease the burden of mounting and unmounting file systems to a machine. It is a set of rules used to control how different filesystems are treated each time they are introduced to a system.
The table itself is a 6-column structure, separated by spaces or tabs, where each column designates a specific parameter and must be set up in the correct order. 
The columns of the table are as follows from left to right: 

**Device**: usually the given name or UUID of the mounted device (sda1/sda2/etc).<br>
**Mount Point**: designates the directory where the device is/will be mounted.  <br>
**File System Type**: nothing trick here, shows the type of filesystem in use.  <br>
**Options**: lists any active mount options. If using multiple options, they must be separated by commas. <br> 
**Backup Operation**: (the first digit) this is a binary system where 1 = dump utility backup of a partition. 0 = no backup. This is an outdated backup method and should NOT be used.<br> 
**File System Check Order**: (second digit) Here we can see three possible outcomes.  0 means that fsck will not check the filesystem. Numbers higher than this represents the check order. The root filesystem should be set to 1 and other partitions set to 2. <br>

Some options in **fstab**:
* **auto/noauto**: controls whether the partition is mounted automatically on boot (or not). The default is **auto**. **noauto** overrides the auto option and will ensure that the mount is not automatically mounted at boot time. 
* **auto**: the filesystem can be mounted automatically at bootup. This is really unnecessary as this is the default action of mount -a anyway.
* **exec/noexec**: controls whether or not the partition can execute binaries. In the name of security, this is usually set to noexec.
* **ro/rw**: controls read and write privileges - ro = read-only, where rw= read-write.
* **nouser** : only permit root to mount the filesystem (default setting).
* **user**: permit any user to mount the filesystem.
* **noatime**:it disables writing file access times to the drive every time you read a file. This speed up the read operations
* **_netdev**: it ensures systemd understands that the mount is network dependent and order it after the network is online. 
* **bg**: if bg is specified, a timeout or failure causes the mount command to fork a child which continues to attempt to mount the export. This is known as a "background" mount.

If you want the volume mounted automatically when an Azure VM is started or rebooted, add an entry to the **/etc/fstab** file on the host. <br>
For example: 
```
$ANFIP:/$FILEPATH /$MOUNTPOINT nfs bg,rw,hard,noatime,nolock,rsize=65536,wsize=65536,vers=3,tcp,_netdev 0 0
$ANFIP is the IP address of the Azure NetApp Files volume found in the volume properties menu
$FILEPATH is the export path of the Azure NetApp Files volume
$MOUNTPOINT is the directory created on the Linux host used to mount the NFS export
```

In our specific example:
```console
10.1.0.4:/netappVol1  /mnt/nfs1 nfs bg,rw,hard,noatime,nolock,rsize=65536,wsize=65536,vers=4.1,tcp,_netdev 0 0
10.1.0.4:/netappVol2  /mnt/nfs2 nfs bg,rw,hard,noatime,nolock,rsize=65536,wsize=65536,vers=4.1,tcp,_netdev 0 0
10.1.0.4:/netappVol3  /mnt/nfs3 nfs bg,rw,hard,noatime,nolock,rsize=65536,wsize=65536,vers=3,tcp,_netdev 0 0
```

To validate **fstab** without system reboot, you can simple run: 
```
sudo mount -a
```
**-a**: mount all filesystems (of the given types) mentioned in fstab. This command will mount all (not-yet-mounted) filesystems mentioned in fstab and is used in system script startup during booting. If a mount has the **noauto** option set, the sudo mount -a command will not mount it.

The same -a option can be used with umount to unmount all the filesystems in **/etc/mtab**:
```
sudo unmount -a
```

### <a name="cloud-init NFS volume in Linux"></a>2.2 Cloud-init to mount the NFS volumes
Cloud-init is used to mount the NFS volumes at boot time. <br>
To make sure the script worked, use the following command to see the status of cloud-init. You can have two outputs from this:
```console
$ cloud-init status
status: done

$ cloud-init status
status: error
```
To troubleshoot the error, you can locate the logs by the following commands: 
```console
$ tail /var/log/cloud-init-output.log
$ tail /var/log/cloud-init.log
```
For analyse logs: 
```console
$ cloud-init analyze show -i /var/log/cloud-init.log
```
The purpose of cloud-init, is that it only runs during the first boot, but for testing purposes it's good to know how to rerun the cloud-init script.
```console
$ cloud-init clean --reboot
```

## <a name="remote NFS volume in Windows"></a>3. Mounting NFS volume in Windows
To install the NFS client in Windows, run the powershell:
- Server OS:
  ```powershell
  Install-WindowsFeature NFS-Client
  ```
- Desktop OS: 
  ```powershell
  Enable-WindowsOptionalFeature -FeatureName ServicesForNFS-ClientOnly, ClientForNFS-Infrastructure -Online -NoRestart
  ```

To mount NFSv3 volumes on a Windows client using NFS, first of all mounts the volume onto a Linux VM and change the rights into **chmod 777** or **chmod 775** command against the volume:
```bash
chmod -R 777 /mnt/nfs3
```
then mount the volume via the NFS client on Windows using the mount option **mtype=hard** to reduce connection issues. For example:

```powershell
Set-NfsClientConfiguration -CaseSensitiveLookup 1
mount -o rsize=1024 -o wsize=1024 -o mtype=hard \\10.1.0.4\netappVol3 X
```
- replace share-name netappVol3 with the name of your NFS share
- replace X: with the desired drive letter.

To unmount:
```
umount [–f] {–a | Drive}
```

## <a name="traffic transit"></a>4. Transit across the azure firewall
The communications between the application VMs and the NetApp volume transit across the Azure firewall

[![4]][4]

To check the IOPS of the NFS, you can use **FIO** [**Flexible I/O**]. To install **fio** in Ubuntu VMs:
```bash
sudo apt-get update && sudo apt-get install fio -y
```
You can run the commands directly or create a job file with the command and then run the job file.<br>
Some information about the options available in **fio**:
* **--name** it is a required argument, fio will create files based on that name to test with, inside the working directory you're currently in.
* **--rw=randwrite** means do random write operations to our test files in the current working directory. Other options include **seqread, seqwrite, randread, and randrw**
* **--bs=4k** The size of the block file for a single I/O is 4 KB. These are very small individual operations. It means a extra overhead in the disks, since a separate operation has to be commanded for each 4K of data. the value should be low (bs value should be small value such as 4k) when testing IOPS, and it should bet a large value (such as 1024k) when testing throughput.
* **--size=4G** The size of the test file. 
* **--numjobs=4** The number of test threads. If we wanted to simulate multiple parallel processes, eg --numjobs=4, which would create 4 separate test files of --size size, and 4 separate processes operating on them at the same time.
* **--iodepth=1** number of I/O requests can be made concurrently. This is how deep we're willing to try to stack commands in the OS's queue. Since we set this to 1, this is effectively pretty much the same thing as the sync IO engine—we're only asking for a single operation at a time, and the OS has to acknowledge receipt of every operation we ask for before we can ask for another.
* **-ioengine=libaio** libaio (Linux AIO, asynchronous I/O) is selected for the test. I/O is usually used in applications in two ways.
* **--direct=1** posibile values true=1 or false=0. If the value is set to 1 (using non-buffered I/O) is fairer for testing as the benchmark will send the I/O directly to the storage subsystem bypassing the OS filesystem cache. The recommended value is always 1.


###  Sequential write throughput (write bandwidth) (1024 KB for single I/O)
```
fio --filename=/mnt/nfs1/1.bin --size=1G --direct=1 --iodepth=64 --rw=write --ioengine=libaio --bs=1024k --numjobs=1 --runtime=60 --group_reporting --name=write-testing --eta-newline=1
```
### Sequential read throughput (read bandwidth) (1024 KB for single I/O)
```
fio --filename=/mnt/nfs1/1.bin --size=1G --direct=1 --iodepth=64 --rw=read --ioengine=libaio --bs=1024k --numjobs=1 --runtime=60 --group_reporting  --name=read-testing --eta-newline=1
```

### Random write latency (4 KB for single I/O):
```
fio --filename=/mnt/nfs1/1.bin -size=1G -direct=1 --iodepth=1 --rw=randwrite --ioengine=libaio --bs=4k --numjobs=1 --runtime=60 --group_reporting  --name=rnd-write-testing --eta-newline=1
```
### Random read latency (4KB for single I/O)
```
fio --filename=/mnt/nfs1/1.bin --size=1G --direct=1 --iodepth=1 --rw=randread --ioengine=libaio --bs=4k --numjobs=1 --runtime=60 --group_reporting  --name=rnd-read-testing --eta-newline=1
```

### Test file random read/writes (64KB for single I/O) 
```
sudo fio --filename=/mnt/nfs2/2.bin --size=4GB --direct=1 --iodepth=32 --rw=randrw --ioengine=libaio --bs=64k --numjobs=4 --runtime=60 --group_reporting --name=64k-test --eta-newline=1
```
This command will write a 4GB file [4 jobs x 4 GB = 16GB] running 4 processes at a time.


### test random read/writes by job
Create a job file, fio-rnd-readwrite.fio, with the following content:
```
[global]
bs=64K
iodepth=64
direct=1
ioengine=libaio
group_reporting
time_based
runtime=60
numjobs=4
name=raw-randreadwrite
rw=randrw
							
[job1]
filename=/mnt/nfs1/1.bin
```

Run the job using the following command:
```
fio fio-rnd-readwrite.fio --eta-newline=1
```

Test fio in windows. If we mount the NFS volume as X drive: 
```console
"C:\Program Files\fio\fio.exe" --name=test1 --readwrite=randrw --rwmixread=70 --bs=8k --ba=64k --filename=X\:\datafile.dat --size=32m --ioengine=windowsaio  --runtime=60 --time_based --iodepth=2 --numjobs=3  --eta=always
```

To measure your disks I/O latency you can use IOPing tool:
```
apt install -y ioping
ioping /mnt/nfs1 -s 256k -i 1
```
-s specify the request size.<br>
-i the time interval. You can use the value 0 to flood requests.

`Tags: NetApp` <br>
`date: 22-09-2022`

<!--Image References-->

[1]: ./media/network-diagram1.png "network diagram"
[2]: ./media/storage-hierarchy.png "Azure NetApp File storage hierarchy"
[3]: ./media/netapp-configuration.png "Azure NetApp configuration"
[4]: ./media/network-diagram2.png "traffic in transit through the azure firewall"


<!--Link References-->
