<properties
pageTitle= 'MongoDB in Azure VM'
description= "MongoDB in Azure VM"
documentationcenter: na
services= "noSQL DB"
documentationCenter= "github"
authors= "fabferri"
editor= ""/>

<tags
   ms.service="configuration-Example-Azure"
   ms.devlang="na"
   ms.topic="article"
   ms.tgt_pltfrm="Azure"
   ms.workload="MongoDB"
   ms.date="28/12/2022"
   ms.author="fabferri" />

# MongoDB in Azure VM
Here you have an ARM template to install through cloud-init MongoDB in Azure VM.<br>
The structure of MongoDB is shown below:

[![1]][1]

[![2]][2]

This post walks you through the steps required to create a MongoDB configuration with a database and a collection. The configuration diagram is shown below:

[![3]][3]

## File list
* **vms.json**: ARM template to create the Azure VM with MongoDB installed through cloud-init
* **vms.ps1**: powershell to deploy the ARM template **vms.json**. Before running the powershell **vms.ps1** script, two variables have to be customized: $adminUsername and $adminPassword. Replace "ADMINISTRATOR_USERNAME" with your administrator username and "ADMINISTRATOR_PASSWORD" with your administrator password
* **cloud-init-mongodb.txt**: cloud-init file to install mondoDB in the VM at boot time
* **listmovies.json**: The file is used with the **mongoimport** utility to import a collection in MongoDB


## <a name="MongoDB installation"></a>1. MongoDB installation
Ubuntu 22.04 doesn't have official MongoDB packages. The best option now is to have Ubuntu 20.04, where official MongoDB packages are available.

```bash
# Import the public key used by the package management system.
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -

#Create a list file for MongoDB.
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list

# Reload local package database
sudo apt-get update

#Install the MongoDB packages.
sudo apt-get install -y mongodb-org

# Start MongoDB
sudo systemctl start mongod

# Verify that MongoDB has started successfully.
sudo systemctl status mongod

# To ensure that MongoDB will start at system reboot
sudo systemctl enable mongod

# check the version
mongod --version
```

Installing MongoDB creates three default databases: **Admin**, **Config**, **Local** <br>
All the operations of installation of mongodDB described above are executed automatically in ARM template through cloud-init.

## <a name="access to MongoDB"></a>2. Import data into MongoDB with mongoimport tool
A **mongod** runs on your localhost with <ins>default port 27017</ins>.

```bash
# Start a mongosh session 
mongosh
```

You already have the Database Tools installed. The following command will determine if the Database Tools are already installed on your system:
```bash
sudo dpkg -l mongodb-database-tools
```

### NOTES:
* The default path to MongoDB's data storage is **/var/lib/mongodb** 
* The data directory **/var/lib/mongodb** and the log directory **/var/log/mongodb** are created during the installation. You can follow the state of the process for errors or important messages by watching the output in the **/var/log/mongodb/mongod.log** file. By default, MongoDB runs using the **mongodb** user account.
* The configuration file for MongoDB is located at **/etc/mongod.conf**. All the needed configurations, including the database path, logs directory, can be made in this file

To import the **listmovies.json** into MongoDB:
```bash
# import a single json file in mongodb
# The command will import all of the json file into a collection named listmovies. 
# You don't have to create the collection in advance.
# without **--drop** the mongoimport command will append. 
mongoimport --db='dbmovies' --collection='listmovies' --file='listmovies.json' --drop
```

Mongoimport will only import one file at a time with the --file option; to import all the .json files in a folder:
```bash
cat *.json | mongoimport --collection='listmovies'
```

MongoDB creates a new **_id** for each document inserted into the MongoDB collection, because they're not contained in the source data.

## <a name="MongoDB commands"></a>3. Basic MongoDB commands

| MongoDB command                     | Description                        |
| ----------------------------------- | ---------------------------------- |
| db.help                             | help                               |
| show dbs                            | get list of all databases          |
| db                                  | it knows your current working/selected database |
| use DB_NAME                         | select a specific database                     |
| db.DATABASE_NAME.count()            | number of Documents in the database            |
| db.dropDatabase()                   | drop the selected database                     |
| show collections <br> show tables   | get the list of Collections created            |
| db.getCollectionNames()             | shows all Collections as a list                |	 
| db.getCollectionInfos()             | returns information about the collection       |
| db.COLLECTION_NAME.count()          | count Documents in a Collection                |
| db.COLLECTION_NAME.countDocuments() | count Documents in a Collection (new command)  |
| db.createCollection("COLLECTION_NAME") | create the new Collection                   |
| db.COLLECTION_NAME.drop()           | drop Collection                                |
| db.COLLECTION_NAME.find()           | get Collection document. it shows all contents of that Collection |
| db.COLLECTION_NAME.find().pretty()  | need to visually tidy up the Collection        |
| db.COLLECTION_NAME.findOne()        | find the first document in a Collection        |
| db.COLLECTION_NAME.find().limit(10) | find a limited number of results               |
| db.collectionName.findOne({_id: ObjectId("3ae67d7606444f189acfba1e")}) | find a Document by ID|
| db.getUsers() <br> show users       | get a list of users |
| db.dropUser                         | delete a user       |

* If a database does not exist, MongoDB creates the database when you first store data for that database. 
* MongoDB stores documents in Collections. Collections are analogous to tables in relational databases.
* If a collection does not exist, MongoDB creates the Collection when you first store data for that Collection.

## <a name="MongoDB queries"></a>4. Few MongoDB queries with listmovies collection 
All the MongoDB queries are related to the database **dbmovies** and **listmovies** collection imported by **mongoimport** tool in the previous paragraph.

Find a document with **Director** contains "Ser":
```console
db.listmovies.find({Director:{$regex : "Ser"} })
db.listmovies.find({Director:  /.*Ser.*/ })
```
If we want the query to be case-insensitive, we can use "i" option:
```console
db.listmovies.find({Director:  /.*ser.*/i })
```
Find documents with Director contains "John Boorman":
```console
db.listmovies.find({Director : "John Boorman"})
db.listmovies.find({Director : {$eq : "John Boorman"}})
```
Find documents with **Director** contains "John Boorman" <ins>OR</ins> "Sergio Leone":
```console
db.listmovies.find(
   {$or: [{Director : "John Boorman"}, {Director : "Sergio Leone"} ]}
)
```

Find documents with **Director** contains "Sergio Leone" <ins>AND</ins> **Year** is greater that 1965:
```console
db.listmovies.find(
   {Director : "Sergio Leone", Year : {$gt : 1965}  }
)
```

Find documents with  **Year** is greater or equal to 1965:
```console
db.listmovies.find( { Year: { $gte: 1966 } })
```
Find the documents with Actor1 equal to "Clint Eastwood":
```console
db.listmovies.find(
   {"Team.Actor1" : "Clint Eastwood"}
)
```

The following operation returns all documents in the **listmovies** collection, sorted first by the **Director** field in ascending order, and then, within each **Year** field in ascending order:
```console
db.listmovies.find().sort( {Director: 1, Year: 1 })
```

The following operation returns all documents that match the **Director** field:
```console
db.listmovies.find( {}, {Director:1, _id: 0})
db.listmovies.find( {}, {Director:1, _id: 0}).sort({Director: 1})
```
The _id field is removed from the results by setting it to 0 in the projection.

List of **Director** and **Title**, ordered by **Director**:
```console
db.listmovies.find( {}, {Director:1,Title:1, _id: 0}).sort({Director: 1})
```

Return all **listmovies** but <ins>excludes</ins> fields (Team, Posterfile, Id, _id) specified in the projection:
```console
db.listmovies.find( {}, {Team:0, Posterfile:0, Id:0, _id: 0})
```

Return all documents with Director beginning with "A" OR "S":
```console
db.listmovies.find({ Director: { $in: [/^A/,/^S/] } })
```

## <a name="secure MongoDB"></a>5. Secure MongoDB
In MongoDB, Authentication is not enabled by default, implying that any user with access to the database server can view, add and delete data without any permissions. 

### <a name="Creation of MongoDB admin"></a>5.1 Create a MongoDB administrative user 
The first step is to create an administrative user. Login to the MongoDB with **mongosh** and connect to the **admin** db:
```console
use admin
```
Create the database user:
```console
db.createUser(
  {
    user: "superAdmin",
    pwd: passwordPrompt(),
    roles: [ { role: "userAdminAnyDatabase", db: "admin" }, "readWriteAnyDatabase" ]
 }
)
```
* **user: "superAdmin"** it creates an administrative user named superAdmin; this is just an arbitrary name and you should use yours and avoid trivial username
* **pwd: passwordPrompt()** a prompt asks for the password
* **roles: [ { role: "userAdminAnyDatabase", db: "admin" }, "readWriteAnyDatabase" ]** the Administrative user is granted read and write permissions to the admin database. Since this role is defined in the admin database, the administrative user, in effect, can read and modify all the databases in the cluster.<br>

To enable authorization, in the MongoDB config file **/etc/mongod.conf** uncomment the #security and set the authorization directive:
```yml
security:
  authorization: enabled
```

To apply the changes, restart the Mongo service:
```console
sudo systemctl restart mongod
sudo systemctl status mongod
```

In the local vm with MondogDB server, login with the admin credential: 
```
mongosh mongodb://superAdmin@127.0.0.1:27017
```

### <a name="Creation of MongoDB admin"></a>5.2 Configure MongoDB for remote access
By default, MongoDB is only able to accept connections from the same server where it is installed (loopback address interface). 
To enable remote access edit the MongoDB config file **/etc/mongod.conf**; locate the **net:** session and change the value of **bindIp** from 127.0.0.1 to the value 0.0.0.0
```yml
# network interfaces
net:
  port: 27017
  bindIp: 0.0.0.0
```
<br>
To apply the changes made, restart mongo daemon (mongod):
```console
sudo systemctl restart mongod
sudo systemctl status mongod
```
Login to Mongo shell:
```
mongosh
```
you will see the warning messages are disappeared. However, if you run the command **show dbs** you will get a message says "listDatabases requires authentication"<br>
Login with the admin credential: 
```
mongosh "mongodb://superAdmin@MONGO_IP_ADDRESS:27017"
```

MongoDB tools are published at: https://www.mongodb.com/try/download/shell you can grab the URLs of different tools in the web page. <br>
MongoDB Shell is the quickest way to connect to MongoDB. In the vm2, download and install the MongoDB Shell:
```bash
wget https://downloads.mongodb.com/compass/mongodb-mongosh_1.6.1_amd64.deb
sudo apt install ./mongodb-mongosh_1.6.1_amd64.deb
``` 
mongosh mongodb://superAdmin@10.0.1.10:27017


A check can be done through the log at:
```bash
tail -f /var/log/mongodb/mongod.log
``` 


## <a name="new user MongoDB"></a>6. Add a new user to MongoDB database
Create a new user with **dbOwner** build-in role in the **dbmovies** database. The database owner can perform any administrative action on the database. 
```console
use dbmovies
db.createUser(
  {
    user: "moviesAdmin",
    pwd:  "YOUR_SECRET_PASSWORD",
    roles: [{ role: "dbOwner", db: "dbmovies" }]
  }
)
```

From remote vm2 to connect into **dbmovies** in the MongoDB server running on vm1:
```
mongosh mongodb://moviesAdmin@10.0.1.10:27017/dbmovies
mongosh -u moviesAdmin -p YOUR_PASSWORD mongodb://10.0.1.10:27017/dbmovies
```

## <a name="install golang"></a>5. Install Golang in vm2
```bash
apt install -y golang-go
```
At writing time the golang release installed in ubuntu 22.04 is 1.18.1 <br>

## <a name="connect to mongoDB in Golang"></a>6. How to connect to a remote MongoDB server in Golang
In the vm2:

```bash
mkdir mycode
cd mycode
vim main.go
```
Paste the code in the vim editor the content of file main.go:

In vm2, run the following command to install MongoDB Go driver and all the dependencies:
```console
go mod init test
go mod tidy
```

**go mod tidy** ensures that the go.mod file matches the source code in the module. It adds any missing module requirements necessary to build the current module’s packages and dependencies, and it removes requirements on modules that don’t provide any relevant packages. 
**go mod tidy** works by loading all the packages in the main module and all the packages they import, recursively. 

Run the golang code:
```console
go run main.go
```


`Tags: MongoDB` <br>
`date: 28-12-22`

<!--Image References-->
[1]: ./media/diagram1.png "MongoDB diagram"
[2]: ./media/diagram2.png "MongoDB diagram"
[3]: ./media/diagram3.png "MongoDB configuration"
<!--Link References-->

