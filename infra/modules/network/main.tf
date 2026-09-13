data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_prefix_list" "dynamodb" {
  name = "com.amazonaws.${var.region}.dynamodb"
}

resource "aws_vpc" "this" {
  cidr_block = var.cidr_block

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

# Private only. There is no internet gateway and no NAT, so nothing in this
# VPC can reach or be reached from the internet.
resource "aws_subnet" "private" {
  count = var.subnet_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.name_prefix}-private-${count.index + 1}"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count = var.subnet_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# A gateway endpoint is how a private Lambda reaches DynamoDB. It adds a route
# to the table rather than an ENI, so it costs nothing and keeps the traffic
# on the AWS network. The alternative, a NAT gateway, is around 32 USD a month
# and sends the traffic out over the internet.
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "${var.name_prefix}-dynamodb-endpoint"
  }
}

# Egress is declared inline so Terraform manages the whole rule set and the
# default allow-all egress rule AWS attaches to a new group is removed. The
# result is a function that can reach DynamoDB and nothing else. No ingress
# rules, because nothing connects to a Lambda.
resource "aws_security_group" "lambda" {
  name        = "${var.name_prefix}-lambda-sg"
  description = "Allows the ${var.name_prefix} health check function to reach DynamoDB."
  vpc_id      = aws_vpc.this.id

  egress {
    description     = "HTTPS to DynamoDB through the gateway endpoint"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [data.aws_prefix_list.dynamodb.id]
  }

  tags = {
    Name = "${var.name_prefix}-lambda-sg"
  }
}
