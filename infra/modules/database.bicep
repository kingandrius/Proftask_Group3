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

Run ACR_NAME=$(az acr list -g "$RESOURCE_GROUP" --query "[0].name" -o tsv)
First deployment detected: bootstrapping infrastructure...
WARNING: /home/runner/work/Proftask_Group3/Proftask_Group3/infra/modules/shared.bicep(109,1) : Warning outputs-should-not-contain-secrets: Outputs should not contain secrets. Found possible secret: output name 'dbPasswordSecretUri' suggests a secret [https://aka.ms/bicep/linter-diagnostics#outputs-should-not-contain-secrets]

WARNING: /home/runner/work/Proftask_Group3/Proftask_Group3/infra/modules/shared.bicep(109,1) : Warning outputs-should-not-contain-secrets: Outputs should not contain secrets. Found possible secret: output name 'dbPasswordSecretUri' suggests a secret [https://aka.ms/bicep/linter-diagnostics#outputs-should-not-contain-secrets]

ERROR: {"status":"Failed","error":{"code":"DeploymentFailed","target":"/subscriptions/***/resourceGroups/rg-fonteyn-g3-booking-test/providers/Microsoft.Resources/deployments/deployment1","message":"At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/arm-deployment-operations for usage details. Correlation ID: 01ef0f1d-55c5-4954-8948-1a9bb0a7dd70","details":[{"code":"InvalidResourceLocation","message":"The resource 'psql-fonteyn-g3-test-nla7id' already exists in location 'swedencentral' in resource group 'rg-fonteyn-g3-booking-test'. A resource with the same name cannot be created in location 'northeurope'. Please select a new resource name."}]}}
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