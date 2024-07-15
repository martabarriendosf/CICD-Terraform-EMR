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

  ec2_attributes {
    instance_profile = aws_iam_instance_profile.emr_instance_profile.arn
  }

  #To manage and coordinate the cluster, it doesn't process any data
  master_instance_group {
    instance_type = "m5.xlarge"
  }

  #These are the instances to process all the data
  core_instance_group {
    instance_type  = "m5.xlarge"
    instance_count = 2
  }
}