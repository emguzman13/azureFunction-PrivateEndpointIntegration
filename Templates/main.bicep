param location string = resourceGroup().location

@description('The name of the backend Azure storage account used by the Azure Function app.')
param functionStorageAccountName string = 'st${uniqueString(resourceGroup().id)}'

//virtual network-related parameters
@description('The name of the virtual network for virtual network integration.')
param vnetName string = 'vnet-${uniqueString(resourceGroup().id)}'

@description('The name of the virtual network subnet to be associated with the Azure Function app.')
param functionSubnetName string = 'snet-func'

@description('The name of the virtual network subnet used for allocating IP addresses for private endpoints.')
param privateEndpointSubnetName string = 'snet-pe'

@description('The IP adddress space used for the virtual network.')
param vnetAddressPrefix string = '10.100.0.0/16'

@description('The IP address space used for the Azure Function integration subnet.')
param functionSubnetAddressPrefix string = '10.100.0.0/24'

@description('The IP address space used for the private endpoints.')
param privateEndpointSubnetAddressPrefix string = '10.100.1.0/24'

//function app parameters
@description('The name of the Azure Function app.')
param functionAppName string = 'func-${uniqueString(resourceGroup().id)}'

@description('The name of the Azure Function hosting plan.')
param functionAppPlanName string = 'plan-${uniqueString(resourceGroup().id)}'

@description('Specifies the OS used for the Azure Function hosting plan.')
@allowed([
  'Windows'
  'Linux'
])
param functionPlanOS string = 'Linux'

@description('Specifies the Azure Function hosting plan SKU.')
@allowed([
  'EP1'
  'EP2'
  'EP3'
])
param functionAppPlanSku string = 'EP1'

//variables
var applicationInsightsName = 'appi-${uniqueString(resourceGroup().id)}'

var privateStorageFileDnsZoneName = 'privatelink.file.${environment().suffixes.storage}'
var privateEndpointStorageFileName = '${storageAccount.name}-file-private-endpoint'

var privateStorageTableDnsZoneName = 'privatelink.table.${environment().suffixes.storage}'
var privateEndpointStorageTableName = '${storageAccount.name}-table-private-endpoint'

var privateStorageBlobDnsZoneName = 'privatelink.blob.${environment().suffixes.storage}'
var privateEndpointStorageBlobName = '${storageAccount.name}-blob-private-endpoint'

var privateStorageQueueDnsZoneName = 'privatelink.queue.${environment().suffixes.storage}'
var privateEndpointStorageQueueName = '${storageAccount.name}-queue-private-endpoint'

var privateFunctionDnsZoneName = 'privatelink.azurewebsites.net'
var privateEndpointFunctionName = '${functionApp.name}-function-private-endpoint'

var functionContentShareName = 'function-share'

// The term "reserved" is used by ARM to indicate if the hosting plan is a Linux or Windows-based plan.
// A value of true indicated Linux, while a value of false indicates Windows.
var isReserved = (functionPlanOS == 'Linux') ? true : false

//Create Virtual Network
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2020-07-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: functionSubnetName
        properties: {
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          delegations: [
            {
              name: 'webapp'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          addressPrefix: functionSubnetAddressPrefix
        }
      }
      {
        name: privateEndpointSubnetName
        properties: {
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          addressPrefix: privateEndpointSubnetAddressPrefix
        }
      }
    ]
  }

  resource functionSubnet 'subnets' existing = {
    name: functionSubnetName
  }

  resource privateEndpointSubnet 'subnets' existing = {
    name: privateEndpointSubnetName
  }
}

//Private DNS Zones

//Storage File DNS Zone
resource storageFileDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateStorageFileDnsZoneName
  location: 'global'

  resource storageFileDnsZoneLink 'virtualNetworkLinks' = {
    name: '${storageFileDnsZone.name}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

//Storage Blob DNS Zone
resource storageBlobDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateStorageBlobDnsZoneName
  location: 'global'

  resource storageBlobDnsZoneLink 'virtualNetworkLinks' = {
    name: '${storageBlobDnsZone.name}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

//Storage Queue DNS Zone
resource storageQueueDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateStorageQueueDnsZoneName
  location: 'global'

  resource storageQueueDnsZoneLink 'virtualNetworkLinks' = {
    name: '${storageQueueDnsZone.name}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

//Storage Table DNS Zone
resource storageTableDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateStorageTableDnsZoneName
  location: 'global'

  resource storageTableDnsZoneLink 'virtualNetworkLinks' = {
    name: '${storageTableDnsZone.name}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

//Function  DNS Zone
resource functionDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateFunctionDnsZoneName
  location: 'global'

  resource functionDnsZoneLink 'virtualNetworkLinks' = {
    name: '${functionDnsZone.name}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

//Private Endpoints

//Storage File Private Endpoint
resource storageFilePrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-02-01' = {
  name: privateEndpointStorageFileName
  location: location
  properties: {
    subnet: {
      id: virtualNetwork::privateEndpointSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'MyStorageFilePrivateLinkConnection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }

  resource storageFilePrivateEndpointDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'filePrivateDnsZoneGroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: storageFileDnsZone.id
          }
        }
      ]
    }
  }
}

//Storage Table Private Endpoint
resource storageTablePrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-02-01' = {
  name: privateEndpointStorageTableName
  location: location
  properties: {
    subnet: {
      id: virtualNetwork::privateEndpointSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'MyStorageTablePrivateLinkConnection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'table'
          ]
        }
      }
    ]
  }

  resource storageTablePrivateEndpointDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'tablePrivateDnsZoneGroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: storageTableDnsZone.id
          }
        }
      ]
    }
  }
}

//Storage Queue Private Endpoint
resource storageQueuePrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-02-01' = {
  name: privateEndpointStorageQueueName
  location: location
  properties: {
    subnet: {
      id: virtualNetwork::privateEndpointSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'MyStorageQueuePrivateLinkConnection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'queue'
          ]
        }
      }
    ]
  }

  resource storageQueuePrivateEndpointDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'queuePrivateDnsZoneGroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: storageQueueDnsZone.id
          }
        }
      ]
    }
  }
}

//Storage Blob Private Endpoint
resource storageBlobPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-02-01' = {
  name: privateEndpointStorageBlobName
  location: location
  properties: {
    subnet: {
      id: virtualNetwork::privateEndpointSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'MyStorageBlobPrivateLinkConnection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }

  resource storageBlobPrivateEndpointDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'blobPrivateDnsZoneGroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: storageBlobDnsZone.id
          }
        }
      ]
    }
  }
}


//Function Private Endpoint
resource functionAppPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-02-01' = {
  name: privateEndpointFunctionName
  location: location
  properties: {
    subnet: {
      id: virtualNetwork::privateEndpointSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'MyFunctionAppPrivateLinkConnection'
        properties: {
          privateLinkServiceId: functionApp.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }

  resource functionAppPrivateEndpointDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'functionAppPrivateDnsZoneGroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: functionDnsZone.id
          }
        }
      ]
    }
  }
}

//Storage Account creation
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: functionStorageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
    }
  }
}

//Storage Account file share creation
resource functionContentShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-04-01' = {
  name: '${storageAccount.name}/default/${functionContentShareName}'
}

//Application Insights creation
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

//App Service Plan creation
resource plan 'Microsoft.Web/serverfarms@2021-01-01' = {
  location: location
  name: functionAppPlanName
  sku: {
    name: functionAppPlanSku
    tier: 'ElasticPremium'
    size: functionAppPlanSku
    family: 'EP'
  }
  kind: 'elastic'
  properties: {
    maximumElasticWorkerCount: 20
    reserved: isReserved
  }
}

//Function app creation
resource functionApp 'Microsoft.Web/sites@2021-01-01' = {
  location: location
  name: functionAppName
  kind: isReserved ? 'functionapp,linux' : 'functionapp'
  properties: {
    httpsOnly: true
    serverFarmId: plan.id
    reserved: isReserved
    virtualNetworkSubnetId: virtualNetwork::functionSubnet.id
    siteConfig: {
      vnetRouteAllEnabled: true
      functionsRuntimeScaleMonitoringEnabled: true
      linuxFxVersion: isReserved ? 'python|3.9' : json('null')
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'WEBSITE_CONTENTOVERVNET'
          value: '1'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: functionContentShareName
        }
      ]
    }
  }

  resource config 'config' = {
    name: 'web'
    properties: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
  }
}
