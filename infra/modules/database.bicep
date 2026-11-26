@description('Azure region for PostgreSQL Flexible Server')
param location string

@description('Environment name (test or prod)')
param envName string

@description('Delegated subnet resource ID for PostgreSQL')
param dbSubnetId string

@description('Private DNS Zone resource ID')
param privateDnsZoneId string

@description('PostgreSQL administrator username')
param dbAdminUser string

@description('PostgreSQL administrator password')
@secure()
param dbAdminPassword string

@description('Application database name')
param dbName string

@description('PostgreSQL compute SKU name')
param dbSkuName string = 'Standard_B1ms'

@description('PostgreSQL compute tier')
param dbSkuTier string = 'Burstable'

@description('Common resource tags')
param tags object

var uniqueSuffix = take(toLower(uniqueString(resourceGroup().id, location)), 6)

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: 'psql-fonteyn-g3-${envName}-${uniqueSuffix}'
  location: location
  tags: tags
  sku: {
    name: dbSkuName
    tier: dbSkuTier
  }
  properties: {
    version: '16'
    administratorLogin: dbAdminUser
    administratorLoginPassword: dbAdminPassword
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    network: {
      delegatedSubnetResourceId: dbSubnetId
      privateDnsZoneArmResourceId: privateDnsZoneId
      publicNetworkAccess: 'Disabled'
    }
    authConfig: {
      activeDirectoryAuth: 'Disabled'
      passwordAuth: 'Enabled'
    }
  }
}

resource bookingDb 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  parent: postgresServer
  name: dbName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

resource enforceTls 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-08-01' = {
  parent: postgresServer
  name: 'require_secure_transport'
  properties: {
    value: 'on'
    source: 'user-override'
  }
}

output postgresFqdn string = postgresServer.properties.fullyQualifiedDomainName
output postgresServerName string = postgresServer.name
output databaseName string = bookingDb.name