resource "aws_vpc" "main" {
  cidr_block                       = "10.0.0.0/16"
  assign_generated_ipv6_cidr_block = true
}

resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  ipv6_cidr_block   = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, 1)
  availability_zone = "us-east-1a"

  assign_ipv6_address_on_creation = true
  map_public_ip_on_launch         = false
}
#enable_dns64                    = true


resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.main.id
  }
  #NAT64 bootstrap
#route {
    #ipv6_cidr_block = "64:ff9b::/96"
   # nat_gateway_id  = aws_nat_gateway.temp.id
  #}
}

resource "aws_egress_only_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}
resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}