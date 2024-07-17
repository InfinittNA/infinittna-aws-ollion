# ref - https://github.com/aws-samples/amazon-ec2-image-builder-samples/blob/master/CloudFormation/Windows/cascading-images-with-dotnet-web-application/windows-baseline-stack.yml

################################################################################
# Pipeline Configuration
################################################################################

# Create the pipeline configuration
resource "aws_imagebuilder_image_pipeline" "windows" {
  name        = "${lookup(var.tags, "ApplicationName")}-windows"
  description = "This pipeline will build the Windows Server 2022 base image."

  image_recipe_arn                 = aws_imagebuilder_image_recipe.windows_2022_base_image.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.windows.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.windows.arn

  image_tests_configuration {
    image_tests_enabled = true
    timeout_minutes     = 60
  }

  # # In this example, the pipeline is scheduled to run a build at 8:00AM Coordinated Universal Time (UTC) every day.
  schedule {
    schedule_expression = "cron(0 0 * * ? *)"
  }

  status = "ENABLED"

  tags = merge(var.tags,
    {
      Purpose = "ImageBuilder"
    }
  )
}


################################################################################
# Distribution Configuration
################################################################################

# Get current account ID
data "aws_caller_identity" "current" {}

# Create the distribution configuration
resource "aws_imagebuilder_distribution_configuration" "windows" {
  name        = "${lookup(var.tags, "ApplicationName")}-windows-base"
  description = "This distribution configuration will distribute the image to the provided regions."

  distribution {
    ami_distribution_configuration {
      ami_tags = var.tags

      name = "${lookup(var.tags, "ApplicationName")}-windows-server-2022-base-{{ imagebuilder:buildDate }}"

      launch_permission {
        user_ids = [data.aws_caller_identity.current.account_id]
      }
    }

    region = var.region
  }

  tags = merge(var.tags,
    {
      Purpose = "ImageBuilder",
      Name    = "${lookup(var.tags, "ApplicationName")}-windows-server-2022-base",
    }
  )
}

################################################################################
# Infrastructure
################################################################################

# Create the InfrastructureConfiguration
resource "aws_imagebuilder_infrastructure_configuration" "windows" {
  name                  = "${lookup(var.tags, "ApplicationName")}-windows"
  description           = "This infrastructure configuration will launch into the provided VPC."
  instance_profile_name = aws_iam_instance_profile.image_builder.name

  subnet_id          = data.terraform_remote_state.vpc.outputs.networking_module.private_subnets[0]
  security_group_ids = [aws_security_group.image_builder.id]

  instance_types = ["m5.large"]
  key_pair       = "dcc-test"

  terminate_instance_on_failure = true

  logging {
    s3_logs {
      s3_bucket_name = aws_s3_bucket.image_builder_logs.bucket
      s3_key_prefix  = "image-builder-logs"
    }
  }

  tags = var.tags
}


################################################################################
# Recipes
################################################################################

# Windows Server Base AMI for Server 2022
data "aws_ami" "windows" {
  most_recent = true
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["801119661308"] # amazon
}

# Create the recipe for the image builder
resource "aws_imagebuilder_image_recipe" "windows_2022_base_image" {
  version     = "1.0.0"
  name        = "${lookup(var.tags, "ApplicationName")}-windows"
  description = "This recipe will setup the Windows Server 2022 operating system."

  working_directory = "C:\\"

  parent_image = data.aws_ami.windows.id

  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:aws:component/update-windows/x.x.x"
  }

  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:aws:component/aws-cli-version-2-windows/x.x.x"
  }

  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:aws:component/powershell-windows/x.x.x"
  }

  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:aws:component/windows-activation-test/x.x.x"
  }

  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:aws:component/reboot-test-windows/x.x.x"
  }

  # https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2-windows-volumes.html
  block_device_mapping {
    device_name = "/dev/sda1"

    ebs {
      delete_on_termination = true
      volume_size           = 100
      volume_type           = "gp3"
    }
  }

  tags = var.tags
}

################################################################################
# Supporting Resources
################################################################################

# Create CloudWatch log group for the image builder
resource "aws_cloudwatch_log_group" "image_builder" {
  name              = "${lookup(var.tags, "ApplicationName")}-image-builder"
  retention_in_days = 7
  tags              = var.tags
}

# Create a log bucket for the image builder
resource "aws_s3_bucket" "image_builder_logs" {
  bucket = "${lookup(var.tags, "ApplicationName")}-image-builder-logs"

  force_destroy = true

  tags = merge(var.tags, {
    Project = "Secret"
    Logs    = "true"
  })
}

# Set bucket encryption
resource "aws_s3_bucket_policy" "image_builder_logs" {
  bucket = aws_s3_bucket.image_builder_logs.bucket
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "${aws_s3_bucket.image_builder_logs.arn}",
          "${aws_s3_bucket.image_builder_logs.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Set bucket public access block
resource "aws_s3_bucket_public_access_block" "image_builder_logs" {
  bucket                  = aws_s3_bucket.image_builder_logs.bucket
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Set bucket versioning
resource "aws_s3_bucket_versioning" "image_builder_logs" {
  bucket = aws_s3_bucket.image_builder_logs.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

# Create a role for the image builder
resource "aws_iam_role" "image_builder" {
  name = "${lookup(var.tags, "ApplicationName")}-image-builder"
  path = "/service-role/"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# Attach the AmazonSSMManagedInstanceCore policy to the image builder role
resource "aws_iam_role_policy_attachment" "image_builder" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.image_builder.name
}

# Attach the AmazonEC2RoleforSSM policy to the image builder role
resource "aws_iam_role_policy_attachment" "image_builder_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
  role       = aws_iam_role.image_builder.name
}

# Attach the policy to the image builder role
resource "aws_iam_role_policy_attachment" "image_builder_logs" {
  policy_arn = aws_iam_policy.image_builder_logs.arn
  role       = aws_iam_role.image_builder.name
}

# Create a policy to allow the image builder to access the log bucket
resource "aws_iam_policy" "image_builder_logs" {
  name        = "${lookup(var.tags, "ApplicationName")}-image-builder-logs"
  path        = "/service-role/"
  description = "Policy to allow the image builder to access the log bucket"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          # "s3:GetBucketAcl",
          # "s3:GetBucketLocation",
          # "s3:GetObject",
          # "s3:ListBucket",
          # "s3:ListBucketMultipartUploads",
          # "s3:ListMultipartUploadParts"
        ],
        Resource = [
          aws_s3_bucket.image_builder_logs.arn,
          "${aws_s3_bucket.image_builder_logs.arn}/*"
        ]
      }
    ]
  })

  tags = var.tags
}

# Create the image builder instance profile
resource "aws_iam_instance_profile" "image_builder" {
  name = "${lookup(var.tags, "ApplicationName")}-image-builder"
  role = aws_iam_role.image_builder.name
  path = "/executionServiceEC2Role/"

  tags = var.tags
}

# Create a image builder iam policy
resource "aws_iam_policy" "image_builder_access" {
  name        = "${lookup(var.tags, "ApplicationName")}-image-builder"
  path        = "/service-role/"
  description = "Policy to allow the image builder to access the log bucket"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:Describe*",
          "imagebuilder:*",
        ],
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# Attach the policy to the image builder role
resource "aws_iam_role_policy_attachment" "image_builder_access" {
  policy_arn = aws_iam_policy.image_builder_access.arn
  role       = aws_iam_role.image_builder.name
}



# Create a security group for the image builder
resource "aws_security_group" "image_builder" {
  name_prefix = "${lookup(var.tags, "ApplicationName")}-image-builder"
  description = "Allow all traffic to the image builder"
  vpc_id      = data.terraform_remote_state.vpc.outputs.networking_module.vpc_id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.vpc.outputs.networking_module.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}
