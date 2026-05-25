# ---------------------------------------------------------------------------------------------------------------------
# GitOps Module Outputs
# ---------------------------------------------------------------------------------------------------------------------

output "argocd_namespace" {
  description = "Namespace where ArgoCD is deployed."
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_server_deployment" {
  description = "Name of the ArgoCD server deployment."
  value       = "argocd-server"
}
