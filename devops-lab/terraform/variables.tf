variable "kubeconfig" {
  description = "Ruta al kubeconfig del cluster k3s"
  type        = string
  default     = "~/.kube/config"
}

variable "grafana_admin_password" {
  description = "Contraseña del usuario admin de Grafana"
  type        = string
  sensitive   = true
}

# Deja null para instalar la última versión. Buena práctica: una vez instalado,
# fija la versión (helm list -A) para que las instalaciones sean reproducibles.
variable "argocd_chart_version" {
  type    = string
  default = null
}

variable "monitoring_chart_version" {
  type    = string
  default = null
}
