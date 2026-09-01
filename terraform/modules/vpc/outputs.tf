output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, ordered by availability zone"
  value       = [for az in local.azs : aws_subnet.public[az].id]
}

output "private_app_subnet_ids" {
  description = "IDs of the private application subnets, ordered by availability zone"
  value       = [for az in local.azs : aws_subnet.private_app[az].id]
}

output "private_db_subnet_ids" {
  description = "IDs of the private database subnets, ordered by availability zone"
  value       = [for az in local.azs : aws_subnet.private_db[az].id]
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = aws_nat_gateway.this[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.this.id
}
