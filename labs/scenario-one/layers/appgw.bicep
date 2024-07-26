
param location string
param appGWName string
param tags object?
param bePoolName string
param appGWSubnetId string
var appGWPIPName = 'r-agwpip-${uniqueString(subscription().id)}'


resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: appGWPIPName
  location: location
  sku: {
    name: 'Standard'
  }
  
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

module appGW 'br/public:avm/res/network/application-gateway:0.1.0' = {
    name: 'appGW'
    params: {
      location: location
      name: appGWName
      backendAddressPools: [
        {
          name: bePoolName
          properties: {
            backendAddresses: []
          }
        }
      ]
      backendHttpSettingsCollection: [
        {
          name: 'appServiceBackendHttpsSetting'
          properties: {
            cookieBasedAffinity: 'Disabled'
            pickHostNameFromBackendAddress: true
            port: 443
            protocol: 'Https'
            requestTimeout: 30
          }
        }
      ]
      enableHttp2: true
      frontendIPConfigurations: [
        {
          name: 'public'
          properties: {
            publicIPAddress: {
              id: publicIPAddress.id
            }
          }
        }
        {
          name: 'private'
          properties: {
            privateIPAddress: '172.16.1.180'
            privateIPAllocationMethod: 'Static'
          subnet: {
            id: appGWSubnetId
          }
          }
        }
      ]
      frontendPorts: [
        {
          name: 'port80'
          properties: {
            port: 80
          }
        }
      ]
      gatewayIPConfigurations: [
        {
          name: 'apgw-ip-configuration'
          properties: {
            subnet: {
              id: appGWSubnetId
            }
          }
        }
      ]
      httpListeners: [
        {
          name: 'public80'
          properties: {
            frontendIPConfiguration: {
              id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGWName, 'public')
            }
            frontendPort: {
              id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGWName, 'port80')
            }
            hostNames: []
            protocol: 'http'
            requireServerNameIndication: false
            customErrorConfigurations: []
          }
        }
        {
          name: 'private80'
          properties: {
            frontendIPConfiguration: {
              id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGWName, 'private')
            }
            frontendPort: {
              id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGWName, 'port80')
            }
            hostNames: []
            protocol: 'http'
            requireServerNameIndication: false
            customErrorConfigurations: []
          }
        }

      ]
      probes: []
      redirectConfigurations: []
      requestRoutingRules: [
        {
          name: 'public443-appServiceBackendHttpsSetting-appServiceBackendHttpsSetting'
          properties: {
            backendAddressPool: {
              id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGWName, bePoolName)
              
            }
            backendHttpSettings: {
              id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGWName, 'appServiceBackendHttpsSetting')
            }
            httpListener: {
              id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGWName, 'public80')
            }
            priority: 200
            ruleType: 'Basic'
          }
        }
        {
          name: 'private443-appServiceBackendHttpsSetting-appServiceBackendHttpsSetting'
          properties: {
            backendAddressPool: {
              id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGWName, bePoolName)
              
            }
            backendHttpSettings: {
              id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGWName, 'appServiceBackendHttpsSetting')
            }
            httpListener: {
              id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGWName, 'private80')
            }
            priority: 400
            ruleType: 'Basic'
          }
        }
      ]
      sku: 'Standard_v2'
      tags: tags
    }
  }
