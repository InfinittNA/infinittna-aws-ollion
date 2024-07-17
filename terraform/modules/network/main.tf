data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "${lookup(var.tags, "ApplicationName")}-vpc"
  cidr = var.vpc_cidr_block

  azs              = local.azs
  public_subnets   = var.vpc_public_subnets
  private_subnets  = var.vpc_private_subnets
  database_subnets = var.vpc_database_subnets

  public_subnet_names   = var.vpc_public_subnet_names
  private_subnet_names  = var.vpc_private_subnet_names
  database_subnet_names = var.vpc_database_subnet_names

  create_database_subnet_group  = var.create_database_subnet_group
  manage_default_security_group = true
  manage_default_network_acl    = false

  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  enable_nat_gateway     = var.enable_nat_gateway
  one_nat_gateway_per_az = var.enable_one_nat_gateway_per_az
  single_nat_gateway     = false

  # For VPN Gateway connections
  # enable_vpn_gateway = true
  # customer_gateways = {
  #   IP1 = {
  #     bgp_asn     = 65112
  #     ip_address  = "1.2.3.4"
  #     device_name = "${lookup(var.tags, "ApplicationName")}-some_name"
  #   },
  #   IP2 = {
  #     bgp_asn    = 65112
  #     ip_address = "5.6.7.8"
  #   }
  # }

  # Enable this after FSx is deployed if you want to auto assign the DHCP options to the managed AD Servers
  # enable_dhcp_options              = true
  # dhcp_options_domain_name         = "service.consul"
  # dhcp_options_domain_name_servers = ["127.0.0.1", "10.10.0.2"]

  # VPC Flow Logs (Cloudwatch log group and IAM role will be created)
  enable_flow_log                      = var.enable_flow_log
  create_flow_log_cloudwatch_log_group = var.enable_flow_log_cloudwatch_log_group
  create_flow_log_cloudwatch_iam_role  = var.create_flow_log_cloudwatch_iam_role
  flow_log_max_aggregation_interval    = 60

  tags = var.tags
}

# ################################################################################
# # VPC Endpoints Module
# ################################################################################

module "vpc_endpoints" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  # version = "5.0.0"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [data.aws_security_group.default.id]

  endpoints = {
    s3 = {
      service = "s3"
      tags    = { Name = "${lookup(var.tags, "ApplicationName")}-s3-vpc-endpoint" }
    },
    dynamodb = {
      service         = "dynamodb"
      service_type    = "Gateway"
      route_table_ids = flatten([module.vpc.intra_route_table_ids, module.vpc.private_route_table_ids, module.vpc.public_route_table_ids])
      policy          = data.aws_iam_policy_document.dynamodb_endpoint_policy.json
      tags            = { Name = "${lookup(var.tags, "ApplicationName")}-dynamodb-vpc-endpoint" }
    },
    ssm = {
      service             = "ssm"
      private_dns_enabled = true
      subnet_ids          = module.vpc.public_subnets
      security_group_ids  = [aws_security_group.vpc_tls.id]
      tags                = { Name = "${lookup(var.tags, "ApplicationName")}-ssm-vpc-endpoint" }
    },
    ssmmessages = {
      service             = "ssmmessages"
      private_dns_enabled = true
      subnet_ids          = module.vpc.public_subnets
      security_group_ids  = [aws_security_group.vpc_tls.id]
      tags                = { Name = "${lookup(var.tags, "ApplicationName")}-ssmmessages-vpc-endpoint" }
    },
    ec2 = {
      service             = "ec2"
      private_dns_enabled = true
      subnet_ids          = module.vpc.public_subnets
      security_group_ids  = [aws_security_group.vpc_tls.id]
      tags                = { Name = "${lookup(var.tags, "ApplicationName")}-ec2-vpc-endpoint" }
    },
    ec2messages = {
      service             = "ec2messages"
      private_dns_enabled = true
      subnet_ids          = module.vpc.public_subnets
      security_group_ids  = [aws_security_group.vpc_tls.id]
      tags                = { Name = "${lookup(var.tags, "ApplicationName")}-ec2messages-vpc-endpoint" }
    },
    kms = {
      service             = "kms"
      private_dns_enabled = true
      subnet_ids          = module.vpc.public_subnets
      security_group_ids  = [aws_security_group.vpc_tls.id]
      tags                = { Name = "${lookup(var.tags, "ApplicationName")}-kms-vpc-endpoint" }
    }
    secret_manager = {
      service             = "secretsmanager"
      private_dns_enabled = true
      subnet_ids          = module.vpc.public_subnets
      security_group_ids  = [aws_security_group.vpc_tls.id]
      tags                = { Name = "${lookup(var.tags, "ApplicationName")}-secretsmanager-vpc-endpoint" }
    }
  }

  tags = merge(var.tags, {
    Endpoint = "true"
  })
}

module "vpc_endpoints_nocreate" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

  create = false
}

################################################################################
# Supporting Resources
################################################################################

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = module.vpc.vpc_id
}

data "aws_iam_policy_document" "dynamodb_endpoint_policy" {
  statement {
    effect    = "Deny"
    actions   = ["dynamodb:*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:sourceVpce"

      values = [module.vpc.vpc_id]
    }
  }
}

data "aws_iam_policy_document" "generic_endpoint_policy" {
  statement {
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceVpc"

      values = [module.vpc.vpc_id]
    }
  }
}

resource "aws_security_group" "vpc_tls" {
  name_prefix = "${lookup(var.tags, "ApplicationName")}-vpc_tls_"
  description = "Allow TLS inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  tags = var.tags
}
