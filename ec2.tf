resource "aws_instance" "web1" {
  associate_public_ip_address = true
  subnet_id = aws_subnet.pub-subnet-1.id
  ami           = "ami-080e1f13689e07408"
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.sec-tf.id]

  tags = {
    Name = "web1"
  }
  user_data     = <<-EOF
  #!/bin/bash
  sudo apt update
  sudo apt install nginx -y
  systemctl enable nginx
  systemctl start nginx
  EOF
}
