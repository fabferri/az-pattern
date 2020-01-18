https://github.com/Azure/azure-quickstart-templates/blob/master/1-CONTRIBUTION-GUIDE/best-practices.md


        {
            "type": "Microsoft.Network/localNetworkGateways",
            "name": "[variables('localGatewayName11')]",
            "apiVersion": "2019-06-01",
            "comments": "public IP of remote IPSec peer",
            "location": "[variables('location2')]",
            "dependsOn": [],
            "properties": {
                "gatewayIpAddress": "[reference(variables('gateway1PublicIP1Id'),'2017-10-01').ipAddress]",
                "bgpSettings": {
                    "asn": "[variables('asnGtw1')]",
                    "bgpPeeringAddress": "[first(split( reference(resourceId('Microsoft.Network/virtualNetworkGateways',variables('gateway1Name')),'2017-10-01').bgpSettings.bgpPeeringAddress , ','))]",
                    // "[split( reference(resourceId('Microsoft.Network/virtualNetworkGateways',variables('gateway1Name'))).bgpSettings.bgpPeeringAddress , ',')[0]]",
                    //"[variables('gtw2RemotebgpPeeringAddress')]",
                    "peerWeight": 0
                }
            }
        },