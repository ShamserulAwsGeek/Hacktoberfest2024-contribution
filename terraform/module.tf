# ECR LOGIN CREATION:
#!/bin/bash
REGION="eu-west-1"
`aws ecr get-login --no-include-email --region ${REGION}`

# CONTAINER RESOURCE CREATION:
data "aws_caller_identity" "current" {
}

module "my-ecs" {
  source         = "github.com/in4it/terraform-modules//modules/ecs-cluster"
  vpc_id         = module.vpc.vpc_id
  cluster_name   = "my-ecs"
  instance_type  = "t2.small"
  ssh_key_name   = aws_key_pair.mykeypair.key_name
  vpc_subnets    = join(",", module.vpc.public_subnets)
  enable_ssh     = true
  ssh_sg         = aws_security_group.allow-ssh.id
  log_group      = "my-log-group"
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = var.AWS_REGION
}

module "my-service" {
  source              = "github.com/in4it/terraform-modules//modules/ecs-service"
  vpc_id              = module.vpc.vpc_id
  application_name    = "my-service"
  application_port    = "80"
  application_version = "latest"
  cluster_arn         = module.my-ecs.cluster_arn
  service_role_arn    = module.my-ecs.service_role_arn
  aws_region          = var.AWS_REGION
  healthcheck_matcher = "200"
  cpu_reservation     = "256"
  memory_reservation  = "128"
  log_group           = "my-log-group"
  desired_count       = 2
  alb_arn             = module.my-alb.lb_arn
}

module "my-alb" {
  source             = "github.com/in4it/terraform-modules//modules/alb"
  vpc_id             = module.vpc.vpc_id
  lb_name            = "my-alb"
  vpc_subnets        = module.vpc.public_subnets
  default_target_arn = module.my-service.target_group_arn
  domain             = "*.ecs.newtech.academy"
  internal           = false
  ecs_sg             = [module.my-ecs.cluster_sg]
}

module "my-alb-rule" {
  source           = "github.com/in4it/terraform-modules//modules/alb-rule"
  listener_arn     = module.my-alb.http_listener_arn
  priority         = 100
  target_group_arn = module.my-service.target_group_arn
  condition_field  = "host-header"
  condition_values = ["subdomain.ecs.newtech.academy"]
}


# KEY-PAIR RESOURCE:
resource "aws_key_pair" "mykeypair" {
  key_name   = "mykeypair"
  public_key = file(var.PATH_TO_PUBLIC_KEY)
}


# PROVIDER DETAILS:
provider "aws" {
  region = "eu-west-1"
}

# SECURITY GROUP DECLARATION:
resource "aws_security_group" "allow-ssh" {
  vpc_id      = module.vpc.vpc_id
  name        = "allow-ssh"
  description = "security group that allows ssh and all egress traffic"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-ssh"
  }
}


# VARIABLES DECLARATION:
variable "AWS_REGION" {
  default = "eu-west-1"
}

variable "PATH_TO_PRIVATE_KEY" {
  default = "mykey"
}

variable "PATH_TO_PUBLIC_KEY" {
  default = "mykey.pub"
}


# VERSIONS DECLARATION:

terraform {
  required_version = ">= 0.12"
}


# VPC DECLARATION:
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.59.0"

  name = "vpc-module-demo"
  cidr = "10.0.0.0/16"

  azs             = ["${var.AWS_REGION}a", "${var.AWS_REGION}b", "${var.AWS_REGION}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Environment = "prod"
  }
}





