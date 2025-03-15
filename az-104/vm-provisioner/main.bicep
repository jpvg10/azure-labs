@secure()
param adminSshPublicKey string

param vmCount int
param vmNamePrefix string

targetScope = 'subscription'

resource rg 'Microsoft.Resources/resourceGroups@2024-07-01' = {
  name: 'vms-group'
  location: deployment().location
}

module network './network.bicep' = {
  name: 'networkDeployment'
  scope: rg
}

module vm './vm.bicep' = [for i in range(0, vmCount): {
  name: 'vmDeployment-${i}'
  dependsOn: [network]
  scope: rg
  params: {
    vmName: '${vmNamePrefix}-${i}'
    adminSshPublicKey: adminSshPublicKey
  }
}]

output publicIP array = [for i in range(0, vmCount): {
  publicIP: vm[i].outputs.publicIP
}]
