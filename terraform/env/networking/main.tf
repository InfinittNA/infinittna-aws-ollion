module "networking" {
  source                       = "../../modules/network"
  environment                  = var.environment
  region                       = var.region
  vpc_cidr_block               = var.vpc_cidr_block
  vpc_public_subnets           = var.vpc_public_subnets
  vpc_public_subnet_names      = var.vpc_public_subnet_names
  vpc_private_subnets          = var.vpc_private_subnets
  vpc_private_subnet_names     = var.vpc_private_subnet_names
  vpc_database_subnets         = var.vpc_database_subnets
  vpc_database_subnet_names    = var.vpc_database_subnet_names
  create_database_subnet_group = var.create_database_subnet_group

  tags = var.tags
}


module "fsx" {
  source                           = "../../modules/fsx"
  environment                      = var.environment
  region                           = var.region
  vpc_id                           = module.networking.vpc_id
  subnet_ids                       = module.networking.private_subnets
  ad_name                          = var.ad_name
  ad_log_retention_in_days         = var.ad_log_retention_in_days
  kms_key_deletion_window_in_days  = var.kms_key_deletion_window_in_days
  kms_key_enable_rotation          = var.kms_key_enable_rotation
  kms_key_name                     = var.kms_key_name
  fsx_file_system_name             = var.fsx_file_system_name
  fsx_deployment_type              = var.fsx_deployment_type
  fsx_storage_type                 = var.fsx_storage_type
  ad_manager_instance_type         = var.ad_manager_instance_type
  ad_manager_instance_ec2_key_name = var.ad_manager_instance_ec2_key_name
  ad_manager_subnet_id             = module.networking.private_subnets[3]

  tags = var.tags
}


