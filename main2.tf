provider "aws" {
  region = "us-east-1" # Remplacez par votre région AWS
}

# Création du bucket S3 pour les logs SSM
resource "aws_s3_bucket" "ssm_logs" {
  bucket = "my-unique-ssm-logs"

  tags = {
    Name        = "my-ssm-logs"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "ssm_logs" {
  bucket = aws_s3_bucket.ssm_logs.id

  rule {
    id     = "log"
    status = "Enabled"

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Groupe de sécurité pour le front-end
resource "aws_security_group" "frontend_sg" {
  name        = "frontend-sg"
  description = "Allow HTTP and SSH traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
}

# Groupe de sécurité pour le back-end
resource "aws_security_group" "backend_sg" {
  name        = "backend-sg"
  description = "Allow HTTP and SSH traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
}

# Groupe de sécurité pour l'instance RDS
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow MySQL traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Paire de clés SSH
resource "aws_key_pair" "deployer_key" {
  key_name   = var.key_name
  public_key = file("~/.ssh/${var.key_name}.pub")
}

# Instances EC2 pour le front-end
resource "aws_instance" "frontend_instance" {
  count         = 2
  ami           = var.ami_id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer_key.key_name
  security_groups = [aws_security_group.frontend_sg.name]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install nginx -y
              sudo systemctl enable nginx
              sudo systemctl start nginx

              # Configure Nginx to serve the React application
              sudo cat > /etc/nginx/conf.d/default.conf <<EOL
              server {
                  listen 80;
                  server_name _;

                  root /usr/share/nginx/html;
                  index index.html;

                  location / {
                      try_files \$uri \$uri/ /index.html;
                  }
              }
              EOL

              sudo systemctl restart nginx
              EOF

  tags = {
    Name = "frontend-instance-${count.index}"
  }
}

# Instances EC2 pour le back-end
resource "aws_instance" "backend_instance" {
  count         = 2
  ami           = var.ami_id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer_key.key_name
  security_groups = [aws_security_group.backend_sg.name]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install java-11-amazon-corretto -y
              sudo yum install maven -y
              sudo yum install nginx -y
              sudo systemctl enable nginx
              sudo systemctl start nginx

              # Create a simple Spring Boot application
              mkdir -p /home/ec2-user/springboot-app
              cd /home/ec2-user/springboot-app

              # Create Spring Boot application files
              sudo tee /home/ec2-user/springboot-app/pom.xml > /dev/null <<EOL
              <project xmlns="http://maven.apache.org/POM/4.0.0"
                       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                       xsi:schemaLocation="http://maven.apache.org/xsd/maven-4.0.0.xsd">
                  <modelVersion>4.0.0</modelVersion>
                  <groupId>com.example</groupId>
                  <artifactId>demo</artifactId>
                  <version>0.0.1-SNAPSHOT</version>
                  <packaging>jar</packaging>
                  <name>demo</name>
                  <description>Demo project for Spring Boot</description>
                  <parent>
                      <groupId>org.springframework.boot</groupId>
                      <artifactId>spring-boot-starter-parent</artifactId>
                      <version>2.5.4</version>
                      <relativePath/> <!-- lookup parent from repository -->
                  </parent>
                  <properties>
                      <java.version>11</java.version>
                  </properties>
                  <dependencies>
                      <dependency>
                          <groupId>org.springframework.boot</groupId>
                          <artifactId>spring-boot-starter-web</artifactId>
                      </dependency>
                      <dependency>
                          <groupId>org.springframework.boot</groupId>
                          <artifactId>spring-boot-starter-test</artifactId>
                          <scope>test</scope>
                      </dependency>
                  </dependencies>
                  <build>
                      <plugins>
                          <plugin>
                              <groupId>org.springframework.boot</groupId>
                              <artifactId>spring-boot-maven-plugin</artifactId>
                          </plugin>
                      </plugins>
                  </build>
              </project>
              EOL

              mkdir -p /home/ec2-user/springboot-app/src/main/java/com/example/demo
              sudo tee /home/ec2-user/springboot-app/src/main/java/com/example/demo/DemoApplication.java > /dev/null <<EOL
              package com.example.demo;

              import org.springframework.boot.SpringApplication;
              import org.springframework.boot.autoconfigure.SpringBootApplication;
              import org.springframework.web.bind.annotation.GetMapping;
              import org.springframework.web.bind.annotation.RestController;

              @SpringBootApplication
              public class DemoApplication {

                  public static void main(String[] args) {
                      SpringApplication.run(DemoApplication.class, args);
                  }

                  @RestController
                  class HelloController {
                      @GetMapping("/")
                      public String hello() {
                          return "Hello World!";
                      }
                  }
              }
              EOL

              # Build and run the Spring Boot application
              sudo mvn package
              sudo nohup java -jar target/demo-0.0.1-SNAPSHOT.jar &

              # Configure Nginx to proxy requests to the Spring Boot application
              sudo tee /etc/nginx/conf.d/default.conf > /dev/null <<EOL
              server {
                  listen 80;
                  server_name _;

                  location / {
                      proxy_pass http://localhost:8080;
                      proxy_set_header Host \$host;
                      proxy_set_header X-Real-IP \$remote_addr;
                      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto \$scheme;
                  }
              }
              EOL

              sudo systemctl restart nginx
              EOF

  tags = {
    Name = "backend-instance-${count.index}"
  }
}

# Load Balancer pour le front-end
resource "aws_elb" "frontend_elb" {
  name               = "frontend-elb"
  availability_zones = ["us-east-1d"]
  security_groups    = [aws_security_group.frontend_sg.id]

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  health_check {
    target              = "HTTP:80/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  instances = aws_instance.frontend_instance[*].id
}

# Load Balancer pour le back-end
resource "aws_elb" "backend_elb" {
  name               = "backend-elb"
  availability_zones = ["us-east-1d"]
  security_groups    = [aws_security_group.backend_sg.id]

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  health_check {
    target              = "HTTP:80/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  instances = aws_instance.backend_instance[*].id
}

# Instance RDS
resource "aws_db_instance" "default" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  identifier           = "mydb-instance"
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
  publicly_accessible  = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  tags = {
    Name = "mydb"
  }
}

# AWS Backup Vault
resource "aws_backup_vault" "rds_backup_vault" {
  name = "rds-backup-vault"
}

# IAM Role for AWS Backup
resource "aws_iam_role" "backup_role" {
  name = "backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backup_role_policy" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# AWS Backup Plan
resource "aws_backup_plan" "rds_backup_plan" {
  name = "rds-backup-plan"

  rule {
    rule_name         = "rds-12hour-backup"
    target_vault_name = aws_backup_vault.rds_backup_vault.name
    schedule          = "cron(0 */12 * * ? *)" # Cron expression for every 12 hours

    lifecycle {
      delete_after = 30 # Number of days to retain the backup
    }
  }
}

# AWS Backup Selection
resource "aws_backup_selection" "rds_backup_selection" {
  name          = "rds-backup-selection"
  iam_role_arn  = aws_iam_role.backup_role.arn
  plan_id       = aws_backup_plan.rds_backup_plan.id

  resources = [
    aws_db_instance.default.arn
  ]
}

# Alarme CloudWatch pour vérifier la disponibilité des instances et les redémarrer en cas de panne
resource "aws_cloudwatch_metric_alarm" "frontend_instance_alarm" {
  count = 2

  alarm_name                = "frontend-instance-${count.index}-status-check-failed"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "1"
  metric_name               = "StatusCheckFailed"
  namespace                 = "AWS/EC2"
  period                    = "3600"
  statistic                 = "Average"
  threshold                 = "1"
  alarm_actions             = [aws_ssm_association.frontend_restart[count.index].arn]

  dimensions = {
    InstanceId = aws_instance.frontend_instance[count.index].id
  }
}

resource "aws_cloudwatch_metric_alarm" "backend_instance_alarm" {
  count = 2

  alarm_name                = "backend-instance-${count.index}-status-check-failed"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "1"
  metric_name               = "StatusCheckFailed"
  namespace                 = "AWS/EC2"
  period                    = "3600"
  statistic                 = "Average"
  threshold                 = "1"
  alarm_actions             = [aws_ssm_association.backend_restart[count.index].arn]

  dimensions = {
    InstanceId = aws_instance.backend_instance[count.index].id
  }
}

# IAM Role for SSM
resource "aws_iam_role" "ssm_assume_role" {
  name = "ssm-assume-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_role_policy" {
  role       = aws_iam_role.ssm_assume_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

# SSM Document to Restart Instance
resource "aws_ssm_document" "restart_instance" {
  name          = "restart-instance"
  document_type = "Automation"

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Restart an EC2 instance"
    parameters = {
      InstanceIds = {
        type = "StringList"
        description = "Instance IDs to restart"
      }
    }
    mainSteps = [
      {
        action = "aws:changeInstanceState"
        name   = "restartInstance"
        inputs = {
          InstanceIds   = "{{ InstanceIds }}"
          DesiredState = "running"
        }
      }
    ]
  })
}

# SSM Association to Restart Frontend Instances
resource "aws_ssm_association" "frontend_restart" {
  count           = 2
  name            = aws_ssm_document.restart_instance.name
  association_name = "frontend-restart-${count.index}"
  document_version = "$LATEST"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.frontend_instance[count.index].id]
  }

  output_location {
    s3_bucket_name = aws_s3_bucket.ssm_logs.bucket
  }

  parameters = {
    InstanceIds = [aws_instance.frontend_instance[count.index].id]
  }
  schedule_expression = "rate(1 hour)"
  automation_target_parameter_name = "InstanceIds"
  iam_role = aws_iam_role.ssm_assume_role.arn
}

# SSM Association to Restart Backend Instances
resource "aws_ssm_association" "backend_restart" {
  count           = 2
  name            = aws_ssm_document.restart_instance.name
  association_name = "backend-restart-${count.index}"
  document_version = "$LATEST"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.backend_instance[count.index].id]
  }

  output_location {
    s3_bucket_name = aws_s3_bucket.ssm_logs.bucket
  }

  parameters = {
    InstanceIds = [aws_instance.backend_instance[count.index].id]
  }
  schedule_expression = "rate(1 hour)"
  automation_target_parameter_name = "InstanceIds"
  iam_role = aws_iam_role.ssm_assume_role.arn
}
