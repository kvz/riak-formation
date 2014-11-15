
variable "ami" {
    default = {
        us-east-1 = "ami-3acc7a52"
        eu-west-1 = "ami-37501207"
    }
}

variable "key_name" {
    description = "SSH key name in your AWS account for AWS instances."
}

variable "key_path" {
    description = "Path to the private key specified by key_name."
}

variable "access_key" {
    description = "Access key to manage AWS account."
}

variable "secret_key" {
    description = "Secret key to manage AWS account."
}

variable "region" {
    default = "us-east-1"
    description = "The region of AWS, for AMI lookups."
}

variable "servers" {
    default = "3"
    description = "The number of Consul servers to launch."
}
