terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

# VPC Configuration
resource "aws_vpc" "bank_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "bank-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "bank_igw" {
  vpc_id = aws_vpc.bank_vpc.id
  tags = {
    Name = "bank-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.bank_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.bank_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-2b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-2"
  }
}

# Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.bank_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bank_igw.id
  }
  tags = {
    Name = "public-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_1_rt_a" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2_rt_a" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.bank_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# Security Group for EC2 Instances
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.bank_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg"
  }
}

# IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "ec2-code-deploy-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# ENHANCED IAM Role Policy Attachments for EC2
resource "aws_iam_role_policy_attachment" "ec2_s3" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "ec2_ecr" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# FIXED: Use correct policy for EC2 instances, not CodeDeploy role
resource "aws_iam_role_policy" "ec2_codedeploy_policy" {
  name = "ec2-codedeploy-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-code-deploy-profile"
  role = aws_iam_role.ec2_role.name
}

# Get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# FIXED Launch Template for Blue Environment
resource "aws_launch_template" "blue_lt" {
  name          = "blue-launch-template"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  key_name      = "mynewkey"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -x
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    
    # Update system
    yum update -y
    
    # Install Docker
    amazon-linux-extras install docker -y
    systemctl enable docker
    systemctl start docker
    usermod -a -G docker ec2-user
    
    # Install AWS CLI and CodeDeploy agent
    yum install -y aws-cli ruby wget
    cd /home/ec2-user
    wget https://aws-codedeploy-eu-west-2.s3.eu-west-2.amazonaws.com/latest/install
    chmod +x ./install
    ./install auto
    
    # Start CodeDeploy agent and enable it
    service codedeploy-agent start
    chkconfig codedeploy-agent on
    
    # Verify agent is running
    service codedeploy-agent status
    
    # Create deployment directory with proper permissions
    mkdir -p /tmp/codedeploy
    chown ec2-user:ec2-user /tmp/codedeploy
    
    # Tag instance for CodeDeploy targeting
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    
    aws ec2 create-tags --region $REGION --resources $INSTANCE_ID --tags Key=Name,Value=blue-instance
    aws ec2 create-tags --region $REGION --resources $INSTANCE_ID --tags Key=Environment,Value=blue
    aws ec2 create-tags --region $REGION --resources $INSTANCE_ID --tags Key=CodeDeployEnvironment,Value=blue
    
    echo "Blue instance setup completed at $(date)" > /tmp/base-install.log
    echo "CodeDeploy agent status:" >> /tmp/base-install.log
    service codedeploy-agent status >> /tmp/base-install.log
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                   = "blue-instance"
      Environment           = "blue"
      CodeDeployEnvironment = "blue"
    }
  }
}

# FIXED Launch Template for Green Environment  
resource "aws_launch_template" "green_lt" {
  name          = "green-launch-template"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  key_name      = "mynewkey"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -x
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    
    # Update system
    yum update -y
    
    # Install Docker
    amazon-linux-extras install docker -y
    systemctl enable docker
    systemctl start docker
    usermod -a -G docker ec2-user
    
    # Install AWS CLI and CodeDeploy agent
    yum install -y aws-cli ruby wget
    cd /home/ec2-user
    wget https://aws-codedeploy-eu-west-2.s3.eu-west-2.amazonaws.com/latest/install
    chmod +x ./install
    ./install auto
    
    # Start CodeDeploy agent and enable it
    service codedeploy-agent start
    chkconfig codedeploy-agent on
    
    # Verify agent is running
    service codedeploy-agent status
    
    # Create deployment directory with proper permissions
    mkdir -p /tmp/codedeploy
    chown ec2-user:ec2-user /tmp/codedeploy
    
    # Tag instance for CodeDeploy targeting
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    
    aws ec2 create-tags --region $REGION --resources $INSTANCE_ID --tags Key=Name,Value=green-instance
    aws ec2 create-tags --region $REGION --resources $INSTANCE_ID --tags Key=Environment,Value=green
    aws ec2 create-tags --region $REGION --resources $INSTANCE_ID --tags Key=CodeDeployEnvironment,Value=green
    
    echo "Green instance setup completed at $(date)" > /tmp/base-install.log
    echo "CodeDeploy agent status:" >> /tmp/base-install.log
    service codedeploy-agent status >> /tmp/base-install.log
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                   = "green-instance"
      Environment           = "green"
      CodeDeployEnvironment = "green"
    }
  }
}

# Auto Scaling Group for Blue - Updated with proper tags
resource "aws_autoscaling_group" "blue_asg" {
  name                = "blue-asg"
  desired_capacity    = 1  # Blue starts with instances
  max_size            = 2
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.blue_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "blue-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "blue"
    propagate_at_launch = true
  }

  tag {
    key                 = "CodeDeployEnvironment"
    value               = "blue"
    propagate_at_launch = true
  }
}

# Auto Scaling Group for Green - Updated with proper tags
resource "aws_autoscaling_group" "green_asg" {
  name                = "green-asg"
  desired_capacity    = 0  # Start with 0 instances for blue-green
  max_size            = 2
  min_size            = 0
  vpc_zone_identifier = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.green_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "green-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "green"
    propagate_at_launch = true
  }

  tag {
    key                 = "CodeDeployEnvironment"
    value               = "green"
    propagate_at_launch = true
  }

  # Initial lifecycle hook to keep instances available for CodeDeploy
  initial_lifecycle_hook {
    name                 = "CodeDeploy-green"
    default_result       = "CONTINUE"
    heartbeat_timeout    = 60
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
  }
}

# Application Load Balancer
resource "aws_lb" "bank_alb" {
  name               = "bank-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets           = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  tags = {
    Name = "bank-alb"
  }
}

# FIXED Target Group for Blue
resource "aws_lb_target_group" "blue_tg" {
  name     = "blue-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.bank_vpc.id
  target_type = "instance"

  health_check {
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
}

# FIXED Target Group for Green
resource "aws_lb_target_group" "green_tg" {
  name     = "green-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.bank_vpc.id
  target_type = "instance"

  health_check {
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
}

# # ALB Listener - FIXED to use correct reference
# resource "aws_lb_listener" "bank_listener" {
#   load_balancer_arn = aws_lb.bank_alb.arn
#   port              = "80"
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.blue_tg.arn
#   }
# }
# ALB Listener with forward action for blue-green switching
resource "aws_lb_listener" "bank_listener" {
  load_balancer_arn = aws_lb.bank_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue_tg.arn
  }

  tags = {
    Name = "bank-alb-listener"
  }
}

# Additional listener rule for manual testing/rollback
resource "aws_lb_listener_rule" "green_traffic" {
  listener_arn = aws_lb_listener.bank_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green_tg.arn
  }

  condition {
    host_header {
      values = ["green.bencenet.com"]
    }
  }

  tags = {
    Name = "green-traffic-rule"
  }
}

# Attach Blue ASG to Blue Target Group
resource "aws_autoscaling_attachment" "blue_asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.blue_asg.id
  lb_target_group_arn    = aws_lb_target_group.blue_tg.arn
}

# Attach Green ASG to Green Target Group
resource "aws_autoscaling_attachment" "green_asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.green_asg.id
  lb_target_group_arn    = aws_lb_target_group.green_tg.arn
}

# Output ALB DNS Name
output "alb_dns_name" {
  value = aws_lb.bank_alb.dns_name
}