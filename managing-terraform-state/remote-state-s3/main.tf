locals {
  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
  common_tags = {
    environment      = "dev"
    application_name = "managing-terraform-state"
    type             = "remote-state-s3"
  }
}

data "aws_availability_zones" "available" {}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  name    = format("VPC-%s-%s", local.common_tags.application_name, local.common_tags.type)
  version = "~> 5.1"

  cidr = local.vpc_cidr

  azs              = local.azs
  public_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 3)]
  database_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 6)]

  create_database_subnet_group = true

  tags = local.common_tags
}

resource "aws_key_pair" "dumb_key" {
  key_name   = "dumb_key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDKJRBq6VOaE1GNJtf3kvqz5/YfaPHr4PG6DfdzI8SxjdDzqgZ+DBXDcrnGhJ3eAZOWEueFmuOnzZ+BuvHnXJCMJH73arvoZjxVCNceSVhPQU1p9VTUevsMXeotwGEDB7rmAgB7Mvn6y52nsFqRoHHIYFTEvIPveJao+IfV1kyYmBMTZgJTaVxMXURXq1EBB1f/NiHzN9gnQdQjWPH/6e6BR29Zd5fgHBc9SEuA44v86el/yoh0fkKkvrOKE5NbNM7CPmcK6DYPSLnUYV/OKjPcOVC69Q4EMJBAyPP6ZamEMIaNSJCMG91sUCa1QY1c85WCNrsly9Ebm70LKaeIjCOVgHH+FMZWg4EylqOBp89gvRXnrb2ChdtLuU4+H+dJTuhVgQeMfCFnguFfoWX6WOvQqHaxoFheenS2RDRigbZmQwB3sh0crD6XSTbNGWJsmQygWU57h1rlM7OGIIjzZJW+86ztprWrH53AB0Fp/CZlUFet5saZ34IDIkM/6RjgFJHdNJ5M9bjyqqiDxy195k3bxBPyagD8IzQ7cw57vx+eQh9zNF8Yj2BoOv+KoNyQ0QoDgAk5aTeJ5ETLNf6Kjxj3+JboBMedNoM3ITTK0OveLTgtVvV2kpFNdoAfUMB+kJ1JNoWMaplH1e5TxImDPehx9FaLeirl8Umdz6mWL3eweQ== This is a dumb key"
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.3.1"
  name    = format("single-instance-%s", local.common_tags.type)

  instance_type          = "t2.micro"
  key_name               = aws_key_pair.dumb_key.key_name
  monitoring             = false
  vpc_security_group_ids = [module.vpc.default_security_group_id]
  subnet_id              = module.vpc.private_subnets[0]

  tags = local.common_tags
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.1.1"

  identifier = format("db-%s", local.common_tags.type)

  # All available versions: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html#PostgreSQL.Concepts
  engine               = "postgres"
  engine_version       = "14"
  family               = "postgres14" # DB parameter group
  major_engine_version = "14"         # DB option group
  instance_class       = "db.t4g.micro"

  allocated_storage     = 10
  max_allocated_storage = 20

  # NOTE: Do NOT use 'user' as the value for 'username' as it throws:
  # "Error creating DB Instance: InvalidParameterValue: MasterUsername
  # user cannot be used as it is a reserved word used by the engine"
  db_name  = "dumb_db"
  username = "dump_user"
  password = "dumb_password"
  port     = 5432

  multi_az               = false
  db_subnet_group_name   = module.vpc.database_subnet_group
  vpc_security_group_ids = [module.security_group_db.security_group_id]

  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  create_cloudwatch_log_group     = false

  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  create_monitoring_role                = true
  monitoring_interval                   = 60
  monitoring_role_name                  = "example-monitoring-role-name"
  monitoring_role_use_name_prefix       = true
  monitoring_role_description           = "Description for monitoring role"

  parameters = [
    {
      name  = "autovacuum"
      value = 1
    },
    {
      name  = "client_encoding"
      value = "utf8"
    }
  ]

  tags = local.common_tags
  db_option_group_tags = {
    "Sensitive" = "low"
  }
  db_parameter_group_tags = {
    "Sensitive" = "low"
  }
}

module "security_group_db" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = format("security-group-db-%s", local.common_tags.type)
  description = "Complete PostgreSQL example security group"
  vpc_id      = module.vpc.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access from within VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]

  tags = local.common_tags
}