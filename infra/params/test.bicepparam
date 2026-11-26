using '../main.bicep'

param location = 'swedencentral'
param envName = 'test'
param vnetAddressPrefix = '10.21.0.0/16'
param acaSubnetPrefix = '10.21.0.0/23'
param dbSubnetPrefix = '10.21.2.0/24'
param dbSkuName = 'Standard_B2s'
param dbSkuTier = 'Burstable'
param targetPort = 80
param envLabel = 'Azure Cloud (Test)'
param authMode = 'entra'
param minReplicas = 0
param maxReplicas = 2
param dbAdminPassword = readEnvironmentVariable('DB_ADMIN_PASSWORD', '')
param arrivalsApiKey = readEnvironmentVariable('ARRIVALS_API_KEY', '')
param containerImage = readEnvironmentVariable('CONTAINER_IMAGE', 'mcr.microsoft.com/k8se/quickstart:latest')