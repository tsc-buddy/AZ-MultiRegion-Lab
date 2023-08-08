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

param vnetName string = 'vmss-vnet'
param subnetName string = 'default'
param instanceCount int = 3
param vmSku string = 'Standard_D2s_v5'

@allowed([
  'ubuntulinux'
  'windowsserver'
])
param os string = 'windowsserver'
param adminUsername string = 'adminuser'

@description('The admin password for the VMSS instance.')
@allowed([
  'password'
  'sshPublicKey'
])
param authenticationType string = 'password'

param vmSuffix array = [
  'vmss-1'
  'vmss-2'
]


module regionOneVMSS 'modules/vmss.bicep' = {
  name: 'vmss-1'
  scope: resourceGroup()
  params: {
    adminPasswordOrKey: vmssOneAdminPasswordOrKey
    location: primaryLocation
    vmssName: '${vmSuffix[0]}-${uniqueString(resourceGroup().id)}'
    vnetName: vnetName
    os: os
    subnetName: subnetName
    authenticationType: authenticationType
    adminUsername: adminUsername
    instanceCount: instanceCount
    vmSku: vmSku
    
  }
}

module regionTwoVMSS 'modules/vmss.bicep' = if (multiRegionDeployment) {
  name: 'vmss-2'
  scope: resourceGroup()
  params: {
    adminPasswordOrKey: vmssTwoAdminPasswordOrKey
    location: secondaryLocation
    vmssName: '${vmSuffix[1]}-${uniqueString(resourceGroup().id)}'
    vnetName: vnetName
    os: os
    subnetName: subnetName
    authenticationType: authenticationType
    adminUsername: adminUsername
    instanceCount: instanceCount
    vmSku: vmSku
  }
}
