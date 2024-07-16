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
var vnetName = 's1-vnet-${uniqueString(subscription().id)}'
var appGWName = 's1-appgw-${uniqueString(subscription().id)}'

@secure()
param localadminpw string

var localadmin = 'azureadmin'

var webTierSpec = [
  {
    name: 's1-webvm-1'
    zone: '1'
  }
  {
    name: 's1-webvm-2'
    zone: '2'
}  
{
    name: 's1-webvm-3'
    zone: '3'
}
]
var appTierSpec = [
  {
    name: 's1-appvm-1'
    zone: '1'
  }
  {
    name: 's1-appvm-2'
    zone: '2'
}  
{
    name: 's1-appvm-3'
    zone: '3'
}
]
var dataTierSpec = [
  {
    name: 's1-sqlvm-1'
    zone: '1'
  }
  {
    name: 's1-sqlvm-2'
    zone: '2'
}  
{
    name: 's1-sqlvm-3'
    zone: '3'
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

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.1.6' = {
  name: 'vnetDeployment1'
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


module webvirtualMachine 'br/public:avm/res/compute/virtual-machine:0.5.3' = [for webserver in webTierSpec: {
  name: webserver.name
  params: {
    // Required parameters
    adminUsername: localadmin
    availabiltyZone: webserver.zone
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
            subnetResourceId: subnet.id
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
  } 
  }
]

module virtualMachine 'br/public:avm/res/compute/virtual-machine:0.2.3' = [for vm in vmSpec: {
  name: vm.name
  params: {
    // Required parameters
    adminUsername: adminUsername
    encryptionAtHost: false
    availabilityZone: vm.az
    imageReference: {
      offer: 'WindowsServer'
      publisher: 'MicrosoftWindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: 'latest'
    }
    name: vm.name
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: vnet1.properties.subnets[0].id
          }
        ]
        nicSuffix: 'nic-${vm.name}'
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
    vmSize: vm.vmSize
    // Non-required parameters
    adminPassword: adminPassword
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
    beSiteFqdn: appServices[1].outputs.defaultHostname
    location: location
  }
}
