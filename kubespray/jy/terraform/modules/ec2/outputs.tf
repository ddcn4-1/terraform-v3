# modules/ec2/outputs.tf
# EC2 모듈 출력값

# ==========================================
# NAT Instance
# ==========================================

output "nat_instance_id" {
  description = "NAT Instance ID"
  value       = aws_instance.nat_instance.id
}

output "nat_instance_private_ip" {
  description = "NAT Instance Private IP"
  value       = aws_instance.nat_instance.private_ip
}

output "nat_instance_public_ip" {
  description = "NAT Instance Public IP"
  value       = aws_eip.nat_instance.public_ip
}

# ==========================================
# Bastion Host
# ==========================================

output "bastion_id" {
  description = "Bastion Host Instance ID"
  value       = aws_instance.bastion.id
}

output "bastion_private_ip" {
  description = "Bastion Host Private IP"
  value       = aws_instance.bastion.private_ip
}

output "bastion_public_ip" {
  description = "Bastion Host Public IP (SSH 접근용)"
  value       = aws_eip.bastion.public_ip
}

# ==========================================
# Control Plane
# ==========================================

output "control_plane_id" {
  description = "Control Plane Instance ID"
  value       = aws_instance.control_plane.id
}

output "control_plane_private_ip" {
  description = "Control Plane Private IP"
  value       = aws_instance.control_plane.private_ip
}

output "control_plane_hostname" {
  description = "Control Plane Hostname"
  value       = "k8s-control-plane"
}

# ==========================================
# Worker Nodes
# ==========================================

output "worker_node_ids" {
  description = "Worker Node Instance IDs"
  value       = aws_instance.worker_nodes[*].id
}

output "worker_nodes_private_ips" {
  description = "Worker Nodes Private IPs"
  value       = aws_instance.worker_nodes[*].private_ip
}

output "worker_node_hostnames" {
  description = "Worker Node Hostnames"
  value       = local.worker_node_names
}
