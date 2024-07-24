metadata name = 'Scenario One'
metadata description = 'This bicep codes deploys application infrastructure for scenario one, a web based IaaS application with a database backend.'
targetScope = 'subscription'

param location string = 'eastus2'

var rgName1 = 'rg-waf-az-lab-scenario-1-core'
var rgName2 = 'rg-waf-az-lab-scenario-1-web'
var rgName3 = 'rg-waf-az-lab-scenario-1-app'
var rgname4 = 'rg-waf-az-lab-scenario-1-data'
var vnetName = 'SpokeVNet01'
var appGWName = 's1-appgw-${uniqueString(subscription().id)}'
var vnet2Name = 'coreVNet'
var ilbName = 's1-ilb-${uniqueString(subscription().id)}'
var ergatewayname = 's1-ergw-${uniqueString(subscription().id)}'

@secure()
param localadminpw string

var localadmin = 'azureadmin'

resource resourceGroup1 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName1
  location: location
}
resource resourceGroup2 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName2
  location: location
}
resource resourceGroup3 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName3
  location: location
}
resource resourceGroup4 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgname4
  location: location
}

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


// NSGs for web, app and data tiers

module networkSecurityGroup1 'br/public:avm/res/network/network-security-group:0.3.1' = {
  scope : resourceGroup2
  name: 'nsgDeployment1'
  params: {
    // Required parameters
    name: 'webNsg'
    // Non-required parameters
    location: resourceGroup2.location 
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
          destinationAddressPrefix: '*'    //everything else
          destinationPortRanges: [
            '443'
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


var vnetAddressPrefix = [
  '172.16.0.0/16'
]
var subnetSpec = [
  {
    name: 'appGatewaySubnet'
    addressPrefix: '172.16.1.144/28'
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

//Spoke Network configuration
module virtualNetwork 'br/public:avm/res/network/virtual-network:0.1.6' = {
  name: vnetName
  scope: resourceGroup1
  params: {
    name: vnetName
    addressPrefixes: vnetAddressPrefix
    subnets: [
      for subnet in subnetSpec: {
        name: subnet.name
        addressPrefix: subnet.addressPrefix
        networkSecurityGroupResourceId:  networkSecurityGroup1.outputs.resourceId
      }      
    ]
  }
}

//VMs for Web Tier
module webvirtualMachine 'br/public:avm/res/compute/virtual-machine:0.5.3' = [for webserver in webTierSpec: {
  name: webserver.name
  scope: resourceGroup2
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
  scope: resourceGroup3
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
    tags:{
      Environment: 'Production'
      Role: 'AppServer'
    }
  }
    dependsOn: [
    virtualNetwork
  ]
  }
]

// ILB for app tier

module loadBalancer 'br/public:avm/res/network/load-balancer:0.2.2' = {
  scope: resourceGroup3
  name: 'loadBalancerDeployment'
  params: {
    // Required parameters
    frontendIPConfigurations: [
      {
        name: 'privateIPConfig1'
        subnetId: virtualNetwork.outputs.subnetResourceIds[2]
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
  scope: resourceGroup4
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
  scope: resourceGroup2
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
  scope: resourceGroup1
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
  scope: resourceGroup2
  name : 'keyvault'
  params: {
    location: resourceGroup2.location
    adminPassword: localadminpw
  }

}

// gateway create
module virtualNetworkGateway 'br/public:avm/res/network/virtual-network-gateway:0.1.4' = {
  scope: resourceGroup1
  name: 'virtualNetworkGatewayDeployment'
  params: {
    // Required parameters
    gatewayType: 'ExpressRoute'
    name: ergatewayname
    skuName: 'Standard'
    vNetResourceId: coreVirtualNetwork.outputs.resourceId
    // Non-required parameters
    location: resourceGroup1.location
  }
}
