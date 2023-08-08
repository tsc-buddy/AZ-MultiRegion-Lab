@sys.description('Set to true to deploy a VMSS in two regions wiht supporting Traffic Manager.')
param multiRegionDeployment bool = true

@sys.description('Specify the primary VMSS Instance admin password or SSH Key.')
@secure()
param vmssOneAdminPasswordOrKey string

@sys.description('Specify the Secondary VMSS Instance admin password or SSH Key.')
@secure()
param vmssTwoAdminPasswordOrKey string

@sys.description('Specify the primary Azure region you wish to deploy a AZ ready VMSS into.')
param primaryLocation string = 'australiaeast'

@sys.description('Optional - Specify the secondary Azure region you wish to deploy your second AZ ready VMSS into.')
param secondaryLocation string = 'australiaeast'

@description('The names of the virtual network you wish to deploy the new VMSS instance into. The first record will be for primary VMSS, second record for secondary VMSS.')
param vnetName array = [
  'vmss-vnet'
]

@description('The name of the subnet within the provided VNET that you wish to deploy the new VMSS instance into. The first record will be for primary VMSS, second record for secondary VMSS.')
param subnetName array = [
  'default'
]

@description('The Instance count for VMSS.')
param instanceCount int = 3

@description('The SKU for the VMSS Instance you wish to deploy')
param vmSku string = 'Standard_D2s_v5'

@description('The local admin username')
param adminUsername string = 'adminuser'

@description('Specify the Zones you wish to deploy into')
param zones array = [
  '1'
  '2'
  '3'
]

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

@description('Used to give each VMSS Instance a unique name')
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
  name: 'vmss-1'
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
  name: 'vmss-2'
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
