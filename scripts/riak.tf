resource "aws_instance" "server" {
    ami = "${lookup(var.ami, var.region)}"
    instance_type = "m1.small"
    key_name = "${var.key_name}"
    count = "${var.servers}"
    security_groups = ["${aws_security_group.riak.name}"]

    connection {
        user = "ubuntu"
        key_file = "${var.key_path}"
    }

    provisioner "file" {
        source = "${path.module}/../envs"
        destination = "~"
    }

    provisioner "file" {
        source = "${path.module}/payload"
        destination = "~"
    }

    provisioner "file" {
        source = "${path.module}/../node_modules/bash3boilerplate"
        destination = "~/payload"
    }

    provisioner "remote-exec" {
        inline = [
            "echo ${var.servers} > /tmp/riak-server-count",
            "echo ${aws_instance.server.0.private_dns} > /tmp/riak-leader-addr",
            "bash -c \"source ~/envs/${var.deploy_env}.sh && sudo -HE bash ~/payload/install.sh\"",
            "bash -c \"source ~/envs/${var.deploy_env}.sh && sudo -HE env RIFOR_LEADER_IP=${aws_instance.server.0.private_dns} bash ~/payload/setup.sh\"",
        ]
    }
}

resource "aws_security_group" "riak" {
    name = "riak"
    description = "Consul internal traffic + maintenance."

    // These are for internal traffic
    ingress {
        from_port = 0
        to_port = 65535
        protocol = "tcp"
        self = true
    }

    ingress {
        from_port = 0
        to_port = 65535
        protocol = "udp"
        self = true
    }

    // These are for maintenance
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}
