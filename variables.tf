variable "vpc_name" {
  type = string
  default = "ngwe-enterprise"
}

variable "subnet_prefix" {
  type = list(object({
    cidr_block = string
    name       = string
  }))

  default = [
    {
      cidr_block = "10.0.1.0/24"
      name       = "pub_subnet-1"
    },
    {
      cidr_block = "10.0.2.0/24"
      name       = "pub_subnet-2"
    },
    {
      cidr_block = "10.0.3.0/24"
      name       = "priv_subnet-1"
    },
    {
      cidr_block = "10.0.4.0/24"
      name       = "priv_subnet-2"
    }
  ]
}



