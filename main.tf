#PROVIDER
provider "aws" {
	region = "ap-south-1"
}


data "aws_availability_zones" "available" {}

#VPC
resource "aws_vpc" "main" {
  cidr_block = "10.10.0.0/16"
}


#SUBNETS
resource "aws_subnet" "publicsubnet"{
  count = "${var.azs_count}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)}"
  tags {
    Name = "${var.tagname_subnet}"
  }
}



#INTERNETGATEWAY
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
}


#ROUTETABLE
resource "aws_route_table" "test_route" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
}

resource "aws_route_table_association" "associate_route_table" {
  count = "${var.azs_count}"
  subnet_id      = "${element(aws_subnet.publicsubnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.test_route.id}"
}


#INSTANCE
resource "aws_instance" "apache-php" {

  security_groups = ["${aws_security_group.instance-sg.id}"]
  ami           = "ami-0cc933559cda16fcd"
  instance_type = "t2.micro"
  key_name = "damodaran_test"
  subnet_id = "${aws_subnet.publicsubnet.0.id}"
  associate_public_ip_address = true
  user_data = "${file("${path.module}/installing-components.sh")}"


  tags {
    Name = "Apache-PHP"
  }
}




#SECURITYGROUPS
resource "aws_security_group" "instance-sg" {
  name        = "instance security group"
  description = "Allow all inbound traffic"
  vpc_id      = "${aws_vpc.main.id}"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [
      "${aws_security_group.lb_sg.id}",
    ]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0",]
  }

  tags {
    Name = "Apache-PHP security group"
  }
}


resource "aws_security_group" "lb_sg" {
  name        = "elb security group"
  description = "Allow all inbound traffic"
  vpc_id      = "${aws_vpc.main.id}"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0",]
  }

  tags {
    Name = "Apache-PHP LB security group"
  }
}



#LOADBALANCERS


resource "aws_elb" "apache_php_elb" {
  name = "Apache-PHP-LB"
  internal = false
  security_groups = ["${aws_security_group.lb_sg.id}"]
  subnets = ["${aws_subnet.publicsubnet.*.id}"]
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  health_check {    
    healthy_threshold   = 10    
    unhealthy_threshold = 2    
    timeout             = 5       
    interval            = 10 
    target              = "HTTP:80/index.php"    
  }
  instances = ["${aws_instance.apache-php.id}"]

}
