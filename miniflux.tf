terraform {

  backend "s3" {}
}

provider "aws" {}

variable "aws_ami" {
  description = "The ID of the AWS AMI you'd like to use for the Miniflux server."
  default = "ami-41e0b93b"
}

variable "aws_instance_type" {
  description = "The AWS instance type."
  default = "t2.nano"
}

variable "aws_private_key_name" {
  description = "The name of your AWS keypair."
}

variable "aws_private_key_path" {
  description = "The path (relative or absolute) to your AWS private key."
}

variable "aws_ssl_certificate_id" {
  description = "The name of your AWS SSL certificate, which you can create with the AWS Certificate Manager at https://console.aws.amazon.com/acm/home."
}

resource "aws_vpc" "miniflux" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags {
    Name = "miniflux"
  }
}

resource "aws_internet_gateway" "miniflux" {
  vpc_id = "${aws_vpc.miniflux.id}"

  tags {
    Name = "miniflux"
  }
}

resource "aws_route" "miniflux" {
  route_table_id = "${aws_vpc.miniflux.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.miniflux.id}"
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "primary" {
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  vpc_id = "${aws_vpc.miniflux.id}"
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags {
    Name = "miniflux"
  }
}

resource "aws_security_group" "elb" {
  vpc_id      = "${aws_vpc.miniflux.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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

resource "aws_security_group" "instance" {
  vpc_id = "${aws_vpc.miniflux.id}"

  ingress {
    from_port = 80
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "miniflux"
  }
}

resource "aws_instance" "miniflux" {
  ami = "${var.aws_ami}"
  instance_type = "${var.aws_instance_type}"
  key_name = "${var.aws_private_key_name}"
  vpc_security_group_ids = ["${aws_security_group.instance.id}"]
  subnet_id = "${aws_subnet.primary.id}"
  associate_public_ip_address = true

  connection {
    host = "${self.public_ip}"
    user = "ubuntu"
    private_key = "${file("${var.aws_private_key_path}")}"
  }

  provisioner "habitat" {
    use_sudo = true
    service_type = "systemd"

    service {
      name = "core/postgresql"
      channel = "stable"
    }

    service {
      name = "cnunciato/miniflux"
      channel = "unstable"
      strategy = "at-once"

      bind {
        alias = "db"
        service = "postgresql"
        group = "default"
      }
    }
  }

  tags {
    Name = "miniflux"
  }
}

resource "aws_elb" "miniflux" {
  security_groups = ["${aws_security_group.elb.id}"]
  subnets = ["${aws_subnet.primary.id}"]

  listener {
    instance_port = 8080
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  listener {
    instance_port = 8080
    instance_protocol = "http"
    lb_port = 443
    lb_protocol = "https"
    ssl_certificate_id = "${var.aws_ssl_certificate_id}"
  }

  tags {
    Name = "miniflux"
  }
}

resource "aws_elb_attachment" "miniflux" {
  elb = "${aws_elb.miniflux.id}"
  instance = "${aws_instance.miniflux.id}"
}

output "elb_host" {
  value = "${aws_elb.miniflux.dns_name}"
}

output "elb_url" {
  value = "https://${aws_elb.miniflux.dns_name}"
}

output "instance_ip" {
  value = "${aws_instance.miniflux.public_ip}"
}

output "instance_connect" {
  value = "ssh ubuntu@${aws_instance.miniflux.public_ip} -i ${var.aws_private_key_path}"
}
