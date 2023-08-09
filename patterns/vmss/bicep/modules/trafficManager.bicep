@description('The name of the Traffic Manager Profile.')
@minLength(1)
param tmName string

@description('The names of the endpoints.')
param endpointName array

@description('The Azure Region for each of the endpoints.')
param location array

@description('Optional. The status of the Traffic Manager profile.')
@allowed([
  'Enabled'
  'Disabled'
])
param profileStatus string = 'Enabled'

@description('Optional. The traffic routing method of the Traffic Manager profile.')
@allowed([
  'Performance'
  'Priority'
  'Weighted'
  'Geographic'
  'MultiValue'
  'Subnet'
])
param trafficRoutingMethod string = 'Performance'

@description('Required. The relative DNS name provided by this Traffic Manager profile. This value is combined with the DNS domain name used by Azure Traffic Manager to form the fully-qualified domain name (FQDN) of the profile.')
param relativeName string

@description('Optional. The DNS Time-To-Live (TTL), in seconds. This informs the local DNS resolvers and DNS clients how long to cache DNS responses provided by this Traffic Manager profile.')
param ttl int = 60

@description('Optional. The endpoint monitoring settings of the Traffic Manager profile.')
param monitorConfig object = {
  protocol: 'http'
  port: '80'
  path: '/'
}

@description('Optional. The list of endpoints in the Traffic Manager profile.')
param endpointID array
param endpointfqdn array

@description('Optional. Indicates whether Traffic View is \'Enabled\' or \'Disabled\' for the Traffic Manager profile. Null, indicates \'Disabled\'. Enabling this feature will increase the cost of the Traffic Manage profile.')
@allowed([
  'Disabled'
  'Enabled'
])
param trafficViewEnrollmentStatus string = 'Disabled'

@description('Optional. Maximum number of endpoints to be returned for MultiValue routing type.')
param maxReturn int = 1

var endpointObject = [
  {
    name: endpointName[0]
    type: 'Microsoft.Network/trafficmanagerprofiles/azureEndpoints'
    properties: {
      target: endpointfqdn[0]
      targetResourceId: endpointID[0]
      endpointStatus: 'Enabled'
      weight: 1
      priority: 1
      endpointLocation: location[0]
    }
  }
  {
    name: endpointName[1]
    type: 'Microsoft.Network/trafficmanagerprofiles/azureEndpoints'
    properties: {
      target: endpointfqdn[1]
      targetResourceId: endpointID[1]
      endpointStatus: 'Enabled'
      weight: 5
      priority: 10
      endpointLocation: location[1]
    }
  }
]



resource trafficManagerProfile 'Microsoft.Network/trafficmanagerprofiles@2018-08-01' = {
  name: tmName
  location: 'global'
  properties: {
    profileStatus: profileStatus
    trafficRoutingMethod: trafficRoutingMethod
    dnsConfig: {
      relativeName: relativeName
      ttl: ttl
    }
    monitorConfig: monitorConfig
    endpoints: endpointObject

    trafficViewEnrollmentStatus: trafficViewEnrollmentStatus
    maxReturn: maxReturn
  }
}
