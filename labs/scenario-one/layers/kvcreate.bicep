// Key Vault
param location string = resourceGroup().location
param keyVaultName string = 's1-kv-2${uniqueString(subscription().id)}'

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
