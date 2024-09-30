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
param location string

@description('Required. Enable this if you want to deploy the hub network configuration.')
param deployHub bool

@secure()
@description('The password for the local admin account on the VMs.')
param localAdminPW string

var rgName = 'rg-waf-az-lab-scenario-1'
var vnetName = 's1-spokevnet-${uniqueString(subscription().id)}'
var appGWName = 's1-appgw-${uniqueString(subscription().id)}'
var ilbName = 's1-ilb-${uniqueString(subscription().id)}'
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
    addressPrefix: '172.16.1.128/25'
  }
  {
    name: 'frontEndSubnet'
    addressPrefix: '172.16.1.0/25'
  }
  {
    name: 'appTierSubnet'
    addressPrefix: '172.16.2.0/25'
  }
  {
    name: 'dataSubnet'    
    addressPrefix: '172.16.2.128/25'
  }
]

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
}
// NSGs for web, app and data tiers

module networkSecurityGroup1 'br/public:avm/res/network/network-security-group:0.3.1' = {
  scope : resourceGroup
  name: 'nsgDeployment1'
  params: {
    // Required parameters
    name: 'webNsg'
    // Non-required parameters
    location: location
    securityRules: [
      {
        name: 'allow_appgw_inbound'
        properties: {
          access: 'Allow'
          destinationAddressPrefix: '*'  
          destinationPortRanges: [
            '65200 - 65535'
          ]
          direction: 'Inbound'
          priority: 200
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
        }
      }
      {
        name: 'allow_https_inbound'
        properties: {
          access: 'Allow'
          destinationAddressPrefix: '*'  
          destinationPortRanges: [
            '443'
            '80'
          ]
          direction: 'Inbound'
          priority: 250
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
        }
      }
    ]
    
  }
}

//Spoke Network configuration
module spokeVnet 'br/public:avm/res/network/virtual-network:0.1.6' = {
  name: vnetName
  scope: resourceGroup
  params: {
    name: vnetName
    addressPrefixes: vnetAddressPrefix
    subnets: [
      for subnet in subnetSpec: {
        name: subnet.name
        addressPrefix: subnet.addressPrefix
        networkSecurityGroupResourceId: networkSecurityGroup1.outputs.resourceId
        privateLinkServiceNetworkPolicies: 'Disabled'
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
            subnetResourceId: spokeVnet.outputs.subnetResourceIds[1]
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
    vmSize: 'Standard_D2s_v5'
    adminPassword: localAdminPW
  } 
  
  dependsOn: [
    spokeVnet
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
            subnetResourceId: spokeVnet.outputs.subnetResourceIds[2]
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
    vmSize: 'Standard_D2s_v5'
    adminPassword: localAdminPW
    tags:{
      Environment: 'Production'
      Role: 'AppServer'
    }
  }
    dependsOn: [
    spokeVnet
  ]
  }
]

// ILB for app tier

module loadBalancer 'br/public:avm/res/network/load-balancer:0.2.2' = {
  scope: resourceGroup
  name: 'loadBalancerDeployment'
  params: {
    // Required parameters
    frontendIPConfigurations: [
      {
        name: 'privateIPConfig1'
        subnetId: spokeVnet.outputs.subnetResourceIds[2]
      }
    ]
    name: ilbName
    // Non-required parameters
    backendAddressPools: [
      {
        name: 'servers'
      }
    ]
    inboundNatRules: [
      {
        backendPort: 443
        enableFloatingIP: false
        enableTcpReset: false
        frontendIPConfigurationName: 'privateIPConfig1'
        frontendPort: 443
        idleTimeoutInMinutes: 4
        name: 'inboundNatRule1'
        protocol: 'Tcp'
      }
      {
        backendPort: 3389
        frontendIPConfigurationName: 'privateIPConfig1'
        frontendPort: 3389
        name: 'inboundNatRule2'
      }
    ]
    loadBalancingRules: [
      {
        backendAddressPoolName: 'servers'
        backendPort: 0
        disableOutboundSnat: true
        enableFloatingIP: true
        enableTcpReset: false
        frontendIPConfigurationName: 'privateIPConfig1'
        frontendPort: 0
        idleTimeoutInMinutes: 4
        loadDistribution: 'Default'
        name: 'privateIPLBRule1'
        probeName: 'probe1'
        protocol: 'All'
      }
    ]
    location: location
    probes: [
      {
        intervalInSeconds: 5
        name: 'probe1'
        numberOfProbes: 2
        port: '62000'
        protocol: 'Tcp'
      }
    ]
    skuName: 'Standard'
    }
}

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
            subnetResourceId: spokeVnet.outputs.subnetResourceIds[3]
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
    vmSize: 'Standard_D4s_v5'
    adminPassword: localAdminPW
  } 
  dependsOn: [
    spokeVnet
  ]
  }
]

module appGW1 'layers/appgw.bicep' = {
  scope: resourceGroup
  name: 'appGW1'
  params: {
    appGWName: appGWName
    appGWSubnetId: spokeVnet.outputs.subnetResourceIds[0]
    bePoolName: 'web-be-pool'
    location: location
  }
}
//create Key Vault
module kvcreate 'layers/kvcreate.bicep' = {
  scope: resourceGroup
  name : 'keyvault'
  params: {
    location: location
    adminPassword: localAdminPW
  }

}

module hubConfiguration 'layers/hub.bicep' = if (deployHub) {
  scope: resourceGroup
  name: 'hubConfiguration'
  params: {
    location: location
    remoteVNetId: spokeVnet.outputs.resourceId
  }
}
