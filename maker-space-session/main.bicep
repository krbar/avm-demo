targetScope = 'subscription'

param location string = deployment().location
param resourceGroupName1 string = 'maker-space-rg-1'
param storageAccountName string = 'makerspace${uniqueString(subscription().id, resourceGroupName1)}' // added a suffix to ensure uniqueness
param managedIdentityName string = 'maker-space-mi'
param vnetName string = 'maker-space-vnet'
param logAnalyticsWorkspaceName string = 'maker-space-law'
param tags object = {
  environment: 'lab'
  project: 'maker-space'
}

resource rg1 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName1
  location: location
  tags: tags
}

module identity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.2' = {
  scope: rg1
  params: {
    name: managedIdentityName
    location: location
    tags: tags
  }
}

module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.14.0' = {
  scope: rg1
  params: {
    name: logAnalyticsWorkspaceName
    location: location
    tags: tags
    roleAssignments: [
      {
        principalId: identity.outputs.principalId
        roleDefinitionIdOrName: 'Reader'
        principalType: 'ServicePrincipal'
      }
      {
        principalId: identity.outputs.principalId
        roleDefinitionIdOrName: 'Contributor'
        principalType: 'ServicePrincipal'
      }
    ]
    diagnosticSettings: [
      {
        useThisWorkspace: true
      }
    ]
  }
}

module vnet 'br/public:avm/res/network/virtual-network:0.7.1' = {
  scope: rg1
  params: {
    name: vnetName
    location: location
    tags: tags
    addressPrefixes: [
      '10.0.0.0/16'
    ]
    subnets: [
      {
        name: 'privateEndpoints'
        addressPrefix: '10.0.0.0/24'
        roleAssignments: [
          {
            principalId: identity.outputs.principalId
            roleDefinitionIdOrName: 'Network Contributor'
            principalType: 'ServicePrincipal'
          }
        ]
      }
      {
        name: 'vnet-integration'
        addressPrefix: '10.0.1.0/24'
        delegation: 'Microsoft.Web/serverFarms'
      }
    ]
    diagnosticSettings: [
      {
        workspaceResourceId: logAnalytics.outputs.resourceId
      }
    ]
  }
}

module blobPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.8.0' = {
  scope: rg1
  params: {
    name: 'privatelink.blob.${environment().suffixes.storage}'
    tags: tags
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: vnet.outputs.resourceId
      }
    ]
  }
}

module storageAccount 'br/public:avm/res/storage/storage-account:0.29.0' = {
  scope: rg1
  params: {
    name: storageAccountName
    location: location

    tags: tags

    blobServices: {
      containers: [
        {
          name: 'data'
        }
      ]
    }
    privateEndpoints: [
      {
        service: 'blob'
        subnetResourceId: vnet.outputs.subnetResourceIds[0]
        name: 'pe-blob-storage'
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: blobPrivateDnsZone.outputs.resourceId
            }
          ]
        }
      }
    ]
  }
}
