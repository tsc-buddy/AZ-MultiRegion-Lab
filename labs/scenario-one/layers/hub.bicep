param remoteVNetId string
param location string

var hubVnetName = 's1-hubvnet-${uniqueString(subscription().id)}'
var erGatewayName = 's1-ergw-${uniqueString(subscription().id)}'
var azureFirewallName = 's1-azfw-${uniqueString(subscription().id)}'
var hubVnetAddressPrefix = [
  '172.17.0.0/16'
]
var hubVnetSubnetSpec = [
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

module hubVNet 'br/public:avm/res/network/virtual-network:0.1.6' = {
  name: hubVnetName
  params: {
    name: hubVnetName
    addressPrefixes: hubVnetAddressPrefix
    peerings: [
      {
        allowForwardedTraffic: true
        allowGatewayTransit: true
        allowVirtualNetworkAccess: true
        remotePeeringAllowForwardedTraffic: true
        remotePeeringAllowVirtualNetworkAccess: true
        remotePeeringEnabled: true
        remotePeeringName: 'hubToSpoke'
        remoteVirtualNetworkId: remoteVNetId
        useRemoteGateways: false
      }
    ]
    subnets: [
      for subnets in hubVnetSubnetSpec: {
        name: subnets.name
        addressPrefix: subnets.addressPrefix
      }      
    ]
  }
}

module virtualNetworkGateway 'br/public:avm/res/network/virtual-network-gateway:0.1.4' = {
  name: 'virtualNetworkGatewayDeployment'
  params: {
    // Required parameters
    gatewayType: 'ExpressRoute'
    name: erGatewayName
    skuName: 'Standard'
    vNetResourceId: hubVNet.outputs.resourceId
    // Non-required parameters
    location: location
  }
}

module azureFirewall 'br/public:avm/res/network/azure-firewall:0.4.0' = {
  name: 'azureFirewallDeployment'
  params: {
    // Required parameters
    name: azureFirewallName
    // Non-required parameters
    location: location
    virtualNetworkResourceId: hubVNet.outputs.resourceId
    azureSkuTier: 'Standard'
  }
}
