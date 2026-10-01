# Infraestructura base del laboratorio como código:
#   - Namespaces de plataforma
#   - ArgoCD (GitOps)
#   - kube-prometheus-stack (Prometheus + Grafana + Alertmanager)

provider "kubernetes" {
  config_path = pathexpand(var.kubeconfig)
}

provider "helm" {
  kubernetes {
    config_path = pathexpand(var.kubeconfig)
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name   = "argocd"
    labels = { "managed-by" = "terraform" }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name   = "monitoring"
    labels = { "managed-by" = "terraform" }
  }
}

resource "helm_release" "monitoring" {
  name       = "kps"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.monitoring_chart_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 900

  values = [file("${path.module}/values/monitoring.yaml")]

  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  timeout    = 600

  values = [file("${path.module}/values/argocd.yaml")]

  # Se instala después del monitoreo para que el CRD ServiceMonitor ya exista
  depends_on = [helm_release.monitoring]
}
