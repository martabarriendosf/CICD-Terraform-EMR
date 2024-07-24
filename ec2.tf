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
  autoscaling_role  = aws_iam_role.emr_autoscaling_role.arn

  ec2_attributes {
    instance_profile = aws_iam_instance_profile.emr_instance_profile.arn
    key_name         = "emr-key-pair" 
    subnet_id    = "subnet-015014d9e9bfd7242"
  }
  # Especificación de lanzamiento para la flota de instancias maestras (opcional)
    master_instance_group {
    instance_type = "m4.large"
  }

  core_instance_group {
    instance_type  = "c4.large"
    instance_count = 1

    ebs_config {
      size                 = "40"
      type                 = "gp2"
      volumes_per_instance = 1
    }


    autoscaling_policy = <<EOF
{
"Constraints": {
  "MinCapacity": 1,
  "MaxCapacity": 5
},
"Rules": [
  {
    "Name": "ScaleOutMemoryPercentage",
    "Description": "Scale out if YARNMemoryAvailablePercentage is less than 15",
    "Action": {
      "SimpleScalingPolicyConfiguration": {
        "AdjustmentType": "CHANGE_IN_CAPACITY",
        "ScalingAdjustment": 1,
        "CoolDown": 300
      }
    },
    "Trigger": {
      "CloudWatchAlarmDefinition": {
        "ComparisonOperator": "LESS_THAN",
        "EvaluationPeriods": 1,
        "MetricName": "YARNMemoryAvailablePercentage",
        "Namespace": "AWS/ElasticMapReduce",
        "Period": 300,
        "Statistic": "AVERAGE",
        "Threshold": 15.0,
        "Unit": "PERCENT"
      }
    }
  }
]
}
EOF
  }

  ebs_root_volume_size = 100

  tags = {
    role = "rolename"
    env  = "env"
  }


   # Define a bootstrap action to install CloudWatch Agent
  bootstrap_action {
    name = "Install CloudWatch Agent"
    path = "s3://emr-cloudwatchagent-mbf/cloudwatch_agent/cloudwatch-agent-install.sh"

  }

  

}

# Task instance group with Spot instances
resource "aws_emr_instance_group" "task" {
  cluster_id     = aws_emr_cluster.example_cluster.id
  instance_count = 2
  instance_type  = "m4.large"
  name           = "my little instance group"
  bid_price      = "0.3" # Bid price in USD for Spot instances
}