// Key Vault
param location string = resourceGroup().location
param keyVaultName string = 's1-kv-${uniqueString(subscription().id)}'

@secure()
param adminPassword string

resource keyVault 'Microsoft.KeyVault/vaults@2021-04-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: []
  }
}

// Store the secret in Key Vault
resource secret 'Microsoft.KeyVault/vaults/secrets@2021-04-01-preview' = {
  parent: keyVault
  name: 'adminPassword'
  properties: {
    value: adminPassword
  }
}

/*

// Managed Identity
resource vmIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'azmrmz-lab-identity'
  location: location
}

output vmIdentityId string = vmIdentity.id


// Assign Key Vault access to the Managed Identity
resource kvAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2021-04-01-preview' = {
  name: '${keyVault.name}/add'
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: vmIdentity.properties.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ]
  }
}
*/
/*
// Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: vmName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${vmIdentity.id}': {}
    }
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_DS1_v2'
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: secret.properties.value
    }
 */
