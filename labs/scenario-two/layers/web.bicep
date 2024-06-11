param location string
param aspName string
param appServiceName string
param appServiceKind string
param subnetId string
param privateDNSZoneId string


module serverFarm 'br/public:avm/res/web/serverfarm:0.1.1' =  {
  name: 'webASPDeployment'
  params: {
    name: aspName
    location: location
    sku: {
      capacity: 1
      family: 'S'
      name: 'S1'
      size: 'S1'
      tier: 'Standard'
    }
  }
}

module appService 'br/public:avm/res/web/site:0.3.6' = {
  name: 'AppDeployment'
  params: {
    kind: appServiceKind
    location: location
    name: appServiceName
    serverFarmResourceId: serverFarm.outputs.resourceId
    privateEndpoints: [
      {
        privateDnsZoneResourceIds: [
          privateDNSZoneId
        ]
        subnetResourceId: subnetId
        tags: {
          Environment: 'lab'
        }
      }
    ]
  }
}

output appServiceEndpoint string = appService.outputs.defaultHostname
