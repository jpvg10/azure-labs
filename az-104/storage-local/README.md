# Storage Local

```bash
cp .env.example .env
cp terraform.tfvars.example terraform.tfvars
# Replace values in both new files with your own values

python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

az login

terraform init
terraform plan
terraform apply

python upload.py <path to file>

terraform destroy
```
