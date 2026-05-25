# ---------------------------------------------------------------------------------------------------------------------
# GitOps Module
# ArgoCD via Helm with HA, App of Apps, ApplicationSet for envs.
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# ArgoCD Namespace
# ---------------------------------------------------------------------------------------------------------------------

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = merge(var.common_tags, {
      name = "argocd"
    })
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ArgoCD Helm Release
# ---------------------------------------------------------------------------------------------------------------------

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [templatefile("${path.module}/values-argocd.yaml", {
    name_prefix = var.name_prefix
  })]

  depends_on = [kubernetes_namespace.argocd]
}

# ---------------------------------------------------------------------------------------------------------------------
# App of Apps - Master Application
# ---------------------------------------------------------------------------------------------------------------------

resource "kubernetes_manifest" "app_of_apps" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "app-of-apps"
      namespace = kubernetes_namespace.argocd.metadata[0].name
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.target_revision
        path           = "kubernetes/argocd-apps"
        directory = {
          recurse = true
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.argocd.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune      = var.enable_prune
          selfHeal   = var.enable_self_heal
          allowEmpty = false
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }

  depends_on = [helm_release.argocd]
}

# ---------------------------------------------------------------------------------------------------------------------
# ApplicationSet for Environments
# ---------------------------------------------------------------------------------------------------------------------

resource "kubernetes_manifest" "applicationset_envs" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"
    metadata = {
      name      = "environments"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      generators = [
        {
          list = {
            elements = [
              { env = "dev", namespace = "dev" },
              { env = "staging", namespace = "staging" },
              { env = "prod", namespace = "prod" }
            ]
          }
        }
      ]
      template = {
        metadata = {
          name = "{{env}}-apps"
        }
        spec = {
          project = "default"
          source = {
            repoURL        = var.gitops_repo_url
            targetRevision = var.target_revision
            path           = "kubernetes/argocd-apps/{{env}}"
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "{{namespace}}"
          }
          syncPolicy = {
            automated = {
              prune    = var.enable_prune
              selfHeal = var.enable_self_heal
            }
            syncOptions = ["CreateNamespace=true"]
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}

# ---------------------------------------------------------------------------------------------------------------------
# ArgoCD Notifications
# ---------------------------------------------------------------------------------------------------------------------

resource "kubernetes_config_map" "argocd_notifications_cm" {
  count = var.notifications_enabled ? 1 : 0

  metadata {
    name      = "argocd-notifications-cm"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  data = {
    "service.${var.notification_channel}.placeholder" = <<EOT
      token: $placeholder-token
EOT
    "template.app-sync-succeeded" = <<EOT
      message: |
        Application {{.app.metadata.name}} has been successfully synced.
EOT
    "trigger.on-sync-succeeded" = <<EOT
      - when: app.status.operationState.phase in ['Succeeded']
        send: [app-sync-succeeded]
EOT
  }

  depends_on = [helm_release.argocd]
}

# ---------------------------------------------------------------------------------------------------------------------
# Pre-Sync Hook Example (DB Migration)
# ---------------------------------------------------------------------------------------------------------------------

resource "kubernetes_manifest" "presync_migration" {
  manifest = {
    apiVersion = "batch/v1"
    kind       = "Job"
    metadata = {
      name      = "db-migration-presync"
      namespace = "prod"
      annotations = {
        "argocd.argoproj.io/hook"        = "PreSync"
        "argocd.argoproj.io/hook-delete-policy" = "HookSucceeded"
      }
    }
    spec = {
      template = {
        spec = {
          restartPolicy = "OnFailure"
          containers = [
            {
              name    = "migration"
              image   = "busybox:latest"
              command = ["sh", "-c", "echo 'Running DB migration placeholder...'; sleep 5"]
            }
          ]
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}
