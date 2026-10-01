output "acceso_argocd" {
  value = "kubectl -n argocd port-forward svc/argocd-server 8081:80  ->  http://localhost:8081 (usuario: admin)"
}

output "password_inicial_argocd" {
  value = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "acceso_grafana" {
  value = "kubectl -n monitoring port-forward svc/kps-grafana 3000:80  ->  http://localhost:3000 (usuario: admin)"
}
