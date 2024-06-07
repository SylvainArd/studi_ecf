# Instances EC2 pour le front-end
resource "aws_instance" "frontend_instance" {
  count         = 2
  ami           = "ami-00beae93a2d981137" 
  instance_type = "t2.micro"
  security_groups = [aws_security_group.frontend_sg.name]

  tags = {
    Name = "frontend-instance-${count.index}"
  }
}

# Instances EC2 pour le back-end
resource "aws_instance" "backend_instance" {
  count         = 2
  ami           = "ami-00beae93a2d981137" 
  instance_type = "t2.micro"
  security_groups = [aws_security_group.backend_sg.name]

  tags = {
    Name = "backend-instance-${count.index}"
  }
}

# Load Balancer pour le front-end
resource "aws_elb" "frontend_elb" {
  name               = "frontend-elb"
  availability_zones = ["us-west-2a", "us-west-2b"] # Remplacez par vos zones de disponibilité
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
  availability_zones = ["us-west-2a", "us-west-2b"] # Remplacez par vos zones de disponibilité
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
  name                 = "mydb"
  username             = "admin"
  password             = "lOP659Pou!" # Changez ce mot de passe pour une valeur sécurisée
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
  publicly_accessible  = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  tags = {
    Name = "mydb"
  }
}
