data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Add DHCP Options for the AD
resource "aws_vpc_dhcp_options" "this" {
  domain_name          = var.ad_name
  domain_name_servers  = aws_directory_service_directory.this.dns_ip_addresses
  ntp_servers          = aws_directory_service_directory.this.dns_ip_addresses
  netbios_name_servers = aws_directory_service_directory.this.dns_ip_addresses
  netbios_node_type    = 2

  tags = var.tags
}

resource "random_password" "this" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_directory_service_directory" "this" {
  name     = var.ad_name
  password = random_password.this.result
  edition  = "Standard"
  type     = "MicrosoftAD"

  vpc_settings {
    vpc_id     = var.vpc_id
    subnet_ids = [var.subnet_ids[3], var.subnet_ids[4]]
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "ad" {
  name              = "/aws/directoryservice/${aws_directory_service_directory.this.id}"
  retention_in_days = var.ad_log_retention_in_days

  tags = var.tags
}

data "aws_iam_policy_document" "ad_logs" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    principals {
      type        = "Service"
      identifiers = ["ds.amazonaws.com"]
    }

    resources = [
      aws_cloudwatch_log_group.ad.arn,
      "${aws_cloudwatch_log_group.ad.arn}:*",
      "${aws_cloudwatch_log_group.ad.arn}:*:*"
    ]

    effect = "Allow"
  }
}

resource "aws_cloudwatch_log_resource_policy" "ad_logs" {
  policy_document = data.aws_iam_policy_document.ad_logs.json
  policy_name     = "${lookup(var.tags, "ApplicationName")}-${var.environment}-ad-logs"
}

resource "aws_directory_service_log_subscription" "this" {
  directory_id   = aws_directory_service_directory.this.id
  log_group_name = aws_cloudwatch_log_group.ad.name
}

locals {
  root_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
}

data "aws_iam_policy_document" "fsx_key" {

  statement {
    sid       = "IAMUserPermissions"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [local.root_arn]
    }
  }

  statement {
    sid = "FSxPermissions"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:CreateGrant",
      "kms:ListAliases"
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["fsx.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "this" {
  description             = "Encryption key for FSx"
  enable_key_rotation     = var.kms_key_enable_rotation
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  policy                  = data.aws_iam_policy_document.fsx_key.json

  tags = var.tags

}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.kms_key_name}"
  target_key_id = aws_kms_key.this.key_id
}

resource "aws_security_group" "fsx" {
  vpc_id = var.vpc_id

  revoke_rules_on_delete = true

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(var.tags, {
    Name = "${lookup(var.tags, "ApplicationName")}-${var.environment}-fsx-sg"
  })

  name = "${lookup(var.tags, "ApplicationName")}-${var.environment}-fsx-sg"

}

locals {
  fsx_subnet_ids = var.fsx_deployment_type == "MULTI_AZ_1" ? var.subnet_ids : [var.subnet_ids[3]]
}

resource "aws_fsx_windows_file_system" "this" {
  deployment_type     = var.fsx_deployment_type
  storage_type        = var.fsx_storage_type
  active_directory_id = aws_directory_service_directory.this.id
  subnet_ids          = local.fsx_subnet_ids
  preferred_subnet_id = local.fsx_subnet_ids[0]
  kms_key_id          = aws_kms_key.this.arn
  security_group_ids  = [aws_security_group.fsx.id]
  storage_capacity    = var.fsx_storage_capacity
  throughput_capacity = var.fsx_throughput_capacity
  skip_final_backup   = var.fsx_skip_final_backup

  tags = merge(var.tags, {
    Name = var.fsx_file_system_name
  })

}

# Create a secret with a map of the AD information DNS servers, username, password, and domain
resource "aws_secretsmanager_secret" "ad" {
  name                    = var.ad_name
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "ad" {
  secret_id = aws_secretsmanager_secret.ad.id
  secret_string = jsonencode({
    dns_servers = aws_directory_service_directory.this.dns_ip_addresses,
    username    = "admin",
    password    = random_password.this.result,
    domain      = aws_directory_service_directory.this.name
  })
}

# Create an secret with the FSx IP address and service account
resource "aws_secretsmanager_secret" "fsx" {
  name                    = "${var.ad_name}/fsx/${var.fsx_file_system_name}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "fsx" {
  secret_id = aws_secretsmanager_secret.fsx.id
  secret_string = jsonencode({
    ip_address            = aws_fsx_windows_file_system.this.preferred_file_server_ip
    username              = "admin"
    password              = random_password.this.result
    domain                = aws_directory_service_directory.this.name
    dns                   = aws_fsx_windows_file_system.this.dns_name
    remote_admin_endpoint = aws_fsx_windows_file_system.this.remote_administration_endpoint

  })
}


# Source the AMI for windows 2022 base
data "aws_ami" "windows_2022_base_image" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
}


# build small ec2 windows server to manage FSx and the domain
resource "aws_instance" "ad_manager" {
  ami                  = data.aws_ami.windows_2022_base_image.id
  instance_type        = var.ad_manager_instance_type
  iam_instance_profile = aws_iam_instance_profile.ad_manager.name
  key_name             = var.ad_manager_instance_ec2_key_name



  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
  subnet_id              = var.ad_manager_subnet_id != "" ? var.ad_manager_subnet_id : var.subnet_ids[3]
  vpc_security_group_ids = [aws_security_group.fsx.id]

  tags = merge(var.tags, {
    Name = "${lookup(var.tags, "ApplicationName")}-${var.environment}-fsx-ad-manager"
  })

  # Install Active Directory Tools and AWS Tools for PowerShell then join the domain
  user_data = <<-EOF
    <powershell>
    # Install the Active Directory Domain Services role
    Install-WindowsFeature RSAT-AD-PowerShell
    Install-WindowsFeature RSAT-AD-AdminCenter
    Install-WindowsFeature RSAT-ADDS
    Install-WindowsFeature RSAT-AD-Tools
    Install-WindowsFeature RSAT-ADDS-Tools
    Install-WindowsFeature AD-Domain-Services

    # Install AWS Tools for PowerShell
    # Install-PackageProvider -Name NuGet -Force -ForceBootstrap
    # Install-Module -Name AWSPowerShell -Force -AllowClobber

    # Join the domain using the Secrets Manager values
    $domain_info = (Get-SECSecretValue -SecretId "${aws_secretsmanager_secret.ad.arn}" -VersionStage AWSCURRENT).SecretString | ConvertFrom-Json
    $ad_password = $domain_info.password
    $ad_username = $domain_info.username
    $ad_domain   = $domain_info.domain
    $ad_dns      = $domain_info.dns_servers
    
    # Set the DNS Server(s) to the AD DNS Servers
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    $adapter | Set-DnsClientServerAddress -ServerAddresses $ad_dns

    # Create a FSx Script Directory
    $fsx_script_dir = "C:\FSx"
    if (-not (Test-Path $fsx_script_dir)) {
      New-Item -Path $fsx_script_dir -ItemType Directory
    }

    # Create a script to load FSx PS1 file
    $fsx_script = "$fsx_script_dir\fsxBestPracticeCommands.ps1"
    @'
    # This file contains common best practice commands used to manage FSx
    # This file is not intended to be executed entirely and should be opened in PowerShell ISE and executed as individual blocks
    # Note that most commands ran on FSx have limited documentation online, if you need further details pass -? after the primary command to get more info

    # Set this to the Powershell Endpoint for your FSx Server
    $FSxWindowsRemotePowerShellEndpoint = "${aws_fsx_windows_file_system.this.remote_administration_endpoint}"

    # Turns on DeDupe and Sets Minimum File Age to 0 Days
    Invoke-Command -ComputerName $FSxWindowsRemotePowerShellEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock { Enable-FsxDedup }
    Invoke-Command -ComputerName $FSxWindowsRemotePowerShellEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock { Set-FSxDedupConfiguration -MinimumFileAgeDays 0 }

    # Enable Quotas Enforcement
    $QuotaLimit = 100GB
    $QuotaWarningLimit = 90GB

    Invoke-Command -ComputerName $FSxWindowsRemotePowerShellEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock { Enable-FSxUserQuotas -Enforce -DefaultLimit $Using:QuotaLimit -DefaultWarningLimit $Using:QuotaWarningLimit }


    # Enable Quotas Enforcement for a specific user
    $Domain = "${aws_directory_service_directory.this.name}"
    $UserName = "admin"
    $UserQuotaLimit = 50GB
    $UserQuotaWarningLimit = 45GB

    # Enable Quotas Enforcement for a specific user and set Limit to 50GB and Warning Limit to 45GB
    Invoke-Command -ComputerName $FSxWindowsRemotePowerShellEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock { Set-FSxUserQuotas -Domain $Using:Domain -Name $Using:UserName -Limit $Using:UserQuotaLimit -WarningLimit $Using:UserQuotaWarningLimit }

    # Enable shaodw copies to enabled end-users to recover files and folders to previous versions Default Schedule is (7AM and 12Noon)
    Invoke-Command -ComputerName $FSxWindowsRemotePowerShellEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock { Set-FsxShadowStorage -Default }
    Invoke-Command -ComputerName $FSxWindowsRemotePowerShellEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock { Set-FsxShadowCopySchedule -Default -Confirm:$False}

    # Closing Current Sessions and Enforcing encryption in Transit
    Invoke-Command -ComputerName $FSxWindowsRemotePowerShellEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock { Close-FSxSmbSession -Confirm:$False}
    Invoke-Command -ComputerName $FSxWindowsRemotePowerShellEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock { Set-FsxSmbServerConfiguration -EncryptData $True -RejectUnencryptedAccess $True -Confirm:$False}

    #### Reports

    # Monitoring De-Duplication Status
    Invoke-Command -ComputerName $FSxWindowsRemotePowerShellEndpoint -ConfigurationName FsxRemoteAdmin -ScriptBlock { Get-FSxDedupStatus } | select OptimizedFilesCount,OptimizedFilesSize,SavedSpace,OptimizedFilesSavingsRate

    # Monitoring User-Level Storage Consumption
    Invoke-Command -ComputerName $FSxWindowsRemotePowerShellEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock { Get-FSxUserQuotaEntries }

    ### Monitoring and Closing Open Files

    # Checking if any files are opened and who is using it
    Invoke-Command -ComputerName $FSxWindowsRemotePowerShellEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock { Get-FSxSmbOpenFile}

    # Closing Open Files
    Invoke-Command -ComputerName $FSxWindowsRemotePowerShellEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock { Close-FSxSmbOpenFile -Confirm:$false}

    '@ | Out-File $fsx_script

    # Create a shortcut to open Powershell ISE as Administraotr
    $shortcut = "$env:PUBLIC\Desktop\Powershell ISE.lnk"
    $target   = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell_ise.exe"

    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcut)
    $Shortcut.TargetPath = $target
    $Shortcut.Save()

    # Create a shortcut to the mmc snap-in for File Services
    $shortcut = "$env:PUBLIC\Desktop\FSx Management.lnk"
    $target   = "C:\Windows\System32\fsmgmt.msc"

    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcut)
    $Shortcut.TargetPath = $target
    $Shortcut.Save()

    # Get Name tag of the instance if it exists
    $token = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = "21600"} -Method PUT -Uri http://169.254.169.254/latest/api/token
    $instanceId = (Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token" = $token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id)
    $instanceName = (Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token" = $token} -Method GET -Uri http://169.254.169.254/latest/meta-data/tags/instance/Name)
    

    # Join the domain
    Add-Computer -NewName $instanceName -DomainName $ad_domain -Credential (New-Object System.Management.Automation.PSCredential ($ad_username, (ConvertTo-SecureString $ad_password -AsPlainText -Force))) -Restart
    </powershell>
    EOF
}

# Create an instance profile for the EC2 instance that allows SSM parameter access, KMS key access, and SSM Fleet Manager access
resource "aws_iam_instance_profile" "ad_manager" {
  name = "${lookup(var.tags, "ApplicationName")}-${var.environment}-ad-manager"

  role = aws_iam_role.ad_manager.name

  tags = var.tags
}

resource "aws_iam_role" "ad_manager" {
  name = "ad-manager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.ad_manager.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "kms_access" {
  role       = aws_iam_role.ad_manager.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSKeyManagementServicePowerUser"
}

resource "aws_iam_role_policy_attachment" "secret_manager_access" {
  role       = aws_iam_role.ad_manager.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/SecretsManagerReadWrite"
}
