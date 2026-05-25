# ---------------------------------------------------------------------------------------------------------------------
# EKS Module Outputs
# ---------------------------------------------------------------------------------------------------------------------

output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.main.name
}

output "cluster_id" {
  description = "ID of the EKS cluster."
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Endpoint of the EKS cluster."
  value       = aws_eks_cluster.main.endpoint
  sensitive   = true
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for the cluster."
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "The URL of the OIDC issuer."
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC provider."
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "node_role_arn" {
  description = "ARN of the EKS node IAM role."
  value       = aws_iam_role.node.arn
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host."
  value       = var.enable_bastion ? aws_instance.bastion[0].public_ip : null
}

output "bastion_private_key_pem" {
  description = "Private key for bastion SSH (save securely)."
  value       = var.enable_bastion ? tls_private_key.bastion[0].private_key_pem : null
  sensitive   = true
}
