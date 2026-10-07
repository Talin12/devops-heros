# Points the AWS provider at a local Moto server (docker run -p 5050:5000 motoserver/moto)
# instead of real AWS. Terraform merges *_override.tf into the provider block in versions.tf.
# Delete this file to run the exact same config against a real AWS account.
provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true

  endpoints {
    ec2 = "http://localhost:5050"
    sts = "http://localhost:5050"
  }
}
