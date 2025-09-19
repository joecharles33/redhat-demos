# Get a list of available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Create the VPC
resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.name}-vpc" }
}

# Internet Gateway for outbound internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-igw" }
}

# Decide which AZs we’ll use
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

# Public subnets (1 per AZ)
resource "aws_subnet" "public" {
  for_each                = { for idx, az in local.azs : idx => az }
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr, 4, each.key) # splits CIDR
  availability_zone       = each.value
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.name}-public-${each.value}" }
}

# Private subnets (1 per AZ)
resource "aws_subnet" "private" {
  for_each          = { for idx, az in local.azs : idx => az }
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr, 4, each.key + 8)
  availability_zone = each.value
  tags              = { Name = "${var.name}-private-${each.value}" }
}

# Public route table with internet route
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-public-rt" }
}

resource "aws_route" "public_inet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate public subnets with route table
resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

