
<properties
pageTitle= 'AKS: your first hand-on'
description= "AKS: your first hand-on"
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
   ms.date="11/12/2023"
   ms.author="fabferri" />

# Azure Kubernetes Service (AKS): your first hand-on
The following setup has been verified in Windows host with Azure CLI installed.

### <a name="login in azure subscription"></a> STEP1: login and connect to the target Azure subscription
- Get a list of available subscriptions:
```bash
az account list --output table
```

- See what subscription you are currently using:
```bash
az account show
az account show --output table
```

- Get the current default subscription using "list" command:
```bash
az account list --query "[?isDefault]"
```

- Change the active subscription using the subscription name:
```bash
az account set --subscription "AzureDemo"
```

- Using powershell, change the active subscription:
```bash
$SubId="$(az account list --query "[?name=='AzureDemo'].id" --output tsv)"
az account set --subscription $SubId
```


### <a name="create a resource group"></a> STEP2: set variables and create a resource group
```bash
$location="uksouth"
$rg="k8-1"
az group create --name $rg --location $location
```

### <a name="create an AKS cluster"></a> STEP3: Create an AKS cluster
```bash
az aks create -g $rg -n aks1 --enable-managed-identity --node-count 1 --generate-ssh-keys
```

> [!NOTE] 
> Running the command shows:
> SSH key files **'C:\Users\USERNAME_FOLDER\\.ssh\id_rsa'** and **'C:\Users\USERNAME_FOLDER\\.ssh\id_rsa.pub'** have been generated under ~/.ssh to allow SSH access to the VM. 
> If using machines without permanent storage like Azure Cloud Shell without an attached file share, back up your keys to a safe location

If the files 'C:\Users\USERNAME_FOLDER\\.ssh\id_rsa' and 'C:\Users\USERNAME_FOLDER\\.ssh\id_rsa.pub' are already present, you can use the command:
```bash
$SSH=(Get-Content ~\.ssh\id_rsa.pub)
az aks create -g $rg -n aks1 --enable-managed-identity --node-count 1 --ssh-key-value $SSH
```

See the list:
```bash
az aks list -o table
```

### <a name="install kubectl"></a> STEP4: install kubectl locally. This is one time operation
```bash
az aks install-cli
```
Command output: <br>
The detected architecture of current device is "amd64", and the binary for "amd64" will be downloaded. If the detection is wrong, please download and install the binary corresponding to the appropriate architecture.
No version specified, will get the latest version of kubectl from "https://storage.googleapis.com/kubernetes-release/release/stable.txt"
Downloading client to "C:\Users\USERNAME_FOLDER\.azure-kubectl\kubectl.exe" from "https://storage.googleapis.com/kubernetes-release/release/v1.28.4/bin/windows/amd64/kubectl.exe"
The installation directory "C:\Users\USERNAME_FOLDER\.azure-kubectl" has been successfully appended to the user path, the configuration will only take effect in the new command sessions. Please re-open the command window.
No version specified, will get the latest version of kubelogin from "https://api.github.com/repos/Azure/kubelogin/releases/latest"
Downloading client to "C:\Users\USERNAME_FOLDER\AppData\Local\Temp\tmprxe3487l\kubelogin.zip" from "https://github.com/Azure/kubelogin/releases/download/v0.0.34/kubelogin.zip"
Moving binary to "C:\Users\USERNAME_FOLDER\.azure-kubelogin\kubelogin.exe" from "C:\Users\USERNAME_FOLDER\AppData\Local\Temp\tmprxe3487l\bin\windows_amd64\kubelogin.exe"
The installation directory "C:\Users\USERNAME_FOLDER\.azure-kubelogin" has been successfully appended to the user path, the configuration will only take effect in the new command sessions. Please re-open the command window.

Check the kubectl version:
```bash
kubectl version --client
kubectl version --client --output=yaml
```

### <a name="configure kubectl"></a> STEP5: Configure kubectl to connect to your Kubernetes cluster
```bash
az aks get-credentials --resource-group $rg --name aks1
```
By default, the credentials are <ins>merged</ins> into the **C:\Users\USERNAME_FOLDER\.kube\config** file so kubectl can use them.

The **kubectl config file** is a configuration file that stores all the information necessary to interact with a Kubernetes cluster. It contains the following information:
- The name of the Kubernetes cluster
- The location of the Kubernetes API server
- The credentials (username and password) for authenticating with the Kubernetes API server
- The names of all contexts defined in the cluster

To view the config file,:
```bash
kubectl config view
```

Filter the list ony for cluster name:
```bash
kubectl config view -o jsonpath='{range .contexts[*]}{.name}{''\n''}{end}'
```

A Kubernetes context is a group of access parameters that define which cluster you’re interacting with, which user you’re using, and which namespace you’re working in. <br>

To get all contexts in the file ~\.kube\config
```bash
kubectl config get-contexts
```
To find the current context:
```bash
kubectl config current-context
```

You can switch between these contexts by using: 
```bash
kubectl config use-context <CONTEXT_NAME>
```

To delete a context:
```bash
kubectl config delete-context <CLUSTER_NAME>
```

### <a name="connecto to th AKS cluster"></a> STEP6: Verify the connection to your cluster 
This command returns a list of the cluster nodes:
```bash
kubectl get nodes
```

### <a name="deploy the application"></a> STEP7: deploy the application using a manifest file
Create a file named **nginx.yaml** and paste the content:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 2 # tells deployment to run 2 pods matching the template
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: public-svc
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
```
In Kubernetes, a Service is a method for exposing a network application that is running as one or more Pods in your cluster.


**Command to deploy the application:**
```bash
kubectl apply -f nginx.yaml
```
The **-f** flag is used to specify the file that contains the Deployment configuration. <br>
The command execution shows: <br>
```
deployment.apps/nginx-deployment created
service/public-svc created
```

In **nginx.yaml** file, we define a Deployment called **nginx-deployment** that runs an **nginx:latest** Docker image in two pods (as specified by **replicas: 2**)

Display information about the Deployment:
```bash
kubectl describe deployment nginx-deployment
```
List the Pods created by the deployment:
```bash
kubectl get pods -l app=nginx
```

### <a name="check the application"></a> STEP8: Test the application
Check the status of the deployed pods:
```bash
kubectl get pods -o wide
```
All the POD should be in "Running"
<br>

Display information about a Pod:

```bash
kubectl describe pod <pod-name>
kubectl describe pod nginx
```


#### Check for a public IP address for the store-front application [CTRL-C to stop the kubectl watch process]
```bash
kubectl get service public-svc --watch
```

Store the public IP of the service in a variable:
```bash
$ServicePubIP=(kubectl get service public-svc -o jsonpath='{ .status.loadBalancer.ingress[0].ip }')
```
<br>

Open a web browser to the external IP address:
```powershell
Start-Process http://$ServicePubIP
```
it is visualized the nginx home-page.

### <a name="scaling up the application"></a> STEP9: Scaling up the application by increasing the replica count
Change the number of pods from 2 to 3 and from 3 to 5:
```bash
kubectl scale --replicas=3 deployment.apps/nginx-deployment
OR
kubectl scale --replicas=5 deployment/nginx-deployment
```

Verifing the number of replica:
```bash
kubectl get pods -o wide
```

Scaling down the Deployment works the same way as scaling up:
```bash
kubectl scale --replicas=2 deployment/nginx-deployment
```

### <a name="delete deployment and resource group"></a> STEP11: Deleting a deployment and Resource Group
```bash
kubectl delete deployment nginx-deployment
```
<br>
Removing the deployment does not change the context in ~\.kube\config . 
To delete the context:

```bash
kubectl config delete-context aks1
```

Delete the resource group:
```bash
az group delete --name $rg --yes --no-wait
```