output "leader_address" {
    value = "${aws_instance.server.0.public_dns}"
}
