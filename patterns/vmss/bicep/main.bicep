@sys.description('The Azure region you wish to deploy the VMSS instance into. It must support AZs.')
param location string = 'australiaeast'

@sys.description('The IP address range for Hub Network.')
param vmssName string = 'vmss-${uniqueString(resourceGroup().id)}'

@sys.description('The name of the virtual network you wish to deploy the new VMSS instance into.')
param vnetName string = 'vmss-vnet'

@sys.description('The name of the subnet within the provided VNET that you wish to deploy the new VMSS instance into..')
param subnetName string = 'default'

@sys.description('The Instance count for VMSS.')
param instanceCount int = 3

// Parameter for the VMSS Sku
@sys.description('The SKU for the VMSS Instance you wish to deploy')
param vmSku string = 'Standard_DS1_v2'

@sys.description('The local admin username')
param adminUsername string = 'adminuser'

@sys.description('The admin password for the VMSS instance.')
@secure()
param adminPassword string

var lbName  = '${vmssName}-lb'
var lbFrontEndName = '${vmssName}-lb-frontend'
var lbBackEndName = '${vmssName}-lb-backend'
var lbProbeName = '${vmssName}-lb-probe'

// References an existing virtual network resource
resource vnet 'Microsoft.Network/virtualNetworks@2023-02-01' existing = {
  name: vnetName
}

// References the subnet resource within the virtual network resource you wish to deploy into.
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-02-01' existing = {
  name: subnetName
  parent: vnet
}

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2022-11-01' = {
  name: vmssName
  location: location
  zones: [
    '1'
    '2'
    '3'
  ]
  sku: {
    name: vmSku
    capacity: instanceCount
  }
  properties: {
    orchestrationMode: 'Flexible'
    platformFaultDomainCount: 1
    upgradePolicy: {
      mode: 'Automatic'
    }
    virtualMachineProfile: {
      storageProfile: {
        imageReference: {
          publisher: 'Canonical'
          offer: 'UbuntuServer'
          sku: '16.04-LTS'
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
        }
      }
      osProfile: {
        computerNamePrefix: 'vmss'
        adminUsername: adminUsername
        adminPassword: adminPassword
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: '${vmssName}-nicconfig'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: '${vmssName}-ipconfig'
                  properties: {
                    subnet: {
                      id: subnet.id
                    }
                    primary: true
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}

//Create a public IP
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-02-01' = {
  name: '${vmssName}-pip'
  location: location
  zones: [
    '1'
    '2'
    '3'
  ]
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2023-02-01' = {
  name: lbName
  location: location
  sku: {
    name: 'Standard'
  }
  properties:  {
    frontendIPConfigurations: [
      {
        name: lbFrontEndName
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: lbBackEndName
      }
    ]
    probes: [
      {
        name: lbProbeName
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    loadBalancingRules: [
      {
        name: '${vmssName}-lb-rule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, lbFrontEndName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, lbBackEndName)
          }
          protocol: 'tcp'
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 5
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', lbName, lbProbeName)
          }
        }
      }
    ]
  }
}
