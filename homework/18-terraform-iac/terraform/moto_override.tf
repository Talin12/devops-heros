# Points the AWS provider at a local Moto server (docker run -p 5050:5000 motoserver/moto)
# instead of real AWS. Terraform merges *_override.tf into the provider block above.
# Delete this file to run the exact same config against a real AWS account.
provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true

  endpoints {
    s3  = "http://localhost:5050"
    sts = "http://localhost:5050"
  }
}
