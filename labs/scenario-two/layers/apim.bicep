@description('The Azure region you wish to deploy to.')
param location string

@description('Optional. Tags of the resource.')
param tags object?

@description('Optional. Tags of the resource.')
param subnetId string

@description('The name of the APIM instance')
param apimName string

@description('The SKU Name for APIM')
param apimSku string

@description('The SKU instances for APIM')
param apimSkuCount int

module service 'br/public:avm/res/api-management/service:0.1.7' = {
  name: 'serviceDeployment'
  params: {
    // Required parameters
    name: apimName
    publisherEmail: 'apimgmt-noreply@mail.windowsazure.com'
    publisherName: 'az-amorg-x-001'
    // Non-required parameters
    sku: apimSku
    skuCount: apimSkuCount
    virtualNetworkType: 'External'
    subnetResourceId: subnetId
    apis: [
      {
        apiVersionSet: {
          name: 'echo-version-set'
          properties: {
            description: 'echo-version-set'
            displayName: 'echo-version-set'
            versioningScheme: 'Segment'
          }
        }
        displayName: 'Echo API'
        name: 'echo-api'
        path: 'echo'
        serviceUrl: 'http://echoapi.cloudapp.net/api'
      }
    ]
    authorizationServers: {
      secureList: [
        {
          authorizationEndpoint: '<authorizationEndpoint>'
          clientId: 'apimclientid'
          clientRegistrationEndpoint: 'http://localhost'
          clientSecret: '<clientSecret>'
          grantTypes: [
            'authorizationCode'
          ]
          name: 'AuthServer1'
          tokenEndpoint: '<tokenEndpoint>'
        }
      ]
    }
    backends: [
      {
        name: 'backend'
        tls: {
          validateCertificateChain: false
          validateCertificateName: false
        }
        url: 'http://echoapi.cloudapp.net/api'
      }
    ]
    identityProviders: [
      {
        allowedTenants: [
          'mytenant.onmicrosoft.com'
        ]
        authority: '<authority>'
        clientId: 'apimClientid'
        clientSecret: 'apimSlientSecret'
        name: 'aad'
        signinTenant: 'mytenant.onmicrosoft.com'
      }
    ]
    location: location
    managedIdentities: {
      systemAssigned: true
      userAssignedResourceIds: []
    }
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
            name: 'echo-api'
          }
        ]
        approvalRequired: false
        groups: [
          {
            name: 'developers'
          }
        ]
        name: 'Starter'
        subscriptionRequired: false
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
