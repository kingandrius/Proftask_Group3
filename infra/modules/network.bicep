@description('Azure region for network resources')
param location string

@description('Environment name (test or prod)')
param envName string

@description('VNet CIDR prefix (must not overlap with Vladimir hub VNet)')
param vnetAddressPrefix string

@description('Subnet CIDR for Azure Container Apps Environment')
param acaSubnetPrefix string

@description('Subnet CIDR for PostgreSQL Flexible Server')
param dbSubnetPrefix string

@description('Common resource tags')
param tags object

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-fonteyn-g3-${envName}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-aca'
        properties: {
          addressPrefix: acaSubnetPrefix
          delegations: [
            {
              name: 'Microsoft.App.environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: 'snet-db'
        properties: {
          addressPrefix: dbSubnetPrefix
          delegations: [
            {
              name: 'Microsoft.DBforPostgreSQL.flexibleServers'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
            }
          ]
        }
      }
    ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'fonteyn-g3-${envName}.private.postgres.database.azure.com'
  location: 'global'
  tags: tags
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  name: 'link-vnet-fonteyn-g3-${envName}'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

output vnetId string = vnet.id
output acaSubnetId string = vnet.properties.subnets[0].id
output dbSubnetId string = vnet.properties.subnets[1].id
output privateDnsZoneId string = privateDnsZone.id