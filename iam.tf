resource "aws_iam_role" "node" {
  name = "kubernetes-by-the-hour-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "node" {
  name = "kubernetes-by-the-hour-node-profile"
  role = aws_iam_role.node.name
}

resource "aws_iam_role_policy" "node_cloudwatch_logs" {
  name = "cloudwatch-logs-emf"
  role = aws_iam_role.node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:us-east-1:*:log-group:/otel/kubernetes-by-the-hour/*"
      }
    ]
  })
}