#!/bin/bash

containerName='folder1'
fileName='myfile.txt'
storageName='stggomlxxxgtmroq'
t=$(curl -s 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fstorage.azure.com%2F' -H Metadata:true | jq .access_token)
tk="${t:1:-1}"
curl https://{$storageName}.blob.core.windows.net/{$containerName}/{$fileName} -H "x-ms-version: 2017-11-09" -H "Authorization: Bearer ${tk}"
