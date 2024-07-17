# ref - https://github.com/aws-samples/amazon-ec2-image-builder-samples/blob/master/CloudFormation/Windows/cascading-images-with-dotnet-web-application/windows-dotnet-application-stack.yml

# Get current account ID
data "aws_caller_identity" "current" {}

################################################################################
# Pipeline Configuration
################################################################################

# Create the pipeline configuration
resource "aws_imagebuilder_image_pipeline" "windows" {
  name        = "${lookup(var.tags, "ApplicationName")}-windows-dotnet"
  description = "This pipeline will build the Windows Server 2022 base image."

  image_recipe_arn                 = aws_imagebuilder_image_recipe.windows_dotnet.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.windows.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.windows.arn

  image_tests_configuration {
    image_tests_enabled = true
    timeout_minutes     = 60
  }

  # # In this example, the pipeline is scheduled to run a build at 8:00AM Coordinated Universal Time (UTC) every day.
  schedule {
    schedule_expression                = "cron(0 10 * * ? *)"
    pipeline_execution_start_condition = "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE"
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

# Create the distribution configuration
resource "aws_imagebuilder_distribution_configuration" "windows" {
  name        = "${lookup(var.tags, "ApplicationName")}-windows-dotnet"
  description = "This distribution configuration will distribute the image to the provided regions."

  distribution {
    ami_distribution_configuration {
      ami_tags = var.tags

      name = "${lookup(var.tags, "ApplicationName")}-windows-server-2022-dotnet-{{ imagebuilder:buildDate }}"

      launch_permission {
        user_ids = [data.aws_caller_identity.current.account_id]
      }
    }

    region = var.region
  }

  tags = merge(var.tags,
    {
      Purpose = "ImageBuilder",
      Name    = "${lookup(var.tags, "ApplicationName")}-windows-server-2022-dotnet",
    }
  )
}

################################################################################
# Recipes
################################################################################

# Source our base Windows Server 2022 AMI
data "aws_ami" "windows" {
  most_recent = true

  filter {
    name   = "name"
    values = ["${data.terraform_remote_state.base_windows_server_2022.outputs.base_windows_server_ami_name}-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["self"]
}

resource "aws_imagebuilder_image_recipe" "windows_dotnet" {
  name         = "${lookup(var.tags, "ApplicationName")}-windows-dotnet"
  description  = "This recipe will install the .NET runtime and create a custom Windows Service for a .NET web application."
  parent_image = data.aws_ami.windows.id
  version      = "1.0.0"

  working_directory = "C:\\"

  block_device_mapping {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 100
      volume_type = "gp3"
    }
  }

  component {
    component_arn = aws_imagebuilder_component.windows_nssm_install.arn
  }

  component {
    component_arn = aws_imagebuilder_component.windows_website_install.arn
  }

  tags = var.tags
}

resource "aws_imagebuilder_component" "windows_nssm_install" {
  name               = "${lookup(var.tags, "ApplicationName")}-NSSM"
  description        = "NSSM can be used to create a custom Windows Service. This component will download and install NSSM. The `Path` environment variable will also be updated."
  change_description = "Created with Terraform"

  platform              = "Windows"
  supported_os_versions = ["Microsoft Windows Server 2022"]
  version               = "1.0.0"

  data = <<-EOT
    name: "${lookup(var.tags, "ApplicationName")}-NSSM"
    description: NSSM can be used to create a custom Windows Service. This component will download and install NSSM. The `Path` environment variable will also be updated.
    schemaVersion: 1.0
    
    
    constants:
      - Application:
          type: string
          value: NSSM
      - Source:
          type: string
          value: https://nssm.cc/release/nssm-2.24.zip
    phases:
      - name: build
        steps:
          - name: ZipFile
            action: ExecutePowerShell
            inputs:
              commands:
                - $filename = '{{ Source }}'.split('/')[-1]
                - Join-Path -Path $env:TEMP -ChildPath $filename
          - name: TemporaryPath
            action: ExecutePowerShell
            inputs:
              commands:
                - Join-Path -Path $env:TEMP -ChildPath '{{ Application }}'
          - name: InstallPath
            action: ExecutePowerShell
            inputs:
              commands:
                - Join-Path -Path $env:ProgramFiles -ChildPath '{{ Application }}'
          - name: DownloadNSSM
            action: WebDownload
            inputs:
              - source: '{{ Source }}'
                destination: '{{ build.ZipFile.outputs.stdout }}'
                overwrite: true
          - name: ExtractNSSMZipFile
            action: ExecutePowerShell
            inputs:
              commands:
                - $ErrorActionPreference = 'Stop'
                - $ProgressPreference = 'SilentlyContinue'
                - Write-Host "Extracting '{{ build.ZipFile.outputs.stdout }}' to '{{ build.TemporaryPath.outputs.stdout }}'..."
                - Expand-Archive -Path '{{ build.ZipFile.outputs.stdout }}' -DestinationPath '{{ build.TemporaryPath.outputs.stdout }}' -Force
          - name: NSSMExtractedSource
            action: ExecutePowerShell
            inputs:
              commands:
                - $ErrorActionPreference = 'Stop'
                - (Get-ChildItem -Path '{{ build.TemporaryPath.outputs.stdout }}' | Where-Object {$_.Name -like 'nssm*'} | Select-Object -First 1).FullName
          - name: MoveSourceToDesiredInstallationFolder
            action: MoveFolder
            inputs:
              - source: '{{ build.NSSMExtractedSource.outputs.stdout }}'
                destination: '{{ build.InstallPath.outputs.stdout }}'
                overwrite: true
          - name: UpdatePath
            action: ExecutePowerShell
            inputs:
              commands:
                - |
                  $ErrorActionPreference = 'Stop'
                  $currentPath = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::Machine)
                  $separator = [System.IO.Path]::PathSeparator
                  $addition = 'C:\Program Files\NSSM\win64'
                  $newPath = '{0}{1}{2}' -f $currentPath, $separator, $addition
                  [Environment]::SetEnvironmentVariable('Path', $newPath, [EnvironmentVariableTarget]::Machine)
          - name: RebootForPathUpdate
            action: Reboot
  EOT

  tags = var.tags
}

resource "aws_imagebuilder_component" "windows_website_install" {
  name               = "${lookup(var.tags, "ApplicationName")}--website-installation"
  description        = "Downloads and installs a .NET web application as a Windows Service using NSSM."
  change_description = "Created with Terraform"

  platform              = "Windows"
  supported_os_versions = ["Microsoft Windows Server 2022"]
  version               = "1.0.0"

  data = <<-EOT
    name: "${lookup(var.tags, "ApplicationName")}--website-installation"
    description: Downloads and installs a .NET web application as a Windows Service using NSSM.
    schemaVersion: 1.0
    
    
    constants:
          - Source:
              type: string
              value: '${var.DotnetS3SourceZipFile}'
          - DotnetBinaryName:
              type: string
              value: '${var.DotnetBinaryName}'
          - WebsiteName:
              type: string
              value: '${var.WebsiteName}'
          - TCPPort:
              type: string
              value: '${var.TCPPort}'
          - HTMLTitleValidationString:
              type: string
              value: '${var.HTMLTitleValidationString}'
    phases:
          - name: build
            steps:
              - name: WebsitePath
                action: ExecutePowerShell
                inputs:
                  commands:
                    - Write-Host "$env:SystemDrive\{{ WebsiteName }}"
              - name: ZipFile
                action: ExecutePowerShell
                inputs:
                  commands:
                    - $filename = '{{ Source }}'.split('/')[-1]
                    - Join-Path -Path $env:TEMP -ChildPath $filename
              - name: DownloadZipFile
                action: S3Download
                inputs:
                  - source: '{{ Source }}'
                    destination: '{{ build.ZipFile.outputs.stdout }}'
              - name: EnsureWebsiteFolderDoesNotExist
                action: DeleteFolder
                inputs:
                  - path: '{{ build.WebsitePath.outputs.stdout }}'
                    force: true
              - name: CreateWebsiteFolder
                action: CreateFolder
                inputs:
                  - path: '{{ build.WebsitePath.outputs.stdout }}'
              - name: ExtractWebsite
                action: ExecutePowerShell
                inputs:
                  commands:
                    - $ErrorActionPreference = 'Stop'
                    - $ProgressPreference = 'SilentlyContinue'
                    - Write-Host "Extracting '{{ build.ZipFile.outputs.stdout }}' to '{{ build.WebsitePath.outputs.stdout }}'..."
                    - Expand-Archive -Path '{{ build.ZipFile.outputs.stdout }}' -DestinationPath '{{ build.WebsitePath.outputs.stdout }}'
              - name: CreateWindowsService
                action: ExecuteBinary
                inputs:
                  path: nssm.exe
                  arguments:
                    - 'install'
                    - '{{ WebsiteName }}'
                    - '{{ build.WebsitePath.outputs.stdout }}\{{ DotnetBinaryName }}'
              - name: SetServiceStartupDirectory
                action: ExecuteBinary
                inputs:
                  path: nssm.exe
                  arguments:
                    - 'set'
                    - '{{ WebsiteName }}'
                    - 'AppDirectory'
                    - '{{ build.WebsitePath.outputs.stdout }}'
              - name: CreateFirewallRule
                action: ExecutePowerShell
                inputs:
                  commands:
                    - |
                      $ErrorActionPreference = 'Stop'
                      if (Get-NetFirewallRule -Name '{{ WebsiteName }}' -ErrorAction SilentlyContinue) {
                          Write-Host 'The firewall rule allowing inbound TCP/{{ TCPPort }} traffic already exists.'
                      } else {
                          Write-Host 'Creating a firewall rule allowing inbound TCP/{{ TCPPort }} traffic'
                          $newNetFirewallRule = @{
                              Name = '{{ WebsiteName }}'
                              DisplayName = '{{ WebsiteName }}'
                              Description = 'Allows inbound traffic for the {{ WebsiteName }} website'
                              Enabled = 'true' # This must be a string, not a bool.
                              Profile = 'Any'
                              Direction = 'Inbound'
                              Action = 'Allow'
                              Protocol = 'TCP'
                              LocalPort = '{{ TCPPort }}'
                              ErrorAction = 'SilentlyContinue'
                          }
                          New-NetFirewallRule @newNetFirewallRule
                      }
              - name: StartService
                action: ExecutePowerShell
                inputs:
                  commands:
                    - $ErrorActionPreference = 'Stop'
                    - Start-Service -Name '{{ WebsiteName }}'
              - name: CleanupZipFiles
                action: DeleteFile
                inputs:
                  - path: '{{ build.ZipFile.outputs.stdout }}'

          - name: validate
            steps:
              - name: TestWebsite
                action: ExecutePowerShell
                maxAttempts: 3
                inputs:
                  commands:
                    - |
                      $ErrorActionPreference = 'Stop'
                      try {
                          $content = (Invoke-WebRequest -uri http://localhost:{{ TCPPort }} -UseBasicParsing).content
                          if ($content -like '*<title>{{ HTMLTitleValidationString }}</ title>*') {
                              Write-Host 'The website is responding on TCP/{{ TCPPort }}'
                          } else {
                              throw 'The website is not responding on TCP/{{ TCPPort }}. Failed validation.'
                          }
                      } catch {
                          # Something failed. Sleep before allowing retry
                          Start-Sleep -Seconds 15
                      }

          - name: test
            steps:
              - name: TestWebsite
                action: ExecutePowerShell
                maxAttempts: 3
                inputs:
                  commands:
                    - |
                      $ErrorActionPreference = 'Stop'
                      try {
                          $content = (Invoke-WebRequest -uri http://localhost:{{ TCPPort }} -UseBasicParsing).content
                          if ($content -like '*<title>{{ HTMLTitleValidationString }}</ title>*') {
                              Write-Host 'The website is responding on TCP/{{ TCPPort }}'
                          } else {
                              throw 'The website is not responding on TCP/{{ TCPPort }}. Failed validation.'
                          }
                      } catch {
                          # Something failed. Sleep before allowing retry
                          Start-Sleep -Seconds 15
                      }
  EOT

  tags = var.tags
}


################################################################################
# Infrastructure
################################################################################

# Create the InfrastructureConfiguration
resource "aws_imagebuilder_infrastructure_configuration" "windows" {
  name                  = "${lookup(var.tags, "ApplicationName")}-windows-dotnet"
  description           = "This infrastructure configuration will launch into the provided VPC."
  instance_profile_name = aws_iam_instance_profile.image_builder.name

  subnet_id          = data.terraform_remote_state.vpc.outputs.networking_module.private_subnets[0]
  security_group_ids = [aws_security_group.image_builder.id]

  instance_types = ["m5.large"]
  key_pair       = "dcc-test"

  terminate_instance_on_failure = false

  logging {
    s3_logs {
      s3_bucket_name = aws_s3_bucket.image_builder_logs.bucket
      s3_key_prefix  = "windows-2022-dotnet-imagebuilder-logs"
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
resource "aws_iam_role_policy_attachment" "image_builder_instance_core" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.image_builder.name
}

# Attach the EC2InstanceProfileForImageBuilder policy to the image builder role
resource "aws_iam_role_policy_attachment" "image_builder_profile" {
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
  role       = aws_iam_role.image_builder.name
}

# Attach the AmazonEC2RoleforSSM policy to the image builder role
resource "aws_iam_role_policy_attachment" "image_builder_s3_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
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
