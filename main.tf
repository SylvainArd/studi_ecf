provider "aws" {
  region = "us-east-1" # Remplacez par votre région AWS
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

# Instances EC2 pour le front-end
resource "aws_instance" "frontend_instance" {
  count         = 2
  ami           = var.ami_id
  instance_type = "t2.micro"
  security_groups = [aws_security_group.frontend_sg.name]

  tags = {
    Name = "frontend-instance-${count.index}"
  }
}

# Instances EC2 pour le back-end
resource "aws_instance" "backend_instance" {
  count         = 2
  ami           = var.ami_id
  instance_type = "t2.micro"
  security_groups = [aws_security_group.backend_sg.name]

  tags = {
    Name = "backend-instance-${count.index}"
  }
}

# Load Balancer pour le front-end
resource "aws_elb" "frontend_elb" {
  name               = "frontend-elb"
  availability_zones = ["us-east-1a", "us-east-1b"] # Remplacez par vos zones de disponibilité
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
  availability_zones = ["us-east-1a", "us-east-1b"] # Remplacez par vos zones de disponibilité
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
