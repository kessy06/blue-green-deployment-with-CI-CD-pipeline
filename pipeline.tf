# ECR Repository
resource "aws_ecr_repository" "bencenet_bank_app" {
  name = "bencenet-bank-app"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  force_delete = true
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "bencenet_bank_app_policy" {
  repository = aws_ecr_repository.bencenet_bank_app.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# S3 Bucket for CodePipeline Artifacts
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "bencenet-bank-codepipeline-bucket-${random_id.bucket_suffix.hex}"
}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# Block public access for S3 bucket
resource "aws_s3_bucket_public_access_block" "codepipeline_bucket" {
  bucket = aws_s3_bucket.codepipeline_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM Role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-bencenet-bank-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "codebuild-bencenet-bank-policy"
  role = aws_iam_role.codebuild_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject",
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:GetAuthorizationToken",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = "*"
      }
    ]
  })
}

# Add ECR permissions to CodeBuild role
resource "aws_iam_role_policy_attachment" "codebuild_ecr_policy" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# CodeBuild Project
resource "aws_codebuild_project" "bencenet_bank_build" {
  name          = "bencenet-bank-build"
  description   = "Build project for bencenet Bank Docker application"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 10

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.region
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.account_id
    }

    environment_variable {
      name  = "ECR_REPO_NAME"
      value = aws_ecr_repository.bencenet_bank_app.name
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.bencenet_bank_app.name
    }

    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}

# IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-bencenet-bank-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

# CodePipeline Policy
resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline-bencenet-bank-policy"
  role = aws_iam_role.codepipeline_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.codepipeline_bucket.arn,
          "${aws_s3_bucket.codepipeline_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codebuild:BatchGetProjects"
        ]
        Resource = aws_codebuild_project.bencenet_bank_build.arn
      },
      {
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:DescribeImages"
        ]
        Resource = aws_ecr_repository.bencenet_bank_app.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Separate policy for CodeStar connections
resource "aws_iam_role_policy" "codepipeline_codestar_policy" {
  name = "codepipeline-codestar-policy"
  role = aws_iam_role.codepipeline_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection",
          "codeconnections:UseConnection"
        ]
        Resource = [
          "arn:aws:codestar-connections:eu-west-2:647540925028:connection/9fcff319-5305-440e-a3c6-6dcbc703a294",
          "arn:aws:codeconnections:eu-west-2:647540925028:connection/9fcff319-5305-440e-a3c6-6dcbc703a294"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:GetConnection",
          "codestar-connections:ListConnections",
          "codestar-connections:ListInstallationTargets",
          "codeconnections:GetConnection",
          "codeconnections:ListConnections",
          "codeconnections:ListInstallationTargets"
        ]
        Resource = "*"
      }
    ]
  })
}

# CodeDeploy Application
resource "aws_codedeploy_app" "bencenet_bank_app" {
  name             = "bencenet-bank-app"
  compute_platform = "Server"
}

# IAM Role for CodeDeploy
resource "aws_iam_role" "codedeploy_role" {
  name = "codedeploy-bencenet-bank-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_policy" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# Correct policy for Auto Scaling operations in blue-green deployments
resource "aws_iam_role_policy" "codedeploy_bluegreen_policy" {
  name = "codedeploy-bluegreen-policy"
  role = aws_iam_role.codedeploy_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:CompleteLifecycleAction",
          "autoscaling:DeleteAutoScalingGroup",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeLifecycleHooks",
          "autoscaling:PutLifecycleHook",
          "autoscaling:RecordLifecycleActionHeartbeat",
          "autoscaling:CreateAutoScalingGroup",
          "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:EnableMetricsCollection",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeNotificationConfigurations",
          "autoscaling:SuspendProcesses",
          "autoscaling:ResumeProcesses",
          "autoscaling:AttachInstances",
          "autoscaling:DetachInstances",
          "autoscaling:AttachLoadBalancers",
          "autoscaling:DetachLoadBalancers",
          "autoscaling:AttachLoadBalancerTargetGroups",
          "autoscaling:DetachLoadBalancerTargetGroups",
          "autoscaling:CreateLaunchTemplate",
          "autoscaling:CreateLaunchConfiguration",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeLaunchTemplates",
          "autoscaling:GetPredictiveScalingForecast"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:DescribeSnapshots",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeTags",
          "ec2:CreateTags",
          "ec2:RunInstances",
          "ec2:TerminateInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
      }
    ]
  })
}

# SIMPLIFIED CodeDeploy Deployment Group - Back to IN_PLACE for reliability
resource "aws_codedeploy_deployment_group" "bencenet_bank_dg" {
  app_name              = aws_codedeploy_app.bencenet_bank_app.name
  deployment_group_name = "bencenet-bank-dg"
  service_role_arn      = aws_iam_role.codedeploy_role.arn

  # Use IN_PLACE deployment for reliability
  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  # Target instances by Auto Scaling Groups
  autoscaling_groups = [aws_autoscaling_group.blue_asg.name]

  deployment_config_name = "CodeDeployDefault.AllAtOnce"
}

# CodePipeline
resource "aws_codepipeline" "bencenet_bank_pipeline" {
  name     = "bencenet-bank-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  # Source Stage (GitHub)
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = "arn:aws:codeconnections:eu-west-2:647540925028:connection/9fcff319-5305-440e-a3c6-6dcbc703a294"
        FullRepositoryId = "kessy06/blue-green-deployment-with-CI-CD-pipeline"
        BranchName       = "main"
      }
    }
  }

  # Build Stage (Docker Build)
  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.bencenet_bank_build.name
      }
    }
  }

  # Deploy Stage
  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ApplicationName     = aws_codedeploy_app.bencenet_bank_app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.bencenet_bank_dg.deployment_group_name
      }
    }
  }

  depends_on = [
    aws_s3_bucket_public_access_block.codepipeline_bucket
  ]
}

# Output ECR Repository URL
output "ecr_repository_url" {
  value = aws_ecr_repository.bencenet_bank_app.repository_url
}

# Output CodePipeline URL
output "codepipeline_url" {
  value = "https://eu-west-2.console.aws.amazon.com/codesuite/codepipeline/pipelines/${aws_codepipeline.bencenet_bank_pipeline.name}/view"
}