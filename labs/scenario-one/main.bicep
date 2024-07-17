metadata name = 'Scenario One'
metadata description = 'This bicep codes deploys application infrastructure for scenario one, a web based IaaS application with a database backend.'
targetScope = 'subscription'


@allowed([
  'eastus'
  'eastus2'
  'southcentralus'
  'westus2'
  'westus3'
  'centralus'
  'mexicocentral'
  'brazilsouth'
  'canadacentral'
  'australiaeast'
  'southeastasia'
  'centralindia'
  'eastasia' 
  'japaneast'
  'koreacentral'
  'southafricanorth'
  'northeurope'
  'swedencentral'
  'uksouth'              
  'westeurope'
  'francecentral'
  'germanywestcentral'
  'italynorth'
  'norwayeast'
  'polandcentral'
  'spaincentral'
  'switzerlandnorth'
  'uaenorth'
  'israelcentral'
  'qatarcentral'
])
@description('The Azure region you wish to deploy to. It must support availability zones.')
param location string = 'westus3'


var rgName = 'rg-waf-az-lab-scenario-one'
var vnetName = 'SpokeVNet01'
var appGWName = 's1-appgw-${uniqueString(subscription().id)}'

var vnet2Name = 'coreVNet'

@secure()
param localadminpw string

var localadmin = 'azureadmin'

var webTierSpec = [
  {
    name: 'webServ01'
    zone: 1
  }
  {
    name: 'webServ02'
    zone: 2
  }  
  {
    name: 'webServ03'
    zone: 3
  }
]
var appTierSpec = [
  {
    name: 'appServ01'
    zone: 1
  }
  {
    name: 'appServ02'
    zone: 2
  }   
  {
    name: 'appServ03'
    zone: 3
  }
]
var dataTierSpec = [
  {
    name: 'sqlServ01'
    zone: 1
  }
  {
    name: 'sqlServ02'
    zone: 2
  }  
  {
    name: 'sqlServ03'
    zone: 3
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
    addressPrefix: '172.16.1.0/25'
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
        id: subnet.id
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
            subnetResourceId: virtualNetwork.outputs.subnetResourceIds[0].id
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
  }
]

//VMs for App Tier
module virtualMachine 'br/public:avm/res/compute/virtual-machine:0.2.3' = [for app in appTierSpec: {
  scope: resourceGroup
  name: app.name
  params: {
    // Required parameters
    adminUsername: localadmin
    encryptionAtHost: false
    availabilityZone: app.zone
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
            subnetResourceId: virtualNetwork.outputs.subnetResourceIds[1].id
          }
        ]
        nicSuffix: 'nic-${app.name}'
      }
    ]
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    osType: 'Windows'
    vmSize: app.vmSize
    // Non-required parameters
    adminPassword: localadminpw
    location: location
  }
}
]

//VMs for Data Tier
module sqlvirtualMachine 'br/public:avm/res/compute/virtual-machine:0.2.3' = [for sql in dataTierSpec: {
  scope: resourceGroup
  name: sql.name
  params: {
    // Required parameters
    adminUsername: localadmin
    encryptionAtHost: false
    availabilityZone: sql.zone
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
            subnetResourceId: virtualNetwork.outputs.subnetResourceIds[2].id
          }
        ]
        nicSuffix: 'nic-${sql.name}'
      }
    ]
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    osType: 'Windows'
    vmSize: sql.vmSize
    // Non-required parameters
    adminPassword: localadmin
    location: location
  }
}
]


module appGW 'layers/appgw.bicep' = {
  scope: resourceGroup
  name: 'appGW1'
  params: {
    appGWName: appGWName
    appGWSubnetId: virtualNetwork.outputs.subnetResourceIds[0]
    bePoolName: 'web-be-pool'
    beSiteFqdn: ''
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
      for subnet in coresubnetSpec: {
        name: subnet.name
        addressPrefix: subnet.addressPrefix
        id: subnet.id
      }      
    ]
  }
}

