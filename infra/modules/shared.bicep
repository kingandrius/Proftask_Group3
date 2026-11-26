@description('Azure region for shared resources')
param location string

@description('Environment name (test or prod)')
param envName string

@description('PostgreSQL administrator password stored in Key Vault')
@secure()
param dbAdminPassword string

@description('API key used by Part E park barriers to call /api/arrivals')
@secure()
param arrivalsApiKey string

@description('Common resource tags')
param tags object

var uniqueSuffix = take(toLower(uniqueString(resourceGroup().id, location)), 6)
var acrPullRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
var kvSecretsUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-fonteyn-g3-${envName}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-fonteyn-g3-booking-${envName}'
  location: location
  tags: tags
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: 'acrfonteyng3${envName}${uniqueSuffix}'
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(acr.id, uami.id, acrPullRoleId)
  properties: {
    principalId: uami.properties.principalId
    roleDefinitionId: acrPullRoleId
    principalType: 'ServicePrincipal'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-fg3-${envName}-${uniqueSuffix}'
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

resource kvSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, uami.id, kvSecretsUserRoleId)
  properties: {
    principalId: uami.properties.principalId
    roleDefinitionId: kvSecretsUserRoleId
    principalType: 'ServicePrincipal'
  }
}

resource dbPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'db-admin-password'
  properties: {
    value: dbAdminPassword
  }
}

resource arrivalsApiKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'arrivals-api-key'
  properties: {
    value: arrivalsApiKey
  }
}

output logAnalyticsWorkspaceName string = logAnalytics.name
output acrName string = acr.name
output acrLoginServer string = acr.properties.loginServer
output uamiId string = uami.id
output keyVaultName string = keyVault.name
output dbPasswordSecretUri string = dbPasswordSecret.properties.secretUri
output arrivalsApiKeySecretUri string = arrivalsApiKeySecret.properties.secretUri