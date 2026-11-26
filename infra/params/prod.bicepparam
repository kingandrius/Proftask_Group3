using '../main.bicep'

param location = 'swedencentral'
param envName = 'prod'
param vnetAddressPrefix = '10.20.0.0/16'
param acaSubnetPrefix = '10.20.0.0/23'
param dbSubnetPrefix = '10.20.2.0/24'
param targetPort = 80
param envLabel = 'Azure Cloud (Prod)'
param authMode = 'entra'
param minReplicas = 1
param maxReplicas = 5
param dbAdminPassword = readEnvironmentVariable('DB_ADMIN_PASSWORD', '')
param arrivalsApiKey = readEnvironmentVariable('ARRIVALS_API_KEY', '')
param containerImage = readEnvironmentVariable('CONTAINER_IMAGE', 'mcr.microsoft.com/k8se/quickstart:latest')