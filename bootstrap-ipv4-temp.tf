resource "aws_subnet" "public_temp" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "kubernetes-by-the-hour-temp-public"
  }
}

resource "aws_internet_gateway" "temp" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "kubernetes-by-the-hour-temp-bootstrap-igw"
  }
}

resource "aws_route_table" "public_temp" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.temp.id
  }
}

resource "aws_route_table_association" "public_temp" {
  subnet_id      = aws_subnet.public_temp.id
  route_table_id = aws_route_table.public_temp.id
}

resource "aws_eip" "nat_temp" {
  domain = "vpc"

  tags = {
    Name = "kubernetes-by-the-hour-temp-nat-eip"
  }
}

resource "aws_nat_gateway" "temp" {
  subnet_id     = aws_subnet.public_temp.id
  allocation_id = aws_eip.nat_temp.id

  tags = {
    Name = "kubernetes-by-the-hour-temp-nat"
  }
}