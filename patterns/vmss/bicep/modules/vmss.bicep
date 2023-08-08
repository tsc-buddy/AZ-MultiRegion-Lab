@description('The Azure region you wish to deploy the VMSS instance into. It must support AZs.')
param location string

@description('The IP address range for Hub Network.')
param vmssName string

@description('The name prefix for the VMSS Virtual Machines, not the VMSS Instance.')
param vmNamePrefix string

@description('The name of the virtual network you wish to deploy the new VMSS instance into.')
param vnetName string

@description('The name of the subnet within the provided VNET that you wish to deploy the new VMSS instance into..')
param subnetName string

@description('The Instance count for VMSS.')
param instanceCount int

// Parameter for the VMSS Sku
@description('The SKU for the VMSS Instance you wish to deploy')
param vmSku string

@description('Specify the Zones you wish to deploy into')
param zones array

@allowed([
  'ubuntulinux'
  'windowsserver'
])
param os string

@description('The local admin username')
param adminUsername string

@description('The admin password for the VMSS instance.')
@allowed([
  'password'
  'sshPublicKey'
])
param authenticationType string

@secure()
param adminPasswordOrKey string

@description('Optional. This property can be used by user in the request to enable or disable the Host Encryption for the virtual machine. This will enable the encryption for all the disks including Resource/Temp disk at host itself. For security reasons, it is recommended to set encryptionAtHost to True. Restrictions: Cannot be enabled if Azure Disk Encryption (guest-VM encryption using bitlocker/DM-Crypt) is enabled on your virtual machine scale sets.')
param encryptionAtHost bool = true

@description('Optional. Specifies the SecurityType of the virtual machine scale set. It is set as TrustedLaunch to enable UefiSettings.')
param securityType string = ''

@description('Optional. Specifies whether secure boot should be enabled on the virtual machine scale set. This parameter is part of the UefiSettings. SecurityType should be set to TrustedLaunch to enable UefiSettings.')
param secureBootEnabled bool = false

@description('Optional. Specifies whether vTPM should be enabled on the virtual machine scale set. This parameter is part of the UefiSettings.  SecurityType should be set to TrustedLaunch to enable UefiSettings.')
param vTpmEnabled bool = false

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
  zones: zones
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
        computerNamePrefix: vmNamePrefix
        adminUsername: adminUsername
        adminPassword: (authenticationType== 'password' ? adminPasswordOrKey: null)
        linuxConfiguration: (os=='ubuntulinux' && authenticationType == 'sshPublicKey'? linuxConfiguration : null)
        windowsConfiguration: (os=='windowsserver' ? windowsConfiguration : null)
      }
      securityProfile: {
        encryptionAtHost: encryptionAtHost
        securityType: securityType
        uefiSettings: {
          secureBootEnabled: secureBootEnabled
          vTpmEnabled: vTpmEnabled
        }
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
