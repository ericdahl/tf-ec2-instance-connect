provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source        = "github.com/ericdahl/tf-vpc"
  admin_ip_cidr = "${var.admin_cidr}"
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true

  owners = ["137112412989"]

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "instance-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
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

resource "aws_iam_policy" "instance_connect" {
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "ec2-instance-connect:SendSSHPublicKey",
        "Resource": "*",
        "Condition": {
          "StringEquals": {
            "ec2:osuser": "ec2-user"
          }
        }
      },
      {
        "Effect": "Allow",
        "Action": "ec2:DescribeInstances",
        "Resource": "*"
      }
    ]
  }
EOF
}

resource "aws_iam_instance_profile" "default" {
  name = "${var.name}-instance-profile"
  role = "${aws_iam_role.ec2_role.name}"
}

resource "aws_instance" "jumphost" {
  ami                    = "${data.aws_ami.amazon_linux_2.image_id}"
  instance_type          = "t2.small"
  subnet_id              = "${module.vpc.subnet_public1}"
  vpc_security_group_ids = ["${module.vpc.sg_allow_22}", "${module.vpc.sg_allow_egress}"]
  key_name               = "${var.key_name}"

  iam_instance_profile = "${aws_iam_instance_profile.default.name}"

  user_data = <<EOF
#!/usr/bin/env sh

yum install ec2-instance-connect
EOF

  tags {
    Name = "tf-ec2-instance-connect-sandbox"
  }
}
