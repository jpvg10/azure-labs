# Storage Webapp

The repo for the web app is: [jpvg10/azure-webapp-storage](https://github.com/jpvg10/azure-webapp-storage)

```bash
cp terraform.tfvars.example terraform.tfvars
# Replace values in the new file with your own values

az login

terraform init
terraform plan
terraform apply

# Store AZURE_CLIENT_ID, AZURE_TENANT_ID and AZURE_SUBSCRIPTION_ID (without quotes) as secrets on the web app repo
# Trigger GitHub Actions deployment from the web app repo
# Navigate to website and upload file

terraform destroy
```
