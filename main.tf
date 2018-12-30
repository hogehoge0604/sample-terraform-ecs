provider "aws" {
  region = "ap-northeast-1"
}

resource "aws_cloudwatch_log_group" "ecs" {
  name = "/ecs/test"
}

resource "aws_ecs_cluster" "test" {
  name = "test-cluster"
}

resource "aws_ecs_service" "test" {
  name = "test-service"
  task_definition = "${aws_ecs_task_definition.test.arn}"
  cluster = "${aws_ecs_cluster.test.arn}"
  desired_count = "1"

  launch_type = "FARGATE"

  network_configuration {
    subnets = [
      "${aws_subnet.public.id}",
    ]
    security_groups = ["${aws_security_group.ecs.id}"]
    assign_public_ip = true
  }

  lifecycle {
    ignore_changes = ["desired_count"]
  }

  depends_on = ["aws_ecs_cluster.test"]
}

resource "aws_ecs_task_definition" "test" {
  family = "test-task"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = "256"
  memory = "512"
  container_definitions = "${file("${path.module}/container_definitions.json")}"
  execution_role_arn = "${data.aws_iam_role.ecs_task_execution_role.arn}"

  depends_on = ["aws_ecs_cluster.test", "aws_cloudwatch_log_group.ecs"]
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_security_group" "ecs" {
  name = "test-ecs"
  vpc_id = "${aws_vpc.main.id}"
  
  ingress {
    protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_subnet" "public" {
  cidr_block = "${cidrsubnet(aws_vpc.main.cidr_block, 8, 0)}"
  vpc_id = "${aws_vpc.main.id}"
  map_public_ip_on_launch = true
}

resource "aws_route" "public" {
  route_table_id = "${aws_vpc.main.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.gateway.id}"
}

resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_vpc.main.main_route_table_id}"
}

data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}
