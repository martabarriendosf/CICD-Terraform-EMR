#!/bin/bash

# Install the CloudWatch Agent
sudo yum install -y amazon-cloudwatch-agent

# Download the CloudWatch Agent configuration file from S3
aws s3 cp s3://emr-cloudwatchagent-mbf/config/config.json /opt/aws/amazon-cloudwatch-agent/bin/config.json

# Start the CloudWatch Agent with the downloaded configuration file
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -s -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json

# Check the status of the CloudWatch Agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status
