# configured aws provider with proper credentials
provider "aws" {
  region  = "us-east-1"
}

# store the terraform state file in s3
terraform {
  backend "s3" {
    bucket  = "my-bucket-created-with-terraform-mbf-2"
    key     = "terraform.tfstate" #Name we want to give to the state file in the bucket
    region  = "us-east-1"

  }
}

#Defining the role that EMR can assume, with 2 policies, emr_service_rol for letting EMR assume the rol, and AmazonElasticMapReduceRole to give
# EMR the permissions to run properly the cluster
resource "aws_iam_role" "emr_service_role" {
  name = "emr_service_role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "elasticmapreduce.amazonaws.com" 
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"]
}

# Policy to allow EMR to write logs to the specified S3 bucket
resource "aws_iam_policy" "emr_log_policy" {
  name        = "EMRLogPolicy"
  description = "Policy to allow EMR to write logs to S3"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::mbf-emr-systemfile",
        "arn:aws:s3:::mbf-emr-systemfile/*"
      ]
    }
  ]
}
EOF
}

# Attach the policy to the EMR service role
resource "aws_iam_role_policy_attachment" "emr_service_role_policy_attachment" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = aws_iam_policy.emr_log_policy.arn
}




# Define the EC2 instance profile
resource "aws_iam_role" "emr_ec2_instance_role" {
  name = "emr_ec2_instance_role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
#Giving to the EC2 instances of the cluster, full access to EMR, including the management of the EC2 instances to let the EMR cluster work properly
resource "aws_iam_role_policy_attachment" "emr_ec2_instance_role_policy_attachment" {
  role       = aws_iam_role.emr_ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticMapReduceFullAccess"
}

#We create an IAM instance profile to associate the IAM role to all the EC2 instances from the EMR cluster
resource "aws_iam_instance_profile" "emr_instance_profile" {
  name = "emr_instance_profile"
  role = aws_iam_role.emr_ec2_instance_role.name
}

resource "aws_emr_cluster" "example_cluster" {
  name           = "Example Cluster"
  release_label  = "emr-5.32.0"
  applications   = ["Spark", "Hadoop"]
  service_role   = aws_iam_role.emr_service_role.arn
  log_uri        = "s3://mbf-emr-systemfile/monthly_build/2024/logs/"

  ec2_attributes {
    instance_profile = aws_iam_instance_profile.emr_instance_profile.arn
    key_name         = "emr-key-pair" 
  }
  # Especificación de lanzamiento para la flota de instancias maestras (opcional)
  master_instance_fleet {
    target_on_demand_capacity = 1
    instance_type_configs {
      instance_type   = "m5.xlarge"
      
    }
  }

  #These are the instances to process all the data
  # Grupo de instancias principales (core) con instancias de Spot
  core_instance_fleet {
    name = "Core Instance Fleet"
    target_spot_capacity    = 2 # Número de instancias de Spot para el grupo principal (core)
    instance_type_configs{
      bid_price_as_percentage_of_on_demand_price = 80
      instance_type = "m5.xlarge"
      }

      launch_specifications {
        spot_specification {
          allocation_strategy      = "capacity-optimized"
          block_duration_minutes   = 0
          timeout_action           = "SWITCH_TO_ON_DEMAND"
          timeout_duration_minutes = 10
        }
      }
    
  }

   # Define a bootstrap action to install CloudWatch Agent
  bootstrap_action {
    name = "Install CloudWatch Agent"
    path = "s3://emr-cloudwatchagent-mbf/cloudwatch_agent/cloudwatch-agent-install.sh"

  }

}
