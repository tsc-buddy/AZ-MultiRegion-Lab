@description('The Azure region you wish to deploy the VMSS instance into. It must support AZs.')
param location string = 'australiaeast'

@description('The IP address range for Hub Network.')
param vmssName string = 'vmss-${uniqueString(resourceGroup().id)}'

@description('The name of the virtual network you wish to deploy the new VMSS instance into.')
param vnetName string = 'vmss-vnet'

@description('The name of the subnet within the provided VNET that you wish to deploy the new VMSS instance into..')
param subnetName string = 'default'

@description('The Instance count for VMSS.')
param instanceCount int = 3

// Parameter for the VMSS Sku
@description('The SKU for the VMSS Instance you wish to deploy')
param vmSku string = 'Standard_D2s_v5'

@allowed([
  'ubuntulinux'
  'windowsserver'
])
param os string = 'windowsserver'

@description('The local admin username')
param adminUsername string = 'adminuser'

@description('The admin password for the VMSS instance.')
@allowed([
  'password'
  'sshPublicKey'
])
param authenticationType string = 'password'

@secure()
param adminPasswordOrKey string

var linuxConfiguration = {
  disablePasswordAuthentication: true
  provisionVMAgent: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}
var linuxImageReference = {
  publisher: 'Canonical'
  offer: 'UbuntuServer'
  sku: '18_04-LTS-Gen2'
  version: 'latest'
}
var windowsImageReference = {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: '2019-Datacenter'
  version: 'latest'
}
var windowsConfiguration =  {
  timeZone: 'Pacific Standard Time'
}
var networkApiVersion = '2020-11-01'
var imageReference = (os == 'ubuntulinux' ? linuxImageReference : windowsImageReference)
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

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2023-03-01' = {
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
    singlePlacementGroup: false
    platformFaultDomainCount: 1
    virtualMachineProfile: {
      osProfile: {
        computerNamePrefix: 'vmss'
        adminUsername: adminUsername
        adminPassword: (authenticationType== 'password' ? adminPasswordOrKey: null)
        linuxConfiguration: (os=='ubuntulinux' && authenticationType == 'sshPublicKey'? linuxConfiguration : null)
        windowsConfiguration: (os=='windowsserver' ? windowsConfiguration : null)
      }
      networkProfile: {
        networkApiVersion: networkApiVersion
        networkInterfaceConfigurations: [
            {
            name: '${vmssName}NicConfig01'
            properties: {
              primary: true
              enableAcceleratedNetworking: false
              ipConfigurations: [
                {
                  name: '${vmssName}IpConfig'
                  properties: {
                    privateIPAddressVersion: 'IPv4'
                    subnet: {
                      id: subnet.id
                    }
                    loadBalancerBackendAddressPools: loadBalancer.properties.backendAddressPools
                  }
                }
              ]
            }
          }
        ]
      }
      diagnosticsProfile: {
        bootDiagnostics: {
          enabled: true
        }
      }
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
        imageReference: imageReference
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
