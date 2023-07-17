locals {
  vpc_name               = "vpc-dev"
  vpc_cidr               = "10.10.0.0/18"
  vpc_enable_dns         = true
  vpc_instance_tenancy   = "default"
  vpc_network_monitoring = true

  igw_name = "igw-dev"

  availability_zones = [
    "ap-southeast-1a",
    "ap-southeast-1b",
  ]

  subnet_cidr = cidrsubnets(
    local.vpc_cidr,
    4, 4, # public
    4, 4, # data
    3, 3, # app
  )
}



resource "aws_vpc" "main" {
  cidr_block                           = local.vpc_cidr
  instance_tenancy                     = local.vpc_instance_tenancy
  enable_dns_support                   = local.vpc_enable_dns
  enable_dns_hostnames                 = local.vpc_enable_dns
  enable_network_address_usage_metrics = local.vpc_network_monitoring

  tags = {
    Name = local.vpc_name
  }
}

resource "aws_subnet" "public" {
  count = length(local.availability_zones)

  vpc_id                  = aws_vpc.main.id
  availability_zone       = local.availability_zones[count.index]
  cidr_block              = local.subnet_cidr[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-public-${substr(local.availability_zones[count.index], -1, 1)}"
  }
}

resource "aws_subnet" "data" {
  count = length(local.availability_zones)

  vpc_id                  = aws_vpc.main.id
  availability_zone       = local.availability_zones[count.index]
  cidr_block              = local.subnet_cidr[count.index + length(local.availability_zones)]
  map_public_ip_on_launch = false

  tags = {
    Name = "subnet-data-${substr(local.availability_zones[count.index], -1, 1)}"
  }
}

resource "aws_subnet" "app" {
  count = length(local.availability_zones)

  vpc_id                  = aws_vpc.main.id
  availability_zone       = local.availability_zones[count.index]
  cidr_block              = local.subnet_cidr[count.index + 2 * length(local.availability_zones)]
  map_public_ip_on_launch = false

  tags = {
    Name = "subnet-app-${substr(local.availability_zones[count.index], -1, 1)}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = local.igw_name
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "rt-public"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}