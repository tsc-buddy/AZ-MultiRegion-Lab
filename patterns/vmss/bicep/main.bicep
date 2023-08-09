@sys.description('Set to true to deploy a VMSS in two regions wiht supporting Traffic Manager.')
param multiRegionDeployment bool = false

@sys.description('Specify the primary VMSS Instance admin password or SSH Key.')
@secure()
param vmssOneAdminPasswordOrKey string

@sys.description('Specify the Secondary VMSS Instance admin password or SSH Key.')
@secure()
param vmssTwoAdminPasswordOrKey string

@sys.description('Specify the primary Azure region you wish to deploy a AZ ready VMSS into.')
param primaryLocation string = 'eastus'

@sys.description('Optional - Specify the secondary Azure region you wish to deploy your second AZ ready VMSS into.')
param secondaryLocation string = 'eastus2'

@description('The names of the virtual network you wish to deploy the new VMSS instance into. The first record will be for primary VMSS, second record for secondary VMSS.')
param vnetName array = []

@description('The name of the subnet within the provided VNET that you wish to deploy the new VMSS instance into. The first record will be for primary VMSS, second record for secondary VMSS.')
param subnetName array = []

@description('The Instance count for VMSS.')
param instanceCount int = 3

@description('The VM SKU for the VMSS Instance you wish to deploy')
param vmSku string = 'Standard_D2s_v5'

@description('The local admin username for the VMSS instance.')
param adminUsername string = 'adminuser'

@description('Specify the Availability Zones you wish to deploy into')
param zones array = [
  '1'
  '2'
  '3'
]

@description('The type of OS you wish to use for the VMSS Instance.')
@allowed([
  'ubuntulinux'
  'windowsserver'
])
param os string = 'windowsserver'

@description('The admin password for the VMSS instance.')
@allowed([
  'password'
  'sshPublicKey'
])
param authenticationType string = 'password'

@description('The authentication type for the VMSS instance. This will be determined by the OS you choose.')
param vmssIdentifier array = [
  'vmss-1'
  'vmss-2'
]

@description('The name prefix for the VMSS Virtual Machines, not the VMSS Instance.')
param vmNamePrefix array = [
  'vm-1'
  'vm-2'
]

module regionOneVMSS 'modules/vmss.bicep' = {
  name: vmssIdentifier[0]
  scope: resourceGroup()
  params: {
    vmssName: '${vmssIdentifier[0]}-${uniqueString(resourceGroup().id)}'
    vmNamePrefix: vmNamePrefix[0]
    location: primaryLocation
    instanceCount: instanceCount
    vmSku: vmSku
    zones: zones
    vnetName: vnetName[0]
    subnetName: subnetName[0]
    os: os
    authenticationType: authenticationType
    adminUsername: adminUsername
    adminPasswordOrKey: vmssOneAdminPasswordOrKey
  }
}

module regionTwoVMSS 'modules/vmss.bicep' = if (multiRegionDeployment) {
  name: vmssIdentifier[1]
  scope: resourceGroup()
  params: {
    vmssName: '${vmssIdentifier[1]}-${uniqueString(resourceGroup().id)}'
    vmNamePrefix: vmNamePrefix[1]
    location: secondaryLocation
    instanceCount: instanceCount
    vmSku: vmSku
    zones: zones
    vnetName: vnetName[1]
    subnetName: subnetName[1]
    os: os
    authenticationType: authenticationType
    adminUsername: adminUsername
    adminPasswordOrKey: vmssTwoAdminPasswordOrKey
  }
}

module trafficManagerProfile 'modules/trafficManager.bicep' = if (multiRegionDeployment) {
  name: 'trafficManager'
  scope: resourceGroup()
  params: {
    tmName: 'traffic-manager-${uniqueString(resourceGroup().id)}'
    relativeName: 'tm-uniquesname'
    endpointID: [
      regionOneVMSS.outputs.publicIpID
      regionTwoVMSS.outputs.publicIpID
    ]
    endpointfqdn: [
      regionOneVMSS.outputs.publicIpFQDN
      regionTwoVMSS.outputs.publicIpFQDN
    ]
    location: [
      secondaryLocation
      primaryLocation
    ]
    endpointName: [
      regionOneVMSS.name
      regionTwoVMSS.name
    ]
  }
}
