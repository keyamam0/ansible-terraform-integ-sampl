# Configure the AWS Provider

variable "key_name" {
  default = "my-keypair-tmp"
}
provider "aws" {
  region = "ap-northeast-1"
  # access_key = "xxxx"
  # secret_key = "xxxx"
}

resource "aws_instance" "xxx" {
  ami = "ami-01b32aa8589df6208"
  instance_type = "t2.micro"
  key_name = var.key_name
  #vpc_security_group_ids = ["<セキュリティグループID>"]

  tags = {
    Name = "HelloAnsible-01"
    myGroup = "ansible"
  }
}

resource "aws_instance" "xxx2" {
  ami = "ami-01b32aa8589df6208"
  instance_type = "t2.micro"
  key_name = var.key_name
  #vpc_security_group_ids = ["<セキュリティグループID>"]

  tags = {
    Name = "HelloAnsible-02"
    myGroup = "ansible"
  }
}