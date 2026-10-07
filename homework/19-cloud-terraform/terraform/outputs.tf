output "vpc_id" {
  value = aws_vpc.main.id
}

output "availability_zones" {
  value = local.azs
}

output "public_subnets" {
  value = { for s in aws_subnet.public : s.availability_zone => "${s.id} (${s.cidr_block})" }
}

output "private_subnets" {
  value = { for s in aws_subnet.private : s.availability_zone => "${s.id} (${s.cidr_block})" }
}

output "web_sg_id" {
  value = aws_security_group.web.id
}

output "app_sg_id" {
  value = aws_security_group.app.id
}

output "web_instance" {
  value = {
    id         = aws_instance.web.id
    ami        = aws_instance.web.ami
    private_ip = aws_instance.web.private_ip
    public_ip  = aws_instance.web.public_ip
  }
}
