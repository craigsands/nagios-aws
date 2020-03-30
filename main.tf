variable "env" {
  default = "dev"
}

variable "project" {
  default = "nagios"
}

variable "instance_type" {
  default     = "t3.xlarge"
  description = "EC2 instance type"
}

variable "ssh_public_key" {
  default     = "~/.ssh/id_rsa"
  description = "Path to public key file"
}

variable "allow_cidr_block" {
  default     = "0.0.0.0/0"
  description = "CIDR block to allow for remote access to instances"
}

variable "region" {
  default = "us-east-1"
}


provider "aws" {
  region = "${var.region}"
}

resource "aws_vpc" "main" {
  cidr_block = "${var.env == "prd" ? "10.0.0.0/16" : "172.16.0.0/16"}"

  tags = {
    Name = "${var.project}-${var.env}-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_subnet" "subnet_1" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "${var.env == "prd" ? "10.0.1.0/24" : "172.16.1.0/24"}"
  map_public_ip_on_launch = true
  depends_on              = ["aws_internet_gateway.gw"]

  tags = {
    Name = "${var.project}-${var.env}-subnet-1"
  }
}

resource "aws_route_table" "route" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    Name = "${var.project}-${var.env}-rt"
  }
}

resource "aws_route_table_association" "route_subnet" {
  subnet_id      = "${aws_subnet.subnet_1.id}"
  route_table_id = "${aws_route_table.route.id}"
}

resource "aws_eip" "nagios" {
  instance   = "${aws_instance.nagios.id}"
  vpc        = true
  depends_on = ["aws_internet_gateway.gw"]
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_security_group" "nagios_sg" {
  name        = "${var.project}-${var.env}-sg"
  description = "Allow nagios"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.allow_cidr_block}"]
  }

  ingress {
    description = "Web interface"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.allow_cidr_block}"]
  }

  ingress {
    description = "Https web interface"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${var.allow_cidr_block}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_key_pair" "nagios" {
  key_name   = "nagios"
  public_key = "${file(var.ssh_public_key)}"
}

resource "aws_instance" "nagios" {
  ami                    = "${data.aws_ami.ubuntu.id}"
  instance_type          = "${var.instance_type}"
  key_name               = "${aws_key_pair.nagios.key_name}"
  vpc_security_group_ids = ["${aws_security_group.nagios_sg.id}"]
  subnet_id              = "${aws_subnet.subnet_1.id}"
  user_data              = "${file("./install_nagios.sh")}"

  root_block_device {
    volume_type = "standard"
    volume_size = 80

  }

  tags = {
    Name = "${var.project}-${var.env}"
  }
}
