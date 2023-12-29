## region
provider "aws" {
  region = "eu-central-1"
}
##


## s3 bucket creation
resource "aws_s3_bucket" "devops-tbc-vtabatadze" {
    bucket = var.s3bucketname
  }
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = var.s3bucketname
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = var.s3bucketname

  policy = jsonencode({
    Version   = "2012-10-17",
    Id        = "bucketpolicy_public",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = ["s3:GetObject"],
        Resource  = ["${aws_s3_bucket.devops-tbc-vtabatadze.arn}/index.html"],
      },
    ],
  })
}

resource "aws_s3_bucket_website_configuration" "static_website" {
  bucket = var.s3bucketname
  index_document {
    suffix = "index.html"
  }
}
output "devops-tbc-arn" {
  value = aws_s3_bucket.devops-tbc-vtabatadze.arn
}
##


## iam policy to access rds
resource "aws_iam_policy" "ec2_read_only_policy" {
  name        = "EC2ReadOnlyPolicy"
  description = "Policy for read-only access from EC2 to RDS"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "rds:DescribeDBInstances",
          "rds:ListTagsForResource",
          "rds:ListTagsForResource",
          "rds:DescribeDBClusters",
          "rds:DescribeDBClusterSnapshots",
          "rds:DescribeDBClusterParameterGroups",
          "rds:DescribeDBClusterParameters",
          "rds:DescribeDBEngineVersions",
          "rds:DescribeDBParameterGroups",
          "rds:DescribeDBParameters",
          "rds:DescribeDBSnapshots",
          "rds:DescribeDBSubnetGroups",
          "rds:DescribeEventCategories",
          "rds:DescribeEventSubscriptions",
          "rds:DescribeEvents",
          "rds:DescribeOptionGroups",
          "rds:DescribeOptionGroupOptions",
        ],
        Resource = "*",
      },
    ],
  })
}
##


## iam role for ec2 instance with rds and s3 access rights
resource "aws_iam_role" "ec2_1_role" {
  name = "ec2_1_role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { 
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_policy_attachment" {
  policy_arn = aws_iam_policy.ec2_read_only_policy.arn
  role       = aws_iam_role.ec2_1_role.name
}
##

## ec2 security group for ssh and web traffic
resource "aws_security_group" "ec2_1_instance" {
  name        = "ssh-web"
  description = "security group for ssh and web traffice"
#  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
##


## key pair for ssh
resource "aws_key_pair" "ssh" {
  key_name   = "ssh_key"
  public_key = file("./id_rsa.pub")
}
##


## ec2 instance creation
resource "aws_instance" "ec2_1" {
  ami             = "ami-02da8ff11275b7907"
  instance_type   = "t2.micro"
  key_name 	  = aws_key_pair.ssh.key_name
  security_groups = [aws_security_group.ec2_1_instance.name]
#
  ebs_block_device {
    device_name	 = "/dev/sdb"
    volume_size  = 5
  }
  iam_instance_profile = aws_iam_instance_profile.ec2_1_instance_profile.name
  tags = {
    Name = "ec2_1"
  }
}
resource "aws_iam_instance_profile" "ec2_1_instance_profile" {
  name = "ec2_1_instance_profile"
  role = aws_iam_role.ec2_1_role.name
}
output "ec2_instance_private_ip" {
  value = aws_instance.ec2_1.private_ip
}
output "ec2_instance_public_dns" {
  value = aws_instance.ec2_1.public_dns
} 
##


## secrets manager password generation
resource "random_password" "master" {
  length	   = 16
  special	   = true
  override_special = "!%_^"
}
resource "aws_secretsmanager_secret" "password" {
  name = "postgres13-password"
}
resource "aws_secretsmanager_secret_version" "password" {
  secret_id = aws_secretsmanager_secret.password.id
  secret_string = random_password.master.result
  depends_on = [aws_secretsmanager_secret.password]
}
##

## rds postgres creation
data "aws_secretsmanager_secret_version" "password" {
  secret_id = aws_secretsmanager_secret.password.id
  depends_on = [aws_secretsmanager_secret_version.password]
}
resource "aws_db_instance" "postgresql" {
  identifier	      	 = "postresql" 
  allocated_storage  	 = 5
  storage_type       	 = "gp2"
  engine              	 = "postgres"
  engine_version      	 = "12.13"
  instance_class      	 = "db.t2.micro"
  parameter_group_name	 = "default.postgres12"
  publicly_accessible 	 = false
  skip_final_snapshot 	 = true
  multi_az            	 = false
  username            	 = "demo"
  password            	 = data.aws_secretsmanager_secret_version.password.secret_string
  vpc_security_group_ids = [aws_security_group.instance.id]

  tags = {
    Name = "postgresql"
  }

}
resource "aws_security_group" "instance" {
  name = "postgresql-demo-instance"
  ingress {
    from_port	= 5432
    to_port	= 5432
    protocol	= "tcp"
    cidr_blocks	= ["${aws_instance.ec2_1.private_ip}/32"]
 }
}
##


## cloudfront distribution
resource "aws_cloudfront_distribution" "cloudfront-tbc" {
  origin {
    domain_name = aws_instance.ec2_1.public_dns
    origin_id   = "ec2_1-origin"
    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    target_origin_id       = "ec2_1-origin"
    viewer_protocol_policy = "redirect-to-https"
    cached_methods         = ["GET", "HEAD"]
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    compress               = true
    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
##

