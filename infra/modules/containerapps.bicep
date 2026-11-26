@description('Azure region for Container Apps')
param location string

@description('Environment name (test or prod)')
param envName string

@description('Delegated subnet resource ID for Container Apps')
param acaSubnetId string

@description('Existing Log Analytics Workspace name in this resource group')
param logAnalyticsWorkspaceName string

@description('User-Assigned Managed Identity resource ID')
param uamiId string

@description('ACR login server')
param acrLoginServer string

@description('Container image to deploy (bootstrap or ACR SHA-tagged image)')
param containerImage string

@description('Port the container listens on internally')
param targetPort int = 80

@description('Enable /health liveness and readiness probes (disabled during initial bootstrap)')
param enableHealthProbes bool = true

@description('PostgreSQL FQDN')
param postgresFqdn string

@description('PostgreSQL database name')
param dbName string

@description('PostgreSQL username')
param dbAdminUser string

@description('Key Vault secret URI for PostgreSQL password')
param dbPasswordSecretUri string

@description('Key Vault secret URI for arrivals API key')
param arrivalsApiKeySecretUri string

@description('Banner label displayed in the web UI')
param envLabel string

@description('Staff authentication mode (legacy or entra)')
param authMode string = 'entra'

@description('Minimum container replicas')
param minReplicas int

@description('Maximum container replicas')
param maxReplicas int

@description('Common resource tags')
param tags object

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource managedEnv 'Microsoft.App/managedEnvironments@2025-01-01' = {
  name: 'cae-fonteyn-g3-${envName}'
  location: location
  tags: tags
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: acaSubnetId
      internal: false
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2025-01-01' = {
  name: 'ca-fonteyn-g3-booking-${envName}'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  properties: {
    managedEnvironmentId: managedEnv.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: targetPort
        transport: 'auto'
        allowInsecure: false
      }
      registries: [
        {
          server: acrLoginServer
          identity: uamiId
        }
      ]
      secrets: [
        {
          name: 'db-admin-password'
          keyVaultUrl: dbPasswordSecretUri
          identity: uamiId
        }
        {
          name: 'arrivals-api-key'
          keyVaultUrl: arrivalsApiKeySecretUri
          identity: uamiId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'booking-web'
          image: containerImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            { name: 'DB_HOST', value: postgresFqdn }
            { name: 'DB_PORT', value: '5432' }
            { name: 'DB_NAME', value: dbName }
            { name: 'DB_USER', value: dbAdminUser }
            { name: 'DB_PASSWORD', secretRef: 'db-admin-password' }
            { name: 'DB_SSLMODE', value: 'require' }
            { name: 'POSTGRES_HOST', value: postgresFqdn }
            { name: 'POSTGRES_DB', value: dbName }
            { name: 'POSTGRES_USER', value: dbAdminUser }
            { name: 'POSTGRES_PASSWORD', secretRef: 'db-admin-password' }
            { name: 'ARRIVALS_API_KEY', secretRef: 'arrivals-api-key' }
            { name: 'AUTH_MODE', value: authMode }
            { name: 'ENV_LABEL', value: envLabel }
          ]
          probes: enableHealthProbes ? [
            {
              type: 'Startup'
              httpGet: {
                path: '/health'
                port: targetPort
              }
              initialDelaySeconds: 5
              periodSeconds: 10
              failureThreshold: 12
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: targetPort
              }
              periodSeconds: 15
              failureThreshold: 3
            }
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: targetPort
              }
              periodSeconds: 30
              failureThreshold: 3
            }
          ] : []
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '20'
              }
            }
          }
        ]
      }
    }
  }
}

output containerAppName string = containerApp.name
output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn