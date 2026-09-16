provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "kubernetes-by-the-hour"
      Component = "permanent"
    }
  }
}