# Administrators group
resource "aws_iam_group" "administrators" {
  name = "Administrators"
}

resource "aws_iam_group_policy_attachment" "administrators" {
  group      = aws_iam_group.administrators.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_user_group_membership" "matias_admin" {
  user   = "Matias-admin"
  groups = [aws_iam_group.administrators.name]
}

# sigilos-cicd user
resource "aws_iam_user" "sigilos_cicd" {
  name = "sigilos-cicd"
}

resource "aws_iam_policy" "sigilos_cicd" {
  name = "sigilos-cicd-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucket"
        Effect = "Allow"
        Action = "s3:ListBucket"
        Resource = "arn:aws:s3:::sigilos.st"
      },
      {
        Sid    = "UploadOnly"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::sigilos.st/*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "sigilos_cicd" {
  user       = aws_iam_user.sigilos_cicd.name
  policy_arn = aws_iam_policy.sigilos_cicd.arn
}

# homelab-backup user
resource "aws_iam_user" "homelab_backup" {
  name = "homelab-backup"
}

resource "aws_iam_policy" "homelab_backup" {
  name = "homelab-backup-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBackupBucket"
        Effect = "Allow"
        Action = "s3:ListBucket"
        Resource = "arn:aws:s3:::sigilos-homelab-backups"
      },
      {
        Sid    = "WriteBackupsOnly"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::sigilos-homelab-backups/*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "homelab_backup" {
  user       = aws_iam_user.homelab_backup.name
  policy_arn = aws_iam_policy.homelab_backup.arn
}

# EC2 instance role for Debian VPN
resource "aws_iam_role" "debian_vpn" {
  name = "debian-vpn-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "ec2_self_describe" {
  name = "ec2-self-describe-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DescribeSelf"
      Effect   = "Allow"
      Action   = ["ec2:DescribeInstances", "ec2:DescribeTags"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "debian_vpn" {
  role       = aws_iam_role.debian_vpn.name
  policy_arn = aws_iam_policy.ec2_self_describe.arn
}

resource "aws_iam_instance_profile" "debian_vpn" {
  name = "debian-vpn-role"
  role = aws_iam_role.debian_vpn.name
}
