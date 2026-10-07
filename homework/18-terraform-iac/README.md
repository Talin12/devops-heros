# Terraform & Infrastructure as Code: Homework (Session 18)

**Name:** Talin Daga
**Enrollment No.:** 24BCS10321
**Email:** talin.24bcs10321@sst.scaler.com

> Every command below was actually executed and the output pasted verbatim.
> My config: [`terraform/`](terraform/) · Session labs: [`session18-terraform-iac/`](../../session18-terraform-iac/)

---

## Tasks

| # | Topic | Status |
|---|---|---|
| 1 | Provider + `required_providers` + `default_tags` | ✅ |
| 2 | Resources: S3 bucket, bucket versioning, an object | ✅ |
| 3 | Variables (with a `validation` rule) | ✅ |
| 4 | Outputs | ✅ |
| 5 | `init` → `fmt` → `validate` → `plan` → `apply` | ✅ |
| 6 | State: `state list`, `state show`, drift detection | ✅ |
| 7 | In-place update vs forced replacement | ✅ |
| 8 | `destroy` | ✅ |

## Where this ran

My AWS access key is no longer valid, so I ran everything against **[Moto](https://github.com/getmoto/moto)**,
an open-source AWS API emulator, in Docker:

```bash
docker run -d --name moto -p 5050:5000 motoserver/moto:latest
```

The config itself is plain AWS. Only [`moto_override.tf`](terraform/moto_override.tf) points the
provider at `localhost:5050`. Terraform merges any `*_override.tf` file into the matching block,
so **deleting that one file runs the identical config against a real AWS account.**

**Environment:** Terraform v1.16.4, hashicorp/aws v6.67.0, Moto 5.2.3, region `ap-south-1`.

---

## Files

| File | What it has |
|---|---|
| [`versions.tf`](terraform/versions.tf) | `required_version`, `required_providers`, provider with `default_tags` |
| [`variables.tf`](terraform/variables.tf) | `aws_region`, `project_name`, `environment` (validated), `enable_versioning` |
| [`main.tf`](terraform/main.tf) | `aws_s3_bucket` (with `bucket_prefix`), `aws_s3_bucket_versioning`, `aws_s3_object` |
| [`outputs.tf`](terraform/outputs.tf) | bucket name, ARN, region, versioning status |

I used `bucket_prefix` instead of a fixed `bucket` name. S3 names are global across all AWS
accounts, so the session demo's hard-coded `yatri1107` would fail for anyone who runs it after
the first person.

---

## 1. init, fmt, validate

```console
$ terraform init
Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 6.0"...
- Installing hashicorp/aws v6.67.0...
- Installed hashicorp/aws v6.67.0 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

$ terraform fmt -check -diff

$ terraform validate
Success! The configuration is valid.
```

## 2. Variable validation

```console
$ terraform plan -var environment=qa

Planning failed. Terraform encountered an error while generating this plan.


Error: Invalid value for variable

  on variables.tf line 13:
  13: variable "environment" {
    ├────────────────
    │ var.environment is "qa"

environment must be one of: dev, staging, prod.

This was checked by the validation rule at variables.tf:18,3-13.
```

Caught at plan time, before any API call is made.

## 3. plan and apply

```console
$ terraform plan -out=tfplan

Terraform will perform the following actions:

  # aws_s3_bucket.homework will be created
  + resource "aws_s3_bucket" "homework" {
      + arn                         = (known after apply)
      + bucket                      = (known after apply)
      + bucket_prefix               = "session18-dev-"
      + force_destroy               = true
      + region                      = "ap-south-1"
      + tags                        = {
          + "Environment" = "dev"
          + "Name"        = "session18-dev"
        }
      + tags_all                    = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "session18-dev"
          + "Owner"       = "talin-daga"
        }
      ...
    }

  # aws_s3_bucket_versioning.homework will be created
  ...
          + status     = "Suspended"

  # aws_s3_object.readme will be created
  ...

Plan: 3 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + bucket_arn        = (known after apply)
  + bucket_name       = (known after apply)
  + bucket_region     = "ap-south-1"
  + versioning_status = "Suspended"

$ terraform apply tfplan
aws_s3_bucket.homework: Creating...
aws_s3_bucket.homework: Creation complete after 0s [id=session18-dev-97b2667009d58d2b1c416cf204]
aws_s3_bucket_versioning.homework: Creating...
aws_s3_object.readme: Creating...
aws_s3_object.readme: Creation complete after 0s [id=session18-dev-97b2667009d58d2b1c416cf204/hello.txt]
aws_s3_bucket_versioning.homework: Creation complete after 1s [id=session18-dev-97b2667009d58d2b1c416cf204]

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

bucket_arn = "arn:aws:s3:::session18-dev-97b2667009d58d2b1c416cf204"
bucket_name = "session18-dev-97b2667009d58d2b1c416cf204"
bucket_region = "ap-south-1"
versioning_status = "Suspended"
```

(The plan's long list of `(known after apply)` attributes is trimmed with `...`.)

- `tags_all` = my `tags` **merged with** the provider's `default_tags`.
- Terraform worked out the order from references. The versioning resource and the object both
  use `aws_s3_bucket.homework.id`, so they wait for the bucket and then run in parallel.
- `apply tfplan` runs the saved plan exactly, with no new diff and no prompt.

```console
$ terraform output -raw bucket_name; echo
session18-dev-97b2667009d58d2b1c416cf204

$ aws --endpoint-url http://localhost:5050 --region ap-south-1 s3 cp s3://$(terraform output -raw bucket_name)/hello.txt -
Hello from Terraform - dev
```

> **Emulator note.** The first follow-up `plan` wanted to add the tags again. Moto ignores tags sent
> inside the CreateBucket call itself; the AWS provider then applied them with a separate tagging
> call. After one more `apply`, `plan -detailed-exitcode` returned **exit 0, "No changes"**. That is
> a Moto quirk, not a problem in the config.

## 4. State

```console
$ terraform state list
aws_s3_bucket.homework
aws_s3_bucket_versioning.homework
aws_s3_object.readme

$ terraform state show aws_s3_bucket.homework
# aws_s3_bucket.homework:
resource "aws_s3_bucket" "homework" {
    arn                         = "arn:aws:s3:::session18-dev-97b2667009d58d2b1c416cf204"
    bucket                      = "session18-dev-97b2667009d58d2b1c416cf204"
    bucket_domain_name          = "session18-dev-97b2667009d58d2b1c416cf204.s3.amazonaws.com"
    bucket_prefix               = "session18-dev-"
    bucket_region               = "ap-south-1"
    force_destroy               = true
    id                          = "session18-dev-97b2667009d58d2b1c416cf204"
    region                      = "ap-south-1"
    ...
}
```

(Trimmed to the interesting attributes. The full output also lists `grant`, `versioning`,
`hosted_zone_id`, and so on.)

State is Terraform's record of *which real object* each resource address maps to. Without it,
Terraform would have no way to know that `aws_s3_bucket.homework` is
`session18-dev-97b2667009d58d2b1c416cf204`, because I never wrote that name anywhere.

## 5. In-place update

```console
$ terraform apply -auto-approve -var enable_versioning=true | grep -E "^  #|~ status|Plan:|Apply complete|versioning_status"
  # aws_s3_bucket_versioning.homework will be updated in-place
          ~ status     = "Suspended" -> "Enabled"
Plan: 0 to add, 1 to change, 0 to destroy.
  ~ versioning_status = "Suspended" -> "Enabled"
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
versioning_status = "Enabled"
```

## 6. Drift: someone changes it by hand

```console
$ aws --endpoint-url http://localhost:5050 --region ap-south-1 s3api delete-bucket-tagging --bucket $(terraform output -raw bucket_name)

$ aws --endpoint-url http://localhost:5050 --region ap-south-1 s3api get-bucket-tagging --bucket $(terraform output -raw bucket_name)

aws: [ERROR]: An error occurred (NoSuchTagSet) when calling the GetBucketTagging operation: The TagSet does not exist

$ terraform plan -var enable_versioning=true -detailed-exitcode
aws_s3_bucket.homework: Refreshing state... [id=session18-dev-97b2667009d58d2b1c416cf204]
...
  # aws_s3_bucket.homework will be updated in-place
  ~ resource "aws_s3_bucket" "homework" {
        id                          = "session18-dev-97b2667009d58d2b1c416cf204"
      ~ tags                        = {
          + "Environment" = "dev"
          + "Name"        = "session18-dev"
        }
...
Plan: 0 to add, 1 to change, 0 to destroy.
exit code: 2

$ terraform apply -auto-approve -var enable_versioning=true | tail -8
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

`Refreshing state...` reads the real bucket, finds the tags missing, and plans to put them back.
`-detailed-exitcode` returns **2** for "changes pending" (0 = none, 1 = error). That is what a
nightly CI drift check would test.

## 7. Forced replacement

```console
$ terraform plan -var enable_versioning=true -var environment=staging | grep -E "^  #|must be replaced|forces replacement|Plan:"
  # aws_s3_bucket.homework must be replaced
      ~ bucket_prefix               = "session18-dev-" -> "session18-staging-" # forces replacement
  # aws_s3_bucket_versioning.homework must be replaced
      ~ bucket                = "session18-dev-97b2667009d58d2b1c416cf204" -> (known after apply) # forces replacement
  # aws_s3_object.readme must be replaced
      ~ bucket                        = "session18-dev-97b2667009d58d2b1c416cf204" -> (known after apply) # forces replacement
Plan: 3 to add, 0 to change, 3 to destroy.
```

A bucket can't be renamed, so changing `environment` means **destroy and recreate**, and every
resource that points at the bucket is replaced with it. Changing the versioning flag was a quiet
`~ update`; changing one string here would delete the bucket and all its data. Always read the
plan for `must be replaced` before typing `yes`.

## 8. Destroy

```console
$ terraform state list
aws_s3_bucket.homework
aws_s3_bucket_versioning.homework
aws_s3_object.readme

$ terraform destroy -auto-approve
...
Plan: 0 to add, 0 to change, 3 to destroy.
aws_s3_bucket_versioning.homework: Destroying... [id=session18-dev-ade86f49a7f7031840e4ff9cdb]
aws_s3_object.readme: Destroying... [id=session18-dev-ade86f49a7f7031840e4ff9cdb/hello.txt]
aws_s3_bucket_versioning.homework: Destruction complete after 0s
aws_s3_object.readme: Destruction complete after 0s
aws_s3_bucket.homework: Destroying... [id=session18-dev-ade86f49a7f7031840e4ff9cdb]
aws_s3_bucket.homework: Destruction complete after 0s

Destroy complete! Resources: 3 destroyed.

$ terraform state list

$ aws --endpoint-url http://localhost:5050 --region ap-south-1 s3 ls

$ cat terraform.tfstate | python3 -c "..."
serial: 20 | resources: 0 | lineage: 9d148568-ceff-27fa-9910-243962829e74
```

Destroy runs in the **reverse** order of create: children first, then the bucket.

> **Emulator note.** My first `destroy` was run with versioning `Enabled` and hung on the bucket.
> Moto's server log showed `AttributeError: 'FakeDeleteMarker' object has no attribute 'dispose'`,
> a Moto bug when deleting S3 delete markers. The provider kept retrying. I stopped it, reset Moto,
> and re-ran the lifecycle with versioning suspended. That destroy (above, a new bucket ID) worked
> in under a second.

The state file is not deleted by `destroy`. It stays, empty, with its `serial` bumped on every
write and its `lineage` unchanged. That lineage is how Terraform refuses to overwrite one
project's state with another's.

## What I took away

- **`plan` is the important step, and `-out` makes it binding.** Section 7 is one variable change
  that would have deleted a bucket.
- **Drift is just a normal plan.** Terraform doesn't need a special mode. Every plan compares real
  state with the config.
- **Override files let one config target two places** without `if` statements or copies.
