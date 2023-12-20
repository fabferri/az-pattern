
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
Kubernetes objects are persistent entities in the Kubernetes system. A Kubernetes object is a "<ins>record of intent</ins>"--once you create the object, the Kubernetes system will constantly work to ensure that object exists. <br>
By creating  objects, you're effectively telling the Kubernetes system what is your cluster's desired state. In Kubernetes the YAML manifest file defines the desire state. <br>

Basic objects include:
- **Pod**. A group of one or more containers. Kubernetes uses pods to run an instance of your application. A pod represents a single instance of your application. Pods typically have a 1:1 mapping with a container. In advanced scenarios, a pod may contain multiple containers. Multi-container pods are scheduled together on the same node, and allow containers to share related resources. A pod is a logical resource, but application workloads run on the containers. Pods are typically ephemeral, disposable resources.
- **Service**. An abstraction that defines a logical set of pods as well as the policy for accessing them.
- **Volume**. An abstraction that lets us persist data. (This is necessary because containers are ephemeral—meaning data is deleted when the container is deleted.)
- **Namespace**. Namespaces provides a mechanism for isolating groups of resources within a single cluster. Names of resources need to be unique within a namespace, but not across namespaces. Namespace-based scoping is applicable only for namespaced objects. Namespaces are a way to divide cluster resources between multiple users (via resource quota).

A **deployment** is an abstraction to the **pod**. It allows you to have extra functionality and control on top of the pod to say how many instances of a pod you want to run across nodes or if you want to define your rolling update strategy. This allows you to control your deployments based on your requirements in order to have zero downtime as you bring up a new process and deprecate old ones. <br>
In Kubernetes manifest file, the **Deployment** makes the following tasks: 
- creates the pods (defines the number of pod replicas to create),
- create and update a set of identical pods,
- ensures the correct number of pods is always running in the cluster, 
- handles scalability,
- takes care of updates to the pods.

A Deployment describes a desired state. All these activities can be configured through fields in the Deployment YAML. <br> 

A container image represents binary data that encapsulates an application and all its software dependencies.<br>
You typically create a container image of your application and push it to a registry before referring to it in a Pod.<br>
If you don't specify a registry hostname, Kubernetes assumes that you reference the container image from the Docker public registry: https://hub.docker.com/ 

**The following setup has been verified in Windows host with Azure CLI locally installed.**

### <a name="login in azure subscription"></a> STEP1: login and connect to the target Azure subscription
- `az login --use-device-code`      - login in Azure with the device authentication code in the web browser
- `az account list --output table`  - Get a list of available subscriptions <br>
- `az account show`                 - Show the subscription you are currently using <br>
- `az account show --output table`  - Show the subscription you are currently using by tabular format <br>
- `az account list --query "[?isDefault]" `   - Get the current default subscription <br>
- `az account set --subscription "AzureDemo"` - Change the active subscription using the subscription name 
- `az account list --query "[?name=='AzureDemo'].id" --output tsv` - Get the Azure subscription ID
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

If the files **'C:\Users\USERNAME_FOLDER\\.ssh\id_rsa'** and **'C:\Users\USERNAME_FOLDER\\.ssh\id_rsa.pub'** are already present, you can use the command:
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
Downloading client to "C:\Users\USERNAME_FOLDER\\.azure-kubectl\kubectl.exe" from "https://storage.googleapis.com/kubernetes-release/release/v1.28.4/bin/windows/amd64/kubectl.exe"
The installation directory "C:\Users\USERNAME_FOLDER\\.azure-kubectl" has been successfully appended to the user path, the configuration will only take effect in the new command sessions. Please re-open the command window.
No version specified, will get the latest version of kubelogin from "https://api.github.com/repos/Azure/kubelogin/releases/latest"
Downloading client to "C:\Users\USERNAME_FOLDER\AppData\Local\Temp\tmprxe3487l\kubelogin.zip" from "https://github.com/Azure/kubelogin/releases/download/v0.0.34/kubelogin.zip"
Moving binary to "C:\Users\USERNAME_FOLDER\\.azure-kubelogin\kubelogin.exe" from "C:\Users\USERNAME_FOLDER\AppData\Local\Temp\tmprxe3487l\bin\windows_amd64\kubelogin.exe"
The installation directory "C:\Users\USERNAME_FOLDER\\.azure-kubelogin" has been successfully appended to the user path, the configuration will only take effect in the new command sessions. Please re-open the command window.

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

Kubectl uses "contexts" to know how to communicate with the cluster. Contexts are stored in a kubeconfig file, which can store multiple contexts. <br>
A Kubernetes context is a group of access parameters that define which cluster you’re interacting with, which user you’re using, and which namespace you’re working in. <br>
The **kubectl config file** is a configuration file containing the following information:
- The name of the Kubernetes cluster
- The location of the Kubernetes API server
- The credentials (username and password) for authenticating with the Kubernetes API server
- The names of all contexts defined in the cluster
<br>

- `kubectl config view` - View the config file
- `kubectl config view -o jsonpath='{range .contexts[*]}{.name}{''\n''}{end}'` - Filter the list ony for cluster name
- `kubectl config get-contexts` - Get all contexts in the file ~\.kube\config
- `kubectl config current-context` - Find the current context
- `kubectl config use-context <CONTEXT_NAME>` - Switch between contexts
- `kubectl config delete-context <CLUSTER_NAME>` - Delete a context


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
In Kubernetes, a Service is a method for exposing a network application that is running as one or more Pods in your cluster. <br>
A description of the deployment in the YAML manifest file is shown below:
	
| Specification                   | Description                                                                           |
| ------------------------------- | ------------------------------------------------------------------------------------- | 
|`.apiVersion`                    |	Specifies the API group and API resource you want to use when creating the resource.  |
|`.kind`                          |	Specifies the type of resource you want to create.                                    |
|`.metadata.name`                 |	Specifies the name of the deployment. This file runs the nginx image from Docker Hub. |
|`.spec.replicas`                 |	Specifies how many pods to create. This file will create two duplicate pods.          |
|`.spec.selector`                 |	Specifies which pods will be affected by this deployment.                             |
|`.spec.selector.matchLabels`     |	Contains a map of {key, value} pairs that allow the deployment to find and manage the created pods. |
|`.spec.selector.matchLabels.app` |	Has to match `.spec.template.metadata.labels.`                |
|`.spec.template.labels`          |	Specifies the {key, value} pairs attached to the object.      |
|`.spec.template.app`             |	Has to match `.spec.selector.matchLabels.`                    |
|`.spec.spec.containers`          |	Specifies the list of containers belonging to the pod.        |
|`.spec.spec.containers.name`     |	Specifies the name of the container specified as a DNS label. |
|`.spec.spec.containers.image`    |	Specifies the container image name.                           |
|`.spec.spec.containers.ports`    |	Specifies the list of ports to expose from the container.     |
|`.spec.spec.containers.ports.containerPort` |	Specifies the number of ports to expose on the pod's IP address |

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

### <a name="AKS cluster with ARM template"></a> STEP12: Spin up an AKS cluster with ARM template
To spin up the ARM template **k8s.json** run the script: **k8s.ps1** <br>
When completed, run the command to see the cluster:
```bash
az aks list -o table
```

To communicate with the specific new cluster:
```bash
az aks get-credentials -g $rg -n $aksName
kubectl cluster-info
kubectl get nodes -o wide
```


> [!NOTE]
**kubectl get** can fetch information about all Kubernetes objects, as well as nodes in the Kubernetes data plane.
The most common Kubernetes objects you are likely to query are pods, services, deployments, stateful sets, and secrets.
- **-o wide** just adds more information (which is dependent on the type of objects being queried).
- **-o yaml** and **-o json** output the complete current state of the object (and thus usually includes more information than the original manifest files).
- **-o jsonpath** allows you to select the information you want out of the full JSON of the -o json option using the jsonpath notation.
- **-o go-template** allows you to apply Go templates for more advanced features.