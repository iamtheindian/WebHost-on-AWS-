#Login to console
provider "aws" {
	region = "ap-south-1"
	profile= "rbterra"
}
#Creating VPC
resource "aws_vpc" "main" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true 
  tags = {
    Name = "aws_main"
  }
}
#Creating private subnet
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "private_sub"
  }
  depends_on =[
		aws_vpc.main
  ]
}

#Creating public subnet
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.2.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public_sub"
  }
  depends_on =[
		aws_vpc.main
  ]
}

#Assigning IGW
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "IGW_aws_main"
  }
  depends_on =[
		aws_vpc.main
  ]
}

resource "aws_route_table" "art" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "igw_route"
  }
  depends_on =[
		aws_vpc.main
  ]
}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.art.id
  
  depends_on =[
		aws_route_table.art
  ]
}

#Creating SG for WORDPRESS
resource "aws_security_group" "sg_wordpress" {
  name        = "sg_wordpress"
  description = "Allow WORDPRESS inbound traffic"
  vpc_id      =  aws_vpc.main.id

  ingress {
    description = "SSH CONFIG"
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
    Name = "sg_wordpress"
  }
  depends_on =[
		aws_vpc.main
  ]
}
resource "aws_security_group_rule" "asgr_wordpress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id =  aws_security_group.sg_wordpress.id
  description = "HTTP CONFIG"
  depends_on =[
		aws_security_group.sg_wordpress
  ]
}

#Creating SG for WORDPRESS
resource "aws_security_group" "sg_mysql" {
  name        = "sg_mysql"
  description = "Allow MYSQL inbound traffic"
  vpc_id      =  aws_vpc.main.id

  ingress {
    description = "SSH CONFIG"
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
    Name = "sg_mysql"
  }
  depends_on =[
		aws_vpc.main
  ]
}
resource "aws_security_group_rule" "asgr_mysql" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id =  aws_security_group.sg_mysql.id
  description = "SQL CONFIG"
  depends_on =[
		aws_security_group.sg_mysql
  ]
}

#Varaible for WORDPRESS AMI
variable "wp_ami" {
	default = "ami-7e257211"
}
  
#Varaible for MYSQL AMI
variable "ms_ami" {
	default = "ami-76166b19"
}

#Creating KEY_PAIR
resource "tls_private_key" "tkey" {
  algorithm   = "RSA"
}
#assigne public openssh to the aws key pair
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = tls_private_key.tkey.public_key_openssh
  depends_on=[tls_private_key.tkey]
 }

#use key_name variable in the field of aws_instance's key_name
#if you want to save this key then use this
resource "local_file" "lf" {
  content = tls_private_key.tkey.private_key_pem
  filename= "awskey.pem"
}

resource "aws_instance" "webos" {
  ami           =    var.wp_ami
  instance_type =    "t2.micro"
  key_name      =    aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.sg_wordpress.id]
  subnet_id     = aws_subnet.public.id
  tags = {
    Name = "WORDPRESS"
  }
}
resource "aws_instance" "dbos" {
  ami           =    var.ms_ami
  instance_type =    "t2.micro"
  key_name      =    aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.sg_mysql.id]
  subnet_id     = aws_subnet.private.id
  tags = {
    Name = "MYSQL"
  }
}