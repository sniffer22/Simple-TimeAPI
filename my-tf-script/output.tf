output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "api_ingress_ip" {
  value = kubernetes_ingress.api_ingress.status[0].load_balancer[0].ingress[0].ip
}

