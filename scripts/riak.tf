resource "aws_instance" "server" {
    ami = "${lookup(var.ami, var.region)}"
    instance_type = "c1.medium"
    key_name = "${var.key_name}"
    count = "${var.servers}"
    security_groups = ["${aws_security_group.riak.name}"]

    connection {
        user = "ubuntu"
        key_file = "${var.key_path}"
    }

    provisioner "remote-exec" {
        inline = [
            "echo ${var.servers} > ~/riak-server-count",
            "echo ${aws_instance.server.0.private_dns} > ~/riak-leader-addr",
            "echo ${aws_instance.server.0.private_ip} > ~/riak-leader-private-ip",
            "curl --silent --retry 3 http://169.254.169.254/latest/meta-data/local-hostname > ~/riak-self-addr",
            "curl --silent --retry 3 http://169.254.169.254/latest/meta-data/local-ipv4 > ~/riak-self-private-ip",
        ]
    }
}

resource "aws_security_group" "riak" {
    name = "riak"
    description = "Internal traffic + maintenance."

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

    // SSH
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    // Https
    ingress {
        from_port = 8069
        to_port = 8069
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    // Http
    ingress {
        from_port = 8098
        to_port = 8098
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}
