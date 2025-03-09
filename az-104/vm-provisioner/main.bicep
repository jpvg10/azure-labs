@secure()
param adminSshPublicKey string

targetScope = 'subscription'

resource rg 'Microsoft.Resources/resourceGroups@2024-07-01' = {
  name: 'vms-group'
  location: deployment().location
}

module network './network.bicep' = {
  name: 'networkDeployment'
  scope: rg
}

module vm './vm.bicep' = {
  name: 'vmDeployment'
  dependsOn: [network]
  scope: rg
  params: {
    vmName: 'myVM'
    adminSshPublicKey: adminSshPublicKey
  }
}

output publicIP string = vm.outputs.publicIP
