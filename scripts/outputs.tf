output "leader_address" {
  value = "${aws_instance.server.0.public_dns}"
}
output "leader_private_ip" {
  value = "${aws_instance.server.0.private_ip}"
}
output "public_addresses" {
  value = "${join(\"\n\", aws_instance.server.*.public_dns)}"
}
output "server_count" {
  value = "${var.servers}"
}
