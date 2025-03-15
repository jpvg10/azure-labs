# VM Provisioner

For this lab I decided to try out Bicep instead of Terraform.

```bash
az login

az deployment sub what-if --location 'Sweden Central' --template-file main.bicep --parameters params.json --parameters adminSshPublicKey=null
az deployment sub create --location 'Sweden Central' --template-file main.bicep --parameters params.json
# Paste your SSH public key when prompted

# Inspect the output in the terminal to find the public IP of the VMs
ssh azureuser@<public ip>

az group delete -n vms-group -f Microsoft.Compute/virtualMachines --y --no-wait
```
