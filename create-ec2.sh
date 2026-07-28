#!/bin/bash
set -e

REGION="ap-south-1"
KEY_NAME="websocket-key"
INSTANCE_TYPE="t3.micro"
INSTANCE_NAME="devops-websocket-server"

echo "Getting latest Ubuntu 24.04 AMI..."

AMI_ID=$(aws ssm get-parameters \
  --region $REGION \
  --names /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
  --query "Parameters[0].Value" \
  --output text)

echo "AMI: $AMI_ID"

echo "Creating VPC..."

VPC_ID=$(aws ec2 create-vpc \
  --region $REGION \
  --cidr-block 10.0.0.0/16 \
  --query "Vpc.VpcId" \
  --output text)

echo "VPC: $VPC_ID"

aws ec2 modify-vpc-attribute \
  --region $REGION \
  --vpc-id $VPC_ID \
  --enable-dns-support "{\"Value\":true}"

aws ec2 modify-vpc-attribute \
  --region $REGION \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames "{\"Value\":true}"

echo "Creating Internet Gateway..."

IGW_ID=$(aws ec2 create-internet-gateway \
  --region $REGION \
  --query "InternetGateway.InternetGatewayId" \
  --output text)

aws ec2 attach-internet-gateway \
  --region $REGION \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VPC_ID

echo "Creating Public Subnet..."

SUBNET_ID=$(aws ec2 create-subnet \
  --region $REGION \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone ap-south-1a \
  --query "Subnet.SubnetId" \
  --output text)

aws ec2 modify-subnet-attribute \
  --region $REGION \
  --subnet-id $SUBNET_ID \
  --map-public-ip-on-launch

echo "Creating Route Table..."

RT_ID=$(aws ec2 create-route-table \
  --region $REGION \
  --vpc-id $VPC_ID \
  --query "RouteTable.RouteTableId" \
  --output text)

aws ec2 create-route \
  --region $REGION \
  --route-table-id $RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

aws ec2 associate-route-table \
  --region $REGION \
  --route-table-id $RT_ID \
  --subnet-id $SUBNET_ID

echo "Creating Security Group..."

SG_ID=$(aws ec2 create-security-group \
  --region $REGION \
  --group-name websocket-sg \
  --description "WebSocket Security Group" \
  --vpc-id $VPC_ID \
  --query "GroupId" \
  --output text)

aws ec2 authorize-security-group-ingress \
  --region $REGION \
  --group-id $SG_ID \
  --ip-permissions '[
    {
      "IpProtocol":"tcp",
      "FromPort":22,
      "ToPort":22,
      "IpRanges":[{"CidrIp":"0.0.0.0/0"}]
    },
    {
      "IpProtocol":"tcp",
      "FromPort":80,
      "ToPort":80,
      "IpRanges":[{"CidrIp":"0.0.0.0/0"}]
    },
    {
      "IpProtocol":"tcp",
      "FromPort":443,
      "ToPort":443,
      "IpRanges":[{"CidrIp":"0.0.0.0/0"}]
    }
  ]'

echo "Launching EC2..."

INSTANCE_ID=$(aws ec2 run-instances \
  --region $REGION \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET_ID \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":15,"VolumeType":"gp3"}}]' \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
  --query "Instances[0].InstanceId" \
  --output text)

echo "Waiting for instance..."

aws ec2 wait instance-running \
  --region $REGION \
  --instance-ids $INSTANCE_ID

PUBLIC_IP=$(aws ec2 describe-instances \
  --region $REGION \
  --instance-ids $INSTANCE_ID \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo
echo "=========================================="
echo "Infrastructure Created Successfully"
echo "=========================================="
echo "VPC          : $VPC_ID"
echo "Subnet       : $SUBNET_ID"
echo "SecurityGroup: $SG_ID"
echo "Instance     : $INSTANCE_ID"
echo "Public IP    : $PUBLIC_IP"
echo
echo "Connect using:"
echo "ssh -i ~/Downloads/devops100.pem ubuntu@$PUBLIC_IP"
