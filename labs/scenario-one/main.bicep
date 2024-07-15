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

@secure()
param sqlpassword string

var rgName = 'rg-waf-az-lab-scenario-one'
var vnetName = 's1-vnet-${uniqueString(subscription().id)}'
var appGWName = 's1-appgw-${uniqueString(subscription().id)}'
var frontEndTierSpec = [
  {
    name: 's1-api-${uniqueString(subscription().id)}'
    kind: 'api'
    farmName: 's1-apiasp-${uniqueString(subscription().id)}'
  }
  {
    name: 's1-web-${uniqueString(subscription().id)}'
    kind: 'app'
    farmName: 's1-webasp-${uniqueString(subscription().id)}'
  }
]
var appTierSpec = [
  {
    name: 's1-api-${uniqueString(subscription().id)}'
    kind: 'api'
    farmName: 's1-apiasp-${uniqueString(subscription().id)}'
  }
  {
    name: 's1-web-${uniqueString(subscription().id)}'
    kind: 'app'
    farmName: 's1-webasp-${uniqueString(subscription().id)}'
  }
]

var dataTierSpec = [
  {
    name: 's1-api-${uniqueString(subscription().id)}'
    kind: 'api'
    farmName: 's1-apiasp-${uniqueString(subscription().id)}'
  }
  {
    name: 's1-web-${uniqueString(subscription().id)}'
    kind: 'app'
    farmName: 's1-webasp-${uniqueString(subscription().id)}'
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

module virtualMachine 'br/public:avm/res/compute/virtual-machine:<version>' = {
  name: 'virtualMachineDeployment'
  params: {
    // Required parameters
    adminUsername: 'localAdminUser'
    imageReference: {
      offer: 'WindowsServer'
      publisher: 'MicrosoftWindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: 'latest'
    }
    name: 'cvmwinmin'
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: ''
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
    zone: 0
    // Non-required parameters
    adminPassword: 'davenewadmin'
    location: 'wetus3'
  }
}

module appServices 'br/public:avm/res/web/site:0.3.6' = [for (app, i) in appServiceSpec: {
  name: 'appDeploy-${app.name}1'
  scope: resourceGroup
  params: {
    kind: app.kind
    location: location
    name: app.name
    serverFarmResourceId: serverFarm[i].outputs.resourceId
    privateEndpoints: [
      {
        privateDnsZoneResourceIds: [
          webPrivateDnsZone.outputs.resourceId
        ]
        subnetResourceId: virtualNetwork.outputs.subnetResourceIds[1]
        tags: {
          Environment: 'lab'
        }
      }
    ]
  }
}]

module webPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.3.0' = {
  name: 'apiPrivateDnsZoneDeployment1'
  scope: resourceGroup
  params: {
    name: 'privatelink.azurewebsites.net'
    location: 'global'
    virtualNetworkLinks: [
      {
        name: 'webVnetLink'
        registrationEnabled: true
        virtualNetworkResourceId: virtualNetwork.outputs.resourceId
      }
    ]
  }
}
 
module sqlServer 'br/public:avm/res/sql/server:0.4.0' = {
  name: 'sqlServerDeployment1'
  scope: resourceGroup
  params: {
    // Required parameters
    name: sqlServerName
    // Non-required parameters
    administratorLogin: 'sqladmin'
    administratorLoginPassword: sqlpassword
    databases: [
      {
        name: 'azlabdb'
        maxSizeBytes: 2147483648
        skuName: 'Standard'
        skuTier: 'Standard'
      }
      {
        name: 'appdb'
        maxSizeBytes: 2147483648
        skuName: 'Standard'
        skuTier: 'Standard'

      }
    ]
    location: location
  }
}



/* module apim 'layers/apim.bicep' = {
  scope: resourceGroup
  name: 'apimDeployment-s1'
  params: {
    apimName: apimName
    location: location
  }
}
 */
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
