variable "aws-key-pair" {
  type = string
  default = "jack-ubuntu"
}

variable "eks-cluster-name" {
  type = string
  default = "elvis"
}

provider "aws" {
  profile = "default"
  region  = "us-east-2"
}

## VPC and Subnet Creation ##

## NOTE: AWS generally defines a public subnet as having an Internet Gateway. 
## A private subnet has a NAT Gateway (in a public subnet) or no gateway at all.
## See https://serverfault.com/questions/854475/aws-nat-gateway-in-public-subnet-why

## VPC and subnet address range are using the recommended values in
## https://aws.amazon.com/blogs/containers/optimize-ip-addresses-usage-by-pods-in-your-amazon-eks-cluster/

resource "aws_vpc" "eks_vpc" {
  cidr_block                       = "10.0.0.0/16"
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name = "eks_vpc"
  }
}

resource "aws_subnet" "eks_subnet_priv_a" {
  vpc_id     = aws_vpc.eks_vpc.id
  cidr_block = "10.0.48.0/20"
  availability_zone = "us-east-2a"

  tags = {
    Name = "eks_subnet_priv_a"
    "kubernetes.io/cluster/${var.eks-cluster-name}" = "shared"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "eks_subnet_priv_b" {
  vpc_id     = aws_vpc.eks_vpc.id
  cidr_block = "10.0.64.0/20"
  availability_zone = "us-east-2b"

  tags = {
    Name = "eks_subnet_priv_b"
    "kubernetes.io/cluster/${var.eks-cluster-name}" = "shared"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

## NOTE: Public subnets MUST be associated to the application load balancers
## Instances themselves can be on the private subnets.
## SEE: https://stackoverflow.com/questions/54871524/elastic-load-balancer-pointing-at-private-subnet
resource "aws_subnet" "eks_subnet_public_a" {
  vpc_id     = aws_vpc.eks_vpc.id
  cidr_block = "10.0.0.0/20"
  availability_zone = "us-east-2a"

  tags = {
    Name = "eks_subnet_public_a"
    "kubernetes.io/cluster/${var.eks-cluster-name}" = "shared"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "eks_subnet_public_b" {
  vpc_id     = aws_vpc.eks_vpc.id
  cidr_block = "10.0.16.0/20"
  availability_zone = "us-east-2b"

  tags = {
    Name = "eks_subnet_public_b"
    "kubernetes.io/cluster/${var.eks-cluster-name}" = "shared"
    "kubernetes.io/role/elb" = "1"
  }
}


# This is compatible with ipv6 only
# https://docs.aws.amazon.com/vpc/latest/userguide/egress-only-internet-gateway.html
#resource "aws_egress_only_internet_gateway" "eks_egress" {
#  vpc_id = aws_vpc.eks_vpc.id
#
#  tags = {
#    Name = "eks_egress"
#  }
#}

resource "aws_internet_gateway" "eks_gw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks-gw"
  }
}


## Security Groups Creation ##
resource "aws_security_group" "allow_tls_http_lb" {
  name        = "allow-tls-http-lb"
  description = "Allow TLS, HTTP inbound traffic"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    description = "TLS from Anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from Anywhere"
    from_port   = 80
    to_port     = 80
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

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "allow_tls_http_ssh_vpc" {
  name        = "allow-tls-http-ssh"
  description = "Allow TLS, HTTP, SSH inbound traffic from VPC"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    description = "TLS from Application Load Balancer"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [aws_security_group.allow_tls_http_lb.id]
  }

  ingress {
    description = "HTTP from Application Load Balancer"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.allow_tls_http_lb.id]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.eks_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls_http_ssh_vpc"
  }
}

# For the bastion host
resource "aws_security_group" "allow_ssh_anywhere" {
  name        = "allow-ssh-anywhere"
  description = "Allow SSH inbound traffic from Anywhere"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    description = "SSH from Anywhere"
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
    Name = "allow_ssh_anywhere"
  }

}

## Create Route To the Gateway in the VPC Route Table ##
resource "aws_route" "eks_route" {
  route_table_id = aws_vpc.eks_vpc.default_route_table_id
    destination_cidr_block    = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_gw.id
  
}

## Create the Elastic IPs ##
resource "aws_eip" "eks_subnet_priv_a_eip" {
  vpc              = true
  public_ipv4_pool = "amazon"
}

resource "aws_eip" "eks_subnet_priv_b_eip" {
  vpc              = true
  public_ipv4_pool = "amazon"
}

## Create the NAT Gateways ##

## NOTE: NAT gateways MUST be on the public subnets 
## See: https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-troubleshooting.html#nat-gateway-troubleshooting-no-internet-connection
resource "aws_nat_gateway" "eks_subnet_priv_a_gw" {
  allocation_id = aws_eip.eks_subnet_priv_a_eip.id
  subnet_id     = aws_subnet.eks_subnet_public_a.id

  tags = {
    Name = "eks_subnet_public_a_gw NAT"
    Notes = "NAT gateways MUST be on the public subnets. See: https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-troubleshooting.html#nat-gateway-troubleshooting-no-internet-connection"
  }
}

resource "aws_nat_gateway" "eks_subnet_priv_b_gw" {
  allocation_id = aws_eip.eks_subnet_priv_b_eip.id
  subnet_id     = aws_subnet.eks_subnet_public_b.id

  tags = {
    Name = "eks_subnet_public_b_gw NAT"
    Notes = "NAT gateways MUST be on the public subnets. See: https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-troubleshooting.html#nat-gateway-troubleshooting-no-internet-connection"
  }
}

## Create Routes to the NAT Gateways ##
resource "aws_route_table" "eks_subnet_priv_a_rt" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "eks_subnet_priv_a_rt"
  }
}

resource "aws_route_table" "eks_subnet_priv_b_rt" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "eks_subnet_priv_b_rt"
  }
  
}


resource "aws_route" "eks_subnet_priv_a_route" {
  route_table_id = aws_route_table.eks_subnet_priv_a_rt.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.eks_subnet_priv_a_gw.id
}

resource "aws_route" "eks_subnet_priv_b_route" {
  route_table_id = aws_route_table.eks_subnet_priv_b_rt.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.eks_subnet_priv_b_gw.id
}

# NOTE: If the route tables are not explicitly associated with a subnet
# the VPC main route table is used.
resource "aws_route_table_association" "eks_subnet_priv_a_route_table_association" {
  subnet_id     = aws_subnet.eks_subnet_priv_a.id
  route_table_id = aws_route_table.eks_subnet_priv_a_rt.id
}

resource "aws_route_table_association" "eks_subnet_priv_b_route_table_association" {
  subnet_id     = aws_subnet.eks_subnet_priv_b.id
  route_table_id = aws_route_table.eks_subnet_priv_b_rt.id
}


## Bastion Host Creation ##

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_configuration#using-with-autoscaling-groups
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# https://harshitdawar.medium.com/launching-a-vpc-with-public-private-subnet-nat-gateway-in-aws-using-terraform-99950c671ce9
resource "aws_instance" "bastion_host" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = var.aws-key-pair
  associate_public_ip_address = true
  subnet_id   = aws_subnet.eks_subnet_public_b.id
  vpc_security_group_ids = [aws_security_group.allow_ssh_anywhere.id]

  tags = {
    Name = "Bastion Host"
  }
}

## EKS Cluster Creation ##

## IAM role from https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster
resource "aws_iam_role" "eks_iam_role" {
  name = "eks-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_iam_role.name
}

# Optionally, enable Security Groups for Pods
# Reference: https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html
resource "aws_iam_role_policy_attachment" "eks_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_iam_role.name
}

resource "aws_eks_cluster" "eks" {
  name     = var.eks-cluster-name
  role_arn = aws_iam_role.eks_iam_role.arn

  vpc_config {
    subnet_ids = [aws_subnet.eks_subnet_priv_a.id, aws_subnet.eks_subnet_priv_b.id, aws_subnet.eks_subnet_public_a.id, aws_subnet.eks_subnet_public_b.id]

    endpoint_public_access = true
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.eks_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_AmazonEKSVPCResourceController,
  ]
}

output "endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.eks.certificate_authority[0].data
}

### EKS Nodes Cluster Configuration ###

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group

resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_eks_node_group" "eks_nodes" {

  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "eks-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids = [aws_subnet.eks_subnet_priv_a.id, aws_subnet.eks_subnet_priv_b.id]

  ami_type       = "AL2_x86_64"
  instance_types = ["t2.micro"]

  remote_access {
    ec2_ssh_key               = var.aws-key-pair
    source_security_group_ids = [aws_security_group.allow_ssh_anywhere.id]
  }

  scaling_config {
    # Example: Create EKS Node Group with 2 instances to start
    desired_size = 3
    max_size     = 5
    min_size     = 2
  }

  # Optional: Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}