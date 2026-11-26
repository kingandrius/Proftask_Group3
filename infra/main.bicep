targetScope = 'resourceGroup'

@description('Azure region')
param location string = resourceGroup().location

@description('Environment name (test or prod)')
@allowed([ 'test', 'prod' ])
param envName string

@description('VNet CIDR prefix')
param vnetAddressPrefix string

@description('ACA delegated subnet CIDR')
param acaSubnetPrefix string

@description('PostgreSQL delegated subnet CIDR')
param dbSubnetPrefix string

@description('PostgreSQL administrator username')
param dbAdminUser string = 'fonteyn_user'

@description('PostgreSQL database name')
param dbName string = 'fonteyn_bookings'

@description('PostgreSQL administrator password')
@secure()
param dbAdminPassword string

@description('Arrivals API key for Part E park barriers')
@secure()
param arrivalsApiKey string

@description('Entra ID App Registration client ID for Easy Auth (optional)')
param entraClientId string = ''

@description('Entra ID App Registration client secret for Easy Auth (optional)')
@secure()
param entraClientSecret string = ''

@description('PostgreSQL SKU name')
param dbSkuName string = 'Standard_B1ms'

@description('PostgreSQL SKU tier')
param dbSkuTier string = 'Burstable'

@description('Container image to run')
param containerImage string

@description('Internal HTTP port exposed by the container')
param targetPort int = 80

@description('Toggle health probes (false during initial empty-ACR bootstrap)')
param enableHealthProbes bool = true

@description('Banner label displayed in the web UI')
param envLabel string

@description('Staff auth mode')
param authMode string = 'entra'

@description('Minimum container replicas')
param minReplicas int

@description('Maximum container replicas')
param maxReplicas int

var tags = {
  Group: 'Group3'
  Owner: 'Andrius'
  Part: 'C'
  Environment: envName
  ManagedBy: 'Bicep'
}

module network 'modules/network.bicep' = {
  name: 'deploy-network-${envName}'
  params: {
    location: location
    envName: envName
    vnetAddressPrefix: vnetAddressPrefix
    acaSubnetPrefix: acaSubnetPrefix
    dbSubnetPrefix: dbSubnetPrefix
    tags: tags
  }
}

module shared 'modules/shared.bicep' = {
  name: 'deploy-shared-${envName}'
  params: {
    location: location
    envName: envName
    dbAdminPassword: dbAdminPassword
    arrivalsApiKey: arrivalsApiKey
    entraClientSecret: entraClientSecret
    tags: tags
  }
}

module database 'modules/database.bicep' = {
  name: 'deploy-database-${envName}'
  params: {
    location: location
    envName: envName
    dbSubnetId: network.outputs.dbSubnetId
    privateDnsZoneId: network.outputs.privateDnsZoneId
    dbAdminUser: dbAdminUser
    dbAdminPassword: dbAdminPassword
    dbName: dbName
    dbSkuName: dbSkuName
    dbSkuTier: dbSkuTier
    tags: tags
  }
}

module containerApps 'modules/containerapps.bicep' = {
  name: 'deploy-containerapps-${envName}'
  params: {
    location: location
    envName: envName
    acaSubnetId: network.outputs.acaSubnetId
    logAnalyticsWorkspaceName: shared.outputs.logAnalyticsWorkspaceName
    uamiId: shared.outputs.uamiId
    acrLoginServer: shared.outputs.acrLoginServer
    containerImage: containerImage
    targetPort: targetPort
    enableHealthProbes: enableHealthProbes
    postgresFqdn: database.outputs.postgresFqdn
    dbName: database.outputs.databaseName
    dbAdminUser: dbAdminUser
    dbPasswordSecretUri: shared.outputs.dbPasswordSecretUri
    arrivalsApiKeySecretUri: shared.outputs.arrivalsApiKeySecretUri
    entraClientId: entraClientId
    entraClientSecretUri: shared.outputs.entraClientSecretUri
    envLabel: envLabel
    authMode: authMode
    minReplicas: minReplicas
    maxReplicas: maxReplicas
    tags: tags
  }
}

output acrName string = shared.outputs.acrName
output acrLoginServer string = shared.outputs.acrLoginServer
output keyVaultName string = shared.outputs.keyVaultName
output postgresFqdn string = database.outputs.postgresFqdn
output containerAppUrl string = 'https://${containerApps.outputs.containerAppFqdn}'