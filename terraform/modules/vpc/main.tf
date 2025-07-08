# main.tf - VPC module

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name}-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true # Public instances need public IPs

  tags = {
    Name = "${var.name}-public-subnet-${count.index + 1}"
  }
}

# Private Application Subnets
resource "aws_subnet" "private_app" {
  count                   = length(var.private_app_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_app_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false # Private instances should not have public IPs

  tags = {
    Name = "${var.name}-private-app-subnet-${count.index + 1}"
  }
}

# Private Database Subnets
resource "aws_subnet" "private_db" {
  count                   = length(var.private_db_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_db_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false # Private instances should not have public IPs

  tags = {
    Name = "${var.name}-private-db-subnet-${count.index + 1}"
  }
}

# NAT Gateways in Public Subnets (one per AZ)
resource "aws_eip" "nat" {
  count  = length(aws_subnet.public)
  domain = "vpc"

  tags = {
    Name = "${var.name}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "main" {
  count         = length(aws_subnet.public)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.name}-nat-gateway-${count.index + 1}"
  }
  # Add depends_on to ensure NAT Gateway is created after EIP
  depends_on = [aws_internet_gateway.main, aws_eip.nat]
}

# Route Tables

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.name}-public-rt"
  }
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table for Private App Subnets (one per AZ, pointing to NAT Gateway)
resource "aws_route_table" "private_app" {
  count  = length(aws_subnet.private_app)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"

    # Only reference NAT GW if it exists at this index
    nat_gateway_id = length(aws_nat_gateway.main) > count.index ? aws_nat_gateway.main[count.index].id : aws_nat_gateway.main[0].id
  }

  tags = {
    Name = "${var.name}-private-app-rt${count.index + 1}"
  }

  depends_on = [aws_nat_gateway.main] # Ensure NAT GWs are created first
}

# Associate Private App Subnets with their respective Private App Route Tables
resource "aws_route_table_association" "private_app" {
  count          = length(aws_subnet.private_app)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

# Route Table for Private Database Subnets (No direct internet access)
resource "aws_route_table" "private_db" {
  count  = length(aws_subnet.private_db)
  vpc_id = aws_vpc.main.id

  # No direct internet route, all traffic stays within VPC or goes to NAT GW if needed by DB (rare for outbound)
  # If DB needs to reach internet for updates/patches, add a route to NAT Gateway.
  # For security, typically DB subnets are isolated.
  # For now, no internet route for DB subnets.

  tags = {
    Name = "${var.name}-private-db-rt${count.index + 1}"
  }
}

# Associate Private Database Subnets with their respective Private DB Route Tables
resource "aws_route_table_association" "private_db" {
  count          = length(aws_subnet.private_db)
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db[count.index].id
}

# Data source to get available AZs in the specified region
data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "region-name"
    values = [var.aws_region]
  }
}
