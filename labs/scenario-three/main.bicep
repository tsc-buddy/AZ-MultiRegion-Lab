metadata name = 'Scenario Three'
metadata description = 'This bicep codes deploys application infrastructure for scenario three, a web based paas application with a database backend.'
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
param location string = 'australiaeast'

@secure()
param sqlpassword string

@sys.description('Creates an APPGW if True (Default: true)')
param createAppGw bool = true

var rgName = 'rg-waf-mr-lab-scenario-3'
var vnetName = 's3-vnet-${uniqueString(subscription().id)}'
var apimName = 's3-apim-${uniqueString(subscription().id)}'
var appGWName = 's3-appgw-${uniqueString(subscription().id)}'
var sqlServerName = 's3-sql-${uniqueString(subscription().id)}'
var storageAccountName = 's3sa${uniqueString(subscription().id)}'
var appServiceSpec = [
  {
    name: 's3-api-${uniqueString(subscription().id)}'
    kind: 'api'
    farmName: 's3-apiasp-${uniqueString(subscription().id)}'
  }
  {
    name: 's3-web-${uniqueString(subscription().id)}'
    kind: 'app'
    farmName: 's3-webasp-${uniqueString(subscription().id)}'
  }
]
var vnetAddressPrefix = [
  '192.168.0.0/16'
]
var subnetSpec = [
  {
    name: 'appGatewaySubnet'
    addressPrefix: '192.168.3.0/24'
  }
  {
    addressPrefix: '192.168.1.0/25'
    name: 'webSubnet'
  }
  {
    addressPrefix: '192.168.0.0/24'
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

module serverFarm 'br/public:avm/res/web/serverfarm:0.1.1' =  [for farm in appServiceSpec:{
  name: 'webASPDeploy-${farm.farmName}1'
  scope: resourceGroup
  params: {
    name: farm.farmName
    location: location
    sku: {
      capacity: 3
      family: 'Pv3'
      name: 'P1v3'
      size: 'P1v3'
      tier: 'PremiumV3'
    }
    zoneRedundant: true
  }
}
]

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
        skuName: 'GP_Gen5'
        skuTier: 'GeneralPurpose'
        skuCapacity: 3
        family: 'Gen5'
        collation: 'SQL_Latin1_General_CP1_CI_AS'
        requestedBackupStorageRedundancy: 'Geo'
        zoneredundant: 'true'
      }
      {
        name: 'appdb'
        maxSizeBytes: 2147483648
        skuName: 'GP_Gen5'
        skuTier: 'GeneralPurpose'
        skuCapacity: 3
        family: 'Gen5'
        collation: 'SQL_Latin1_General_CP1_CI_AS'
        requestedBackupStorageRedundancy: 'Geo'
        zoneredundant: 'true'

      }
    ]
    location: location
  }
}

module storageAccount 'br/public:avm/res/storage/storage-account:0.9.1' = {
  scope: resourceGroup
  name: storageAccountName
  params: {
    name: storageAccountName
    kind: 'StorageV2'
    location: location
    skuName: 'Standard_ZRS'
  }
}
module apim 'layers/apim.bicep' = {
  scope: resourceGroup
  name: 'apimDeployment-sc3'
  params: {
    apimName: apimName
    location: location
  }
}

module appGW 'layers/appgw.bicep' = if (createAppGw) {
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
 