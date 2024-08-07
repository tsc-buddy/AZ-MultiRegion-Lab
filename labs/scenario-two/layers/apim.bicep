param tags object?
param location string
param apimName string
var managedIdentityName = 's2-apim-mi'

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: managedIdentityName
  location: location
}

module service 'br/public:avm/res/api-management/service:0.2.1' = {
  name: apimName
  params: {
    // Required parameters
    name: apimName
    publisherEmail: 'apimgmt-noreply@mail.windowsazure.com'
    publisherName: 'az-amorg-x-001'
    sku: 'Premium'
    skuCount: 2
    zones: [
      1
      2
    ]
    apis: [
      {
        apiVersionSet: {
          name: 'acme-api-version-set'
          properties: {
            description: 'An echo API version set'
            displayName: 'ACME Echo API'
            versioningScheme: 'Segment'
          }
        }
        description: 'An Acme API service'
        displayName: 'ACME-API'
        name: 'acme-api'
        path: 'acme-echo'
        serviceUrl: 'https://echoapi.cloudapp.net/api'
      }
    ]
    backends: [
      {
        name: 'backend'
        tls: {
          validateCertificateChain: false
          validateCertificateName: false
        }
        url: 'https://echoapi.cloudapp.net/api'
      }
    ]
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'True'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA256': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_GCM_SHA256': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA256': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
    }
    location: location
    managedIdentities: {
      systemAssigned: true
      userAssignedResourceIds: [
        managedIdentity.id
      ]
    }
    minApiVersion: '2022-08-01'
    namedValues: [
      {
        displayName: 'apimkey'
        name: 'apimkey'
        secret: true
      }
    ]
    policies: [
      {
        format: 'xml'
        value: '<policies> <inbound> <rate-limit-by-key calls=\'250\' renewal-period=\'60\' counter-key=\'@(context.Request.IpAddress)\' /> </inbound> <backend> <forward-request /> </backend> <outbound> </outbound> </policies>'
      }
    ]
    portalsettings: [
      {
        name: 'signin'
        properties: {
          enabled: false
        }
      }
      {
        name: 'signup'
        properties: {
          enabled: false
          termsOfService: {
            consentRequired: false
            enabled: false
          }
        }
      }
    ]
    products: [
      {
        apis: [
          {
            name: 'acme-api'
          }
        ]
        approvalRequired: true
        description: 'This is an acme echo API'
        displayName: 'ACME-API'
        groups: [
          {
            name: 'developers'
          }
        ]
        name: 'acme-api'
        subscriptionRequired: true
        terms: 'By accessing or using the services provided by Echo API through Azure API Management, you agree to be bound by these Terms of Use. These terms may be updated from time to time, and your continued use of the services constitutes acceptance of any changes.'
      }
    ]
    subscriptions: [
      {
        name: 'testArmSubscriptionAllApis'
        scope: '/apis'
      }
    ]
    tags: tags
  }
}
