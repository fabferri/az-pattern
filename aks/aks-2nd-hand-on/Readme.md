
<properties
pageTitle= 'AKS: 2nd hand-on'
description= "AKS: 2nd hand-on"
services="AKS"
documentationCenter="https://github.com/fabferri/"
authors="fabferri"
editor=""/>

<tags
   ms.service="AKS"
   ms.devlang="AKS"
   ms.topic="article"
   ms.tgt_pltfrm="AKS"
   ms.workload="AKS"
   ms.date="20/12/2023"
   ms.author="fabferri" />

# Azure Kubernetes Service (AKS): 2nd hand-on
The hand-on discuss in Kubernetes about persistent storage and deployment. The nginx is created in two pods with web site in persistent storage. <br>

A Kubernetes **StorageClass** is a Kubernetes storage mechanism that lets you dynamically provision persistent volumes (PV) in a Kubernetes cluster. Kubernetes administrators define classes of storage, and then pods can <ins>dynamically</ins> request the specific type of storage they need.

Each StorageClass contains the fields provisioner, parameters, and reclaimPolicy, which are used when a PersistentVolume belonging to the class needs to be dynamically provisioned.
Creating a **StorageClass** is like to creating other Kubernetes objects and it can be done with manifest file.
Every **StorageClass** has the following fields:
- **Provisioner** - this is the plugin used to provision the PersistenVolume. Kubernetes provides internal provisioners, which you can see listed [here](https://kubernetes.io/docs/concepts/storage/storage-classes/#provisioner). Their names have a **kubernetes.io** prefix, and they are shipped by default as part of Kubernetes.
- **volumeParameters** - parameters describe volumes belonging to the StorageClass. The parameters depend on the provisioner plugin and the properties of the underlying storage system.
- **reclaimPolicy** - indicates under what conditions the storage is released by a pod and can be reclaimed for use by other pods.  in the class’s reclaimPolicy field, StorageClass can dynamically create PersistentVolumes that specify either **Delete** or **Retain**.
   - Setting the reclaim policy to **Delete** means that the storage volume is deleted when it is no longer required by the pod.
   - Setting the reclaim policy to **Retain** means that the storage volume is retained when no longer required by the pod and can be reused by other pods. 
PersistentVolumes that are created manually and managed via a StorageClass will have whatever reclaim policy they were assigned at creation. <br>
To see the default StorageClass: `kubectl get storageclass`
- **volumeBindingMode** - (optional) it controls when volume binding and dynamic provisioning should occur. it can set to **Immediate** or ****. 
    - **Immediate** mode: it indicates that volume binding and dynamic provisioning occurs once the PersistentVolumeClaim is created. When unset, **"Immediate"** mode is used by default.
    - **WaitForFirstConsumer** mode: it will delay the binding and provisioning of a PersistentVolume until a Pod using the PersistentVolumeClaim is created. 

**In-tree drivers refers to the storage drivers that are part of the core Kubernetes code opposed to the CSI drivers, which are plug-ins.** <br>
In the past was challenging to add support for new volume plugins to Kubernetes: volume plugins were "in-tree" meaning their code was part of the core Kubernetes code and shipped with the core Kubernetes binaries—vendors wanting to add support for their storage system to Kubernetes (or even fix a bug in an existing volume plugin) were forced to align with the Kubernetes release process. <br>
In-tree persistent volume types <ins>kubernetes.io/azure-disk</ins> and <ins>kubernetes.io/azure-file</ins> **are deprecated** and will no longer be supported. <br>
Container Storage Interface (CSI) defines a standard interface for container orchestration systems (like Kubernetes) to expose arbitrary block and file storage storage systems to their container workloads.
Using CSI, third-party storage providers can write and deploy plugins exposing new storage systems in Kubernetes without ever having to touch the core Kubernetes code. <br>
Assuming a CSI storage plugin is already deployed on a Kubernetes cluster, users can use CSI volumes through the Kubernetes storage API objects: **PersistentVolumeClaims**, **PersistentVolumes**, and **StorageClasses**. <br>
You can enable automatic creation/deletion of volumes for CSI Storage plugins that support dynamic provisioning by creating a **StorageClass** pointing to the CSI plugin. <br>
The CSI storage driver support on AKS allows you to natively use:
- **Azure Disks** can be used to create a Kubernetes DataDisk resource. Azure Disks are mounted as **ReadWriteOnce** and are only available to one node in AKS.    [**provisioner: disk.csi.azure.com**]
- **Azure Files** can be used to mount an SMB 3.0/3.1 share backed by an Azure storage account to pods. With Azure Files, you can share data across multiple nodes and pods. [**provisioner: file.csi.azure.com**]
- **Azure Blob** storage can be used to mount Blob storage (or object storage) as a file system into a container or pod.

A PersistentVolume (PV) is a piece of storage in the cluster that has been provisioned using **Storage Classes**. <br>
A PersistentVolume can be mounted on a host in any way supported by the resource provider.<br>
The PV access mode are:
- **ReadWriteOnce** (RWO): the volume can be mounted as read-write by a single node. ReadWriteOnce access mode still can allow multiple pods to access the volume when the pods are running on the same node. For single pod access, please see ReadWriteOncePod.
- **ReadOnlyMany** (ROX): the volume can be mounted as read-only by many nodes.
- **ReadWriteMany** (RWX): the volume can be mounted as read-write by many nodes.
- **ReadWriteOncePod** (RWOP): the volume can be mounted as read-write by a single Pod. Use ReadWriteOncePod access mode if you want to ensure that only one pod across the whole cluster can read that PVC or write to it.


### <a name="login in azure subscription"></a>1. Login in the Azure subscription and create the Kubernetes cluster
The following setup has been done in Windows host with Azure CLI installed locally.

- `az login --use-device-code` - login with the device authentication code in the web browser
- `az account list --output table`  - Get a list of available subscriptions <br>
- `az account show`                 - Show the subscription you are currently using <br>
- `az account show --output table`  - Show the subscription you are currently using by tabular format <br>
- `az account list --query "[?isDefault]" ` - Get the current default subscription <br>
- `az account set --subscription "AzureDemo"` - Change the active subscription using the subscription name 
- `az account list --query "[?name=='AzureDemo'].id" --output tsv` - Get the Azure subscription ID
- `$SubId="$(az account list --query "[?name=='AzureDemo'].id" --output tsv)"; az account set --subscription $SubId`  - Change the active subscription (powershell)
- `az aks install-cli` - (<ins>Optional</ins>) - One time operation if you do not have aks command installed 
- `az aks create -g $rg -n $clusterName --enable-managed-identity --node-count 1 --ssh-key-value $SSH` - Create the Kubernetes cluster
- `az aks get-credentials -g $rg -n $clusterName` - Configure kubectl to connect to the kubernetes cluster
- `az aks update -g $rg -n $clusterName --enable-file-driver ` - Enable CSI storage drivers on an existing cluster
The powershell script **01-az-k8s-deployment.ps1** create the resource group, the Kubernetes cluster and the credential to connect to the Kubernetes cluster. After the custer creation. The creation of Kubernets cluster is executed by the command `az aks create -g $rg -n $clusterName --enable-managed-identity --node-count 1 --ssh-key-value $SSH`. The parameter **--node-count <NUMBER_NODE>** define the number of nodes in the cluster. <br>

After cluster creation: 
- `az aks list -o table`  - List the properties of Kubernetes cluster: name, Azure region, Resource Group, Kubernetes Version, etc.
- `kubectl get nodes -o wide` - List of the nodes in Kubernetes cluster 
```
kubectl get nodes -o wide
NAME                                STATUS   ROLES   AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME    
aks-nodepool1-31961289-vmss000000   Ready    agent   45m   v1.27.7   10.224.0.5    <none>        Ubuntu 22.04.3 LTS   5.15.0-1052-azure   containerd://1.7.5-1 
aks-nodepool1-31961289-vmss000001   Ready    agent   45m   v1.27.7   10.224.0.4    <none>        Ubuntu 22.04.3 LTS   5.15.0-1052-azure   containerd://1.7.5-1 
```
<br>

> [!NOTE]
> - `kubectl config view` - View the config file
> - `kubectl config get-contexts` - Get all contexts in the file ~\.kube\config
> - `kubectl config current-context` - Find the current context
> - `kubectl config use-context <CONTEXT_NAME>` - Switch between contexts
> - `kubectl config delete-context <CLUSTER_NAME>` - Delete a context


### <a name="Manifest files description"></a>2. Manifest files description

- **01-storage-class.yaml**: CSI storage classes with **provisioner: file.csi.azure.com** uses Azure Standard Storage to create an Azure file share. The reclaim policy for the storage class ensures that the underlying Azure files share is deleted when the respective PV is deleted.
- **02-pvc.yaml**: it creates a PersistentVolumeClaim (PVC).  PersistentVolumeClaims allow a user to consume abstract storage resources (PersistentVolumes). The PV is named in this case **my-azurefile**.
- **03-deployment.yaml**: define Deployment and Service. A Deployment is responsible for keeping a set of identical pods running in the Kubernetes cluster. 
   - `spec.selector.matchLabels` match the labels in `template.metadata.labels` block. <br>
      matchLabels is a query that allows the Deployment to find and manage the Pods it creates.
   - `spec.replicas`: specifies how many pods to run
   - `spec.containers.image`: specifies which container image to run in each of the pods and ports to expose.
   - `spec.containers.volumeMounts.mountPath`: specifies that the PersistentVolume (PV) is at **/mnt/data** on the cluster's Nodes
   - `spec.volumes.name` a name for the volume. the Deployment object creates containers that request a PersistentVolume (PV) using a PersistentVolumeClaim (PVC), and mount it on a path (**mountPath**) within the container.The configuration file specifies that the volume is at **/mnt/data** on the cluster's Node. The configuration also specifies an access mode <ins>ReadWriteMany</ins>, which means the volume can be mounted as read-write by many nodes.
   - `template.spec.volumes.persistentVolumeClaim` references a PVC. 

Apply in sequence the following manifest files:
```bash
kubectl apply -f .\01-storage-class.yaml
kubectl apply -f .\02-pvc.yaml
kubectl apply -f .\03-deployment.yaml
```

After applying the manifest files **01-storage-class.yaml** and **02-pvc.yaml** we have the following:
```Console
kubectl get sc     
NAME                    PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
azurefile               file.csi.azure.com   Delete          Immediate              true                   20m
azurefile-csi           file.csi.azure.com   Delete          Immediate              true                   20m
azurefile-csi-premium   file.csi.azure.com   Delete          Immediate              true                   20m
azurefile-premium       file.csi.azure.com   Delete          Immediate              true                   20m
default (default)       disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   20m
managed                 disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   20m
managed-csi             disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   20m
managed-csi-premium     disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   20m
managed-premium         disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   20m
private-azurefile-csi   file.csi.azure.com   Delete          Immediate              true                   22s
```

```Console
kubectl get pv -o wide
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                           STORAGECLASS            REASON   AGE    VOLUMEMODE
pvc-7b4b9cc2-6f08-409d-b6bf-da6ef98d167e   100Gi      RWX            Delete           Bound    default/private-azurefile-csi   private-azurefile-csi            108s   Filesystem

kubectl get pvc -o wide
NAME                    STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS            AGE     VOLUMEMODE
private-azurefile-csi   Bound    pvc-7b4b9cc2-6f08-409d-b6bf-da6ef98d167e   100Gi      RWX            private-azurefile-csi   3m49s   Filesystem
```
A storage account with Azure file is automatically created in resource group `MC_<AKS_RESOURCE_GROUP_NAME>_<CLUSTER_NAME>_<AZURE_REGION>`:

[![1]][1]

The Azure file automatically created is empty:

[![2]][2]

[![3]][3]

After running the command `kubectl apply -f .\03-deployment.yaml`, you can check the status of Deployment and pods.
In the manifest **03-deployment.yaml**, we define a Deployment called **nginx-deployment** that runs an **nginx:stable** Docker image in two pods (as specified by **replicas: 2**) <br>
- `kubectl describe deployment nginx-deployment` - Display information about the Deployment
- `kubectl get pods -l app=nginx` - List the Pods created by the deployment:
- `kubectl get pods -o wide` - Check the status of the deployed pods. [All the POD should be in "Running"]
- `kubectl describe pod <pod-name>` - Display detailed information about a Pod

```Console
kubectl get pods -o wide
NAME                                READY   STATUS    RESTARTS   AGE     IP            NODE                                NOMINATED NODE   READINESS GATES 
nginx-deployment-546cc48f47-27kwd   1/1     Running   0          6m35s   10.244.1.2    aks-nodepool1-31961289-vmss000000   <none>           <none> 
nginx-deployment-546cc48f47-cswdm   1/1     Running   0          6m35s   10.244.0.11   aks-nodepool1-31961289-vmss000001   <none>           <none> 

NOTE: kubectl get pods -o wide --watch` - track the status to visulized potential changes

kubectl get service -o wide
NAME         TYPE           CLUSTER-IP    EXTERNAL-IP     PORT(S)        AGE     SELECTOR
kubernetes   ClusterIP      10.0.0.1      <none>          443/TCP        49m     <none>
nginx        LoadBalancer   10.0.99.150   X.50.108.145    80:30036/TCP   6m45s   app=nginx
```

Connecting to the public IP X.50.108.145 return the message: **403 Forbidden**
The default path of nginx homepage is **/usr/share/nginx/html/** mounted to the persistent volume. The persistent volume is linked with CSI driver to the Azure file that doesn't contain an **index.html** file. This is can be verified by login (`kubectl exec <POD_NAME> --stdin --tty  -- /bin/bash`) in a container. Inside the container run the command: **df -h** <br>

```
kubectl exec nginx-deployment-546cc48f47-27kwd --stdin --tty  -- /bin/bash

root@nginx-deployment-546cc48f47-27kwd:/#
root@nginx-deployment-546cc48f47-27kwd:/# df -h
Filesystem                                                                                Size  Used Avail Use% Mounted on
overlay                                                                                   124G   22G  103G  18% /
tmpfs                                                                                      64M     0   64M   0% /dev
/dev/root                                                                                 124G   22G  103G  18% /etc/hosts
shm                                                                                        64M     0   64M   0% /dev/shm
//f0bf49a1538a049c38bfea0.file.core.windows.net/pvc-7b4b9cc2-6f08-409d-b6bf-da6ef98d167e  100G     0  100G   0% /usr/share/nginx/html
tmpfs                                                                                     4.5G   12K  4.5G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs                                                                                     3.4G     0  3.4G   0% /proc/acpi
tmpfs                                                                                     3.4G     0  3.4G   0% /proc/scsi
tmpfs                                                                                     3.4G     0  3.4G   0% /sys/firmware

The folder is empty:
ls /usr/share/nginx/html
```

Copy a local **index.html** to the POD in the folder **/usr/share/nginx/html/**:
```Console
kubectl cp <localfile> <some-namespace>/<some-pod>:/tmp/bar
kubectl cp index.html default/nginx-deployment-546cc48f47-27kwd:/usr/share/nginx/html/index.html
```
You can now check out the presence of index.html file in Azure file and verifying with web browser the successful connection to the nginx through public IP.

### <a name="Manifest files description"></a>2. Reference
[Configure a Pod to Use a PersistentVolume for Storage](https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/)

<br>

`Tags: aks` <br>
`date: 19-12-23`


<!--Image References-->
[1]: ./media/01.png "Create automatically an Azure Storage Account"
[2]: ./media/02.png "Azure file automatically created into Azure Storage Account"
[3]: ./media/03.png "Azure file empty"

<!--Link References-->
