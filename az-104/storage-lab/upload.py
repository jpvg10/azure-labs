import argparse, os
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient

try:
  parser = argparse.ArgumentParser()
  parser.add_argument("file_path", help="Relative or absolute path to the file you want to upload", type=str)
  args = parser.parse_args()

  file_path = args.file_path
  file_name = os.path.basename(file_path)

  account_url = "https://labaccountjpvg.blob.core.windows.net"
  default_credential = DefaultAzureCredential()
  blob_service_client = BlobServiceClient(account_url, credential=default_credential)

  container_name = "uploaded-files"
  blob_client = blob_service_client.get_blob_client(container=container_name, blob=file_name)

  with open(file=file_path, mode="rb") as data:
      blob_client.upload_blob(data)
      print("Uploaded blob:", file_name)

except Exception as ex:
  print("Error:", ex)
