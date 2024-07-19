metadata name = 'Scenario One'
metadata description = 'This bicep codes deploys application infrastructure for scenario one, a web based IaaS application with a database backend.'
targetScope = 'subscription'

param location string = 'eastus2'

var rgName = 'rg-waf-az-lab-scenario-1'
var vnetName = 'SpokeVNet01'
var appGWName = 's1-appgw-${uniqueString(subscription().id)}'
var vnet2Name = 'coreVNet'
var firewallName = 's1-fw-${uniqueString(subscription().id)}'
var ergatewayname = 's1-ergw-${uniqueString(subscription().id)}'

@secure()
param localadminpw string

var localadmin = 'azureadmin'

var webTierSpec = [
  {
    name: 'webServ01'
    zone: 0
  }
  {
    name: 'webServ02'
    zone: 0
  }  
  {
    name: 'webServ03'
    zone: 0
  }
]
var appTierSpec = [
  {
    name: 'appServ01'
    zone: 0
  }
  {
    name: 'appServ02'
    zone: 0
  }   
  {
    name: 'appServ03'
    zone: 0
  }
]
var dataTierSpec = [
  {
    name: 'sqlServ01'
    zone: 0
  }
  {
    name: 'sqlServ02'
    zone: 0
  }  
  {
    name: 'sqlServ03'
    zone: 0
  }
]

var vnetAddressPrefix = [
  '172.16.0.0/16'
]
var subnetSpec = [
  {
    name: 'appGatewaySubnet'
    addressPrefix: '172.16.3.0/24'
  }
  {
    addressPrefix: '172.16.1.0/25'
    name: 'frontEndSubnet'
  }
  {
    addressPrefix: '172.16.2.0/25'
    name: 'appTierSubnet'
  }
  {
    addressPrefix: '172.16.0.0/24'
    name: 'dataSubnet'
  }
]


resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
}

//Spoke Network configuration
module virtualNetwork 'br/public:avm/res/network/virtual-network:0.1.6' = {
  name: vnetName
  scope: resourceGroup
  params: {
    name: vnetName
    addressPrefixes: vnetAddressPrefix
    subnets: [
      for subnet in subnetSpec: {
        name: subnet.name
        addressPrefix: subnet.addressPrefix
      }      
    ]
  }
}

//VMs for Web Tier
module webvirtualMachine 'br/public:avm/res/compute/virtual-machine:0.5.3' = [for webserver in webTierSpec: {
  name: webserver.name
  scope: resourceGroup
  params: {
    // Required parameters
    adminUsername: localadmin
    zone: webserver.zone
    imageReference: {
      offer: 'WindowsServer'
      publisher: 'MicrosoftWindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: 'latest'
    }
    name: webserver.name
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: virtualNetwork.outputs.subnetResourceIds[1]
          }
        ]
        nicSuffix: '-nic-01'
      }
    ]
    encryptionAtHost: false
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Standard_LRS'
      }
    }
    osType: 'Windows'
    vmSize: 'Standard_DS2_v2'
    adminPassword: localadminpw
  } 
  
  dependsOn: [
    virtualNetwork
  ]
  }
]

//VMs for App Tier
module virtualMachine 'br/public:avm/res/compute/virtual-machine:0.5.3' = [for app in appTierSpec: {
  scope: resourceGroup
  name: app.name
  params: {
    // Required parameters
    adminUsername: localadmin
    encryptionAtHost: false
    zone: app.zone
    imageReference: {
      offer: 'WindowsServer'
      publisher: 'MicrosoftWindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: 'latest'
    }
    name: app.name
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: virtualNetwork.outputs.subnetResourceIds[2]
          }
        ]
        nicSuffix: '-nic-01'
      }
    ]
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Standard_LRS'
      }
    }
    osType: 'Windows'
    vmSize: 'Standard_DS2_v2'
    adminPassword: localadminpw
  } 
  dependsOn: [
    virtualNetwork
  ]
  }
]

//VMs for Data Tier
module sqlvirtualMachine 'br/public:avm/res/compute/virtual-machine:0.5.3' = [for sql in dataTierSpec: {
  scope: resourceGroup
  name: sql.name
  params: {
    // Required parameters
    adminUsername: localadmin
    encryptionAtHost: false
    zone: sql.zone
    imageReference: {
      offer: 'WindowsServer'
      publisher: 'MicrosoftWindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: 'latest'
    }
    name: sql.name
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: virtualNetwork.outputs.subnetResourceIds[3]
          }
        ]
        nicSuffix: '-nic-01'
      }
    ]
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Standard_LRS'
      }
    }
    osType: 'Windows'
    vmSize: 'Standard_DS2_v2'
    adminPassword: localadminpw
  } 
  dependsOn: [
    virtualNetwork
  ]
  }
]

module appGW1 'layers/appgw.bicep' = {
  scope: resourceGroup
  name: 'appGW1'
  params: {
    appGWName: appGWName
    appGWSubnetId: virtualNetwork.outputs.subnetResourceIds[0]
    bePoolName: 'web-be-pool'
    beSiteFqdn: '172.16.3.4'
    location: location
  }
}

//Setting up Core VNet

var corevnetAddressPrefix = [
  '172.17.0.0/16'
]
var coresubnetSpec = [
  {
    name: 'coreSubnet'
    addressPrefix: '172.17.0.0/24'
  }
  {
    addressPrefix: '172.17.1.0/25'
    name: 'GatewaySubnet'
  }
  {
    addressPrefix: '172.17.2.0/25'
    name: 'AzureFirewallSubnet'
  }
]

module coreVirtualNetwork 'br/public:avm/res/network/virtual-network:0.1.6' = {
  name: vnet2Name
  scope: resourceGroup
  params: {
    name: vnet2Name
    addressPrefixes: corevnetAddressPrefix
    subnets: [
      for subnets in coresubnetSpec: {
        name: subnets.name
        addressPrefix: subnets.addressPrefix
      }      
    ]
  }
}

//create Key Vault
module kvcreate 'layers/kvcreate.bicep' = {
  scope: resourceGroup
  name : 'keyvault'
  params: {
    location: resourceGroup.location
    adminPassword: localadminpw
  }

}
/*
 //create Firewall
 module azureFirewall 'br/public:avm/res/network/azure-firewall:0.3.2' = {
  scope: resourceGroup
  name: firewallName
  params: {
    // Required parameters
    name: ''
    // Non-required parameters
    location: resourceGroup.location
    virtualNetworkResourceId: coreVirtualNetwork.outputs.subnetResourceIds[2]
  }
}
*/

// gateway create
module virtualNetworkGateway 'br/public:avm/res/network/virtual-network-gateway:0.1.4' = {
  scope: resourceGroup
  name: 'virtualNetworkGatewayDeployment'
  params: {
    // Required parameters
    gatewayType: 'ExpressRoute'
    name: ergatewayname
    skuName: 'Standard'
    vNetResourceId: coreVirtualNetwork.outputs.resourceId
    // Non-required parameters
    location: resourceGroup.location
  }
}
