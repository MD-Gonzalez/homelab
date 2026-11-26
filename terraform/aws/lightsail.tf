# WireGuard relay on Lightsail — replaces the hand-built Debian EC2.
#
# Fixed $5/month bundle (2 vCPU, 0.5 GB, 20 GB SSD, 1 TB transfer) with a
# static IPv4 that survives stop/start, so vpn.sigilos.st never goes stale.
# The relay keeps the EC2's WireGuard keys and 10.10.0.6 address, so the
# router and clients don't change.

variable "ssh_public_key" {
  description = "Public half of the SSH key kept in KeePass (contents of the .pub)"
  type        = string
}

variable "ssh_admin_cidrs" {
  description = "Extra source CIDRs allowed to SSH to the public IP (for the migration only; leave empty afterwards — day-to-day SSH goes through the tunnel)"
  type        = list(string)
  default     = []
}

resource "aws_lightsail_key_pair" "admin" {
  name       = "nuuvv-keepass"
  public_key = var.ssh_public_key
}

resource "aws_lightsail_instance" "vpn" {
  name              = "vpn-relay"
  availability_zone = "us-east-2a"
  blueprint_id      = "debian_12"
  bundle_id         = "nano_3_0" # $5/month with public IPv4
  key_pair_name     = aws_lightsail_key_pair.admin.name

  user_data = <<-EOT
    #!/bin/sh
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard-tools iptables
  EOT

  tags = {
    role = "wireguard-relay"
  }
}

resource "aws_lightsail_static_ip" "vpn" {
  name = "vpn-relay-ip"
}

resource "aws_lightsail_static_ip_attachment" "vpn" {
  static_ip_name = aws_lightsail_static_ip.vpn.name
  instance_name  = aws_lightsail_instance.vpn.name
}

# Lightsail firewall: replaces every default rule on the instance.
resource "aws_lightsail_instance_public_ports" "vpn" {
  instance_name = aws_lightsail_instance.vpn.name

  # WireGuard, from anywhere
  port_info {
    protocol   = "udp"
    from_port  = 51820
    to_port    = 51820
    cidrs      = ["0.0.0.0/0"]
    ipv6_cidrs = ["::/0"]
  }

  # SSH: Lightsail's browser console, plus any temporary admin CIDRs
  port_info {
    protocol          = "tcp"
    from_port         = 22
    to_port           = 22
    cidr_list_aliases = ["lightsail-connect"]
    cidrs             = var.ssh_admin_cidrs
  }
}

output "vpn_static_ip" {
  description = "Put this in terraform/cloudflare/dns.tf (cloudflare_record.vpn)"
  value       = aws_lightsail_static_ip.vpn.ip_address
}
