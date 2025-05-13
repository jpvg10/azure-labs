# Storage Local

```bash
cp terraform.tfvars.example terraform.tfvars
# Replace values in the new file with your own values

az login

terraform init
terraform plan
terraform apply # This will take a long time

# Inspect the terminal output to find the cloud-server IP
# On the Azure Portal navigate to the dev-laptop VM
# Connect to it with Bastion. User is adminuser, password is what you defined in terraform.tfvars


# On the VM run:
ping <cloud server ip>

dig <storage account name>.blob.core.windows.net
# You will see the private IP of the private endpoint

curl "https://<storage account name>.blob.core.windows.net/public-files?restype=container&comp=list"
# The list will be empty but the important thing is it doesn't give an error


# Back on your mahcine:
dig <storage account name>.blob.core.windows.net
# You will see the public IP instead

curl "https://<storage account name>.blob.core.windows.net/public-files?restype=container&comp=list"
# Access denied

terraform destroy
```
