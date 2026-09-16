resource "aws_security_group" "node" {
  name        = "kubernetes-by-the-hour-node-sg"
  description = "Outbound only. No inbound rules needed for Tailscale."
  vpc_id      = aws_vpc.main.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "node" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.node.id]
  ipv6_address_count     = 1
  iam_instance_profile   = aws_iam_instance_profile.node.name

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
  }

  user_data = templatefile("cloud-init.yaml", {
    tailscale_authkey = var.tailscale_authkey
  })

  tags = {
    Name = "kubernetes-by-the-hour-node"
  }
}