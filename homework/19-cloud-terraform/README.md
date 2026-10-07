# Cloud & Terraform in Action: Homework (Session 19)

**Name:** Talin Daga
**Enrollment No.:** 24BCS10321
**Email:** talin.24bcs10321@sst.scaler.com

> Every command below was actually executed and the output pasted verbatim.
> My config: [`terraform/`](terraform/) · Session labs: [`session19-cloud-terraform/`](../../session19-cloud-terraform/)

---

## What I built

The session mini-project (VPC + one public subnet + IGW + route table + SG), extended to the
layout a real app would use:

```text
                              Internet
                                 │
                       ┌─────────▼─────────┐
                       │ Internet Gateway  │
                       └─────────┬─────────┘
  VPC 10.20.0.0/16               │
 ┌───────────────────────────────┼──────────────────────────────────┐
 │  public-rt: 0.0.0.0/0 → igw   │                                  │
 │   ┌───────────────────────┐   │   ┌───────────────────────┐      │
 │   │ public  10.20.1.0/24  │◄──┴──►│ public  10.20.2.0/24  │      │
 │   │ ap-south-1a           │       │ ap-south-1b           │      │
 │   │  EC2 web (web-sg)     │       │                       │      │
 │   └───────────────────────┘       └───────────────────────┘      │
 │  private-rt: local only                                          │
 │   ┌───────────────────────┐       ┌───────────────────────┐      │
 │   │ private 10.20.101.0/24│       │ private 10.20.102.0/24│      │
 │   │ ap-south-1a (app-sg)  │       │ ap-south-1b (app-sg)  │      │
 │   └───────────────────────┘       └───────────────────────┘      │
 └──────────────────────────────────────────────────────────────────┘
   web-sg: 80, 443 from 0.0.0.0/0
   app-sg: 8080 from web-sg only (no CIDR at all)
```

| Concept from the session | Where it is in [`main.tf`](terraform/main.tf) |
|---|---|
| Regions & AZs | `data "aws_availability_zones"` + `slice(..., 0, var.az_count)` |
| VPC & subnets | `aws_vpc`, `aws_subnet` ×2 public + ×2 private via `count`, CIDRs from `cidrsubnet()` |
| Route tables & IGW | public RT with `0.0.0.0/0 → igw`; private RT with only the local route |
| Security groups | `web` (CIDR-based) and `app` (references the `web` SG instead of a CIDR) |
| Compute (IaaS) | `aws_instance.web` in public subnet 1a, AMI looked up with `data "aws_ami"` |

No NAT gateway on purpose: it is the one piece here that bills by the hour even when idle, so the
private subnets have no outbound internet.

## Where this ran

As in Session 18, my AWS key is no longer valid, so this ran against **Moto** (an open-source AWS
emulator) in Docker. Only [`moto_override.tf`](terraform/moto_override.tf) points at it. Delete
that file and the same config targets real AWS.

**Environment:** Terraform v1.16.4, hashicorp/aws v6.67.0, Moto 5.2.3, region `ap-south-1`.

---

## 1. Validate and plan

```console
$ terraform init | grep -E "Installed|successfully"
- Installed hashicorp/aws v6.67.0 (signed by HashiCorp)
Terraform has been successfully initialized!

$ terraform fmt -check

$ terraform validate
Success! The configuration is valid.

$ terraform plan -out=tfplan | grep -E "^  # |^Plan:"
  # aws_instance.web will be created
  # aws_internet_gateway.main will be created
  # aws_route_table.private will be created
  # aws_route_table.public will be created
  # aws_route_table_association.private[0] will be created
  # aws_route_table_association.private[1] will be created
  # aws_route_table_association.public[0] will be created
  # aws_route_table_association.public[1] will be created
  # aws_security_group.app will be created
  # aws_security_group.web will be created
  # aws_subnet.private[0] will be created
  # aws_subnet.private[1] will be created
  # aws_subnet.public[0] will be created
  # aws_subnet.public[1] will be created
  # aws_vpc.main will be created
Plan: 15 to add, 0 to change, 0 to destroy.
```

## 2. Apply

```console
$ terraform apply tfplan
aws_vpc.main: Creating...
aws_vpc.main: Creation complete after 1s [id=vpc-f177431380bde4338]
aws_internet_gateway.main: Creating...
aws_route_table.private: Creating...
aws_subnet.private[1]: Creating...
aws_subnet.public[0]: Creating...
aws_subnet.private[0]: Creating...
aws_subnet.public[1]: Creating...
aws_security_group.web: Creating...
aws_subnet.private[0]: Creation complete after 0s [id=subnet-d036daa78761b9798]
aws_subnet.private[1]: Creation complete after 0s [id=subnet-296e639811d542e09]
aws_internet_gateway.main: Creation complete after 0s [id=igw-ad20f28972c8dd189]
aws_route_table.public: Creating...
aws_route_table.private: Creation complete after 0s [id=rtb-50345038c81d2f4dd]
aws_route_table_association.private[0]: Creating...
aws_route_table_association.private[1]: Creating...
aws_route_table_association.private[0]: Creation complete after 0s [id=rtbassoc-85bdd1331f0996265]
aws_route_table_association.private[1]: Creation complete after 0s [id=rtbassoc-c0a09684c9a73dd02]
aws_security_group.web: Creation complete after 0s [id=sg-fac81ae18518f660d]
aws_security_group.app: Creating...
aws_route_table.public: Creation complete after 0s [id=rtb-7ccdb1f34990ac5aa]
aws_security_group.app: Creation complete after 0s [id=sg-cfed3975773f647fb]
aws_subnet.public[1]: Still creating... [00m10s elapsed]
aws_subnet.public[0]: Still creating... [00m10s elapsed]
aws_subnet.public[0]: Creation complete after 10s [id=subnet-127b2c3a7cec5ee02]
aws_subnet.public[1]: Creation complete after 10s [id=subnet-2268c26d90d6ece3b]
aws_route_table_association.public[1]: Creating...
aws_route_table_association.public[0]: Creating...
aws_instance.web: Creating...
aws_route_table_association.public[1]: Creation complete after 0s [id=rtbassoc-de1b9014eaad61d8d]
aws_route_table_association.public[0]: Creation complete after 0s [id=rtbassoc-3b39906f27ebba291]
aws_instance.web: Still creating... [00m10s elapsed]
aws_instance.web: Creation complete after 10s [id=i-fb1a52f9d9ebc54a0]

Apply complete! Resources: 15 added, 0 changed, 0 destroyed.

Outputs:

app_sg_id = "sg-cfed3975773f647fb"
availability_zones = tolist([
  "ap-south-1a",
  "ap-south-1b",
])
private_subnets = {
  "ap-south-1a" = "subnet-d036daa78761b9798 (10.20.101.0/24)"
  "ap-south-1b" = "subnet-296e639811d542e09 (10.20.102.0/24)"
}
public_subnets = {
  "ap-south-1a" = "subnet-127b2c3a7cec5ee02 (10.20.1.0/24)"
  "ap-south-1b" = "subnet-2268c26d90d6ece3b (10.20.2.0/24)"
}
vpc_id = "vpc-f177431380bde4338"
web_instance = {
  "ami" = "ami-04681a1dbd79675a5"
  "id" = "i-fb1a52f9d9ebc54a0"
  "private_ip" = "10.20.1.4"
  "public_ip" = "54.214.104.12"
}
web_sg_id = "sg-fac81ae18518f660d"
```

The VPC comes first, then everything that only needs the VPC runs **in parallel**. `app` SG waits
for `web` SG (it references it), and the instance waits for public subnet 1a and the web SG.
Terraform built that graph from the references alone. Nothing in the config says "do this first".

(The public IP is assigned by the emulator. No real machine exists to curl.)

## 3. Verify with the AWS CLI

```console
$ aws --endpoint-url http://localhost:5050 ec2 describe-subnets --filters Name=vpc-id,Values=vpc-f177431380bde4338 --query 'Subnets[].[Tags[?Key==`Name`]|[0].Value,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch]' --output table
-----------------------------------------------------------------------------
|                              DescribeSubnets                              |
+--------------------------------+-----------------+--------------+---------+
|  session19-public-ap-south-1a  |  10.20.1.0/24   |  ap-south-1a |  True   |
|  session19-private-ap-south-1a |  10.20.101.0/24 |  ap-south-1a |  False  |
|  session19-private-ap-south-1b |  10.20.102.0/24 |  ap-south-1b |  False  |
|  session19-public-ap-south-1b  |  10.20.2.0/24   |  ap-south-1b |  True   |
+--------------------------------+-----------------+--------------+---------+
```

Route tables. This is what *actually* makes a subnet public or private:

```console
$ aws --endpoint-url http://localhost:5050 ec2 describe-route-tables --filters Name=vpc-id,Values=vpc-f177431380bde4338 --query 'RouteTables[].{Name:Tags[?Key==`Name`]|[0].Value,Routes:Routes[].[DestinationCidrBlock,GatewayId],Subnets:length(Associations[?SubnetId])}' --output json
[
    {
        "Name": null,
        "Routes": [
            [
                "10.20.0.0/16",
                "local"
            ]
        ],
        "Subnets": 0
    },
    {
        "Name": "session19-private-rt",
        "Routes": [
            [
                "10.20.0.0/16",
                "local"
            ]
        ],
        "Subnets": 2
    },
    {
        "Name": "session19-public-rt",
        "Routes": [
            [
                "10.20.0.0/16",
                "local"
            ],
            [
                "0.0.0.0/0",
                "igw-ad20f28972c8dd189"
            ]
        ],
        "Subnets": 2
    }
]
```

- The **unnamed** table is the VPC's *main* route table, which AWS creates automatically. No subnet
  is associated with it, which is good. Any subnet I forget to associate would silently fall back
  to it.
- The only difference between public and private is that **one route**: `0.0.0.0/0 → igw`. The
  "public" in a subnet's name means nothing on its own.
- Every table has `10.20.0.0/16 → local`, so all four subnets can always reach each other.

Security-group chaining on the app tier:

```console
$ aws --endpoint-url http://localhost:5050 ec2 describe-security-groups --filters Name=vpc-id,Values=vpc-f177431380bde4338 Name=group-name,Values=session19-app-sg --query 'SecurityGroups[0].IpPermissions' --output json
[
    {
        "IpProtocol": "tcp",
        "FromPort": 8080,
        "ToPort": 8080,
        "UserIdGroupPairs": [
            {
                "Description": "App port from web SG",
                "UserId": "123456789012",
                "GroupId": "sg-fac81ae18518f660d"
            }
        ],
        "IpRanges": [],
        "Ipv6Ranges": [],
        "PrefixListIds": []
    }
]
```

`IpRanges: []`: the app tier allows **no addresses at all**, only "any instance that is a
member of `sg-fac81…` (web-sg)". If the web tier scales to 50 instances with new IPs, this rule
never needs to change.

```console
$ aws --endpoint-url http://localhost:5050 ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,SubnetId,PrivateIpAddress]' --output table
-----------------------------------------------------------------------------------------
|                                   DescribeInstances                                   |
+----------------------+-----------+----------+----------------------------+------------+
|  i-fb1a52f9d9ebc54a0 |  t3.micro |  running |  subnet-127b2c3a7cec5ee02  |  10.20.1.4 |
+----------------------+-----------+----------+----------------------------+------------+
```

`10.20.1.4`, not `.1`: AWS reserves the first four addresses (and the last) of every subnet,
for the network, the VPC router, DNS and future use.

## 4. Idempotency, then destroy

```console
$ terraform plan -detailed-exitcode | tail -3; echo "exit code: ${pipestatus[1]}"

Terraform has compared your real infrastructure against your configuration
and found no differences, so no changes are needed.
exit code: 0

$ terraform state list | wc -l
      17
```

17 = 15 resources + 2 data sources (`aws_availability_zones`, `aws_ami`).

```console
$ terraform destroy -auto-approve | grep -E "Destroying|Destruction complete|Destroy complete"
aws_route_table_association.private[1]: Destroying... [id=rtbassoc-c0a09684c9a73dd02]
aws_security_group.app: Destroying... [id=sg-cfed3975773f647fb]
aws_route_table_association.public[1]: Destroying... [id=rtbassoc-de1b9014eaad61d8d]
aws_route_table_association.private[0]: Destroying... [id=rtbassoc-85bdd1331f0996265]
aws_route_table_association.public[0]: Destroying... [id=rtbassoc-3b39906f27ebba291]
aws_instance.web: Destroying... [id=i-fb1a52f9d9ebc54a0]
aws_route_table_association.public[0]: Destruction complete after 0s
aws_route_table_association.private[1]: Destruction complete after 0s
aws_route_table_association.private[0]: Destruction complete after 0s
aws_route_table_association.public[1]: Destruction complete after 0s
aws_security_group.app: Destruction complete after 0s
aws_route_table.private: Destroying... [id=rtb-50345038c81d2f4dd]
aws_route_table.public: Destroying... [id=rtb-7ccdb1f34990ac5aa]
aws_subnet.private[0]: Destroying... [id=subnet-d036daa78761b9798]
aws_subnet.private[1]: Destroying... [id=subnet-296e639811d542e09]
aws_subnet.private[0]: Destruction complete after 0s
aws_subnet.private[1]: Destruction complete after 0s
aws_route_table.private: Destruction complete after 0s
aws_route_table.public: Destruction complete after 0s
aws_internet_gateway.main: Destroying... [id=igw-ad20f28972c8dd189]
aws_internet_gateway.main: Destruction complete after 0s
aws_instance.web: Destruction complete after 10s
aws_subnet.public[0]: Destroying... [id=subnet-127b2c3a7cec5ee02]
aws_subnet.public[1]: Destroying... [id=subnet-2268c26d90d6ece3b]
aws_security_group.web: Destroying... [id=sg-fac81ae18518f660d]
aws_subnet.public[0]: Destruction complete after 0s
aws_security_group.web: Destruction complete after 0s
aws_subnet.public[1]: Destruction complete after 0s
aws_vpc.main: Destroying... [id=vpc-f177431380bde4338]
aws_vpc.main: Destruction complete after 0s
Destroy complete! Resources: 15 destroyed.

$ aws --endpoint-url http://localhost:5050 ec2 describe-vpcs --filters Name=tag:Session,Values=19 --query 'Vpcs[].VpcId'
[]
```

Note the order: public subnet 1a and `web-sg` could not be deleted until the **instance** was gone
(10s), and the VPC went last. AWS refuses to delete a subnet or SG that still has something in it,
and Terraform's graph already knows that.

## What I took away

- **"Public subnet" is a route, not a setting.** One `0.0.0.0/0 → igw` entry is the entire
  difference.
- **Reference security groups, not IPs.** The app tier's rule has an empty `IpRanges` and still
  does exactly the right thing.
- **`count` + `cidrsubnet()` turns a one-AZ lab into a multi-AZ layout** by changing one number
  (`az_count`), without copy-pasting subnet blocks.
