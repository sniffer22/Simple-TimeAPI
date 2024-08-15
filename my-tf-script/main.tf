###########################################################################
//IAM Roles and Policies
###########################################################################
resource "google_project_iam_member" "cluster_admin" {
  project = var.project_id
  role    = "roles/container.clusterAdmin"
  member  = "user:your-email@example.com"
}
###########################################################################
// VPC and Subnets
###########################################################################

resource "google_compute_network" "vpc_network" {
  name = var.vpc_name
}

resource "google_compute_subnetwork" "subnet" {
  name          = "simple-api-subnet"
  network       = google_compute_network.vpc_network.id
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
}
###########################################################################
// Setting Up a NAT Gateway
###########################################################################
resource "google_compute_router" "nat_router" {
  name    = "simple-api-nat-router"
  network = google_compute_network.vpc_network.id
  region  = var.region
}

resource "google_compute_router_nat" "nat_config" {
  name                         = "simple-api-nat-config"
  router                       = google_compute_router.nat_router.name
  region                       = var.region
  nat_ip_allocate_option       = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

#############################################################################
//Fire Rules
#############################################################################
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  source_ranges = ["10.0.0.0/16"]
  direction     = "INGRESS"
  target_tags   = ["gke-cluster"]
}

resource "google_compute_firewall" "allow_external" {
  name    = "allow-external"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
  target_tags   = ["gke-cluster"]
}

resource "google_compute_firewall" "allow_health_check" {
  name    = "allow-health-check"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  allow {
    protocol = "tcp"
    ports    = ["10256"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16", "0.0.0.0/0"]
  direction     = "INGRESS"
  target_tags   = ["gke-cluster"]
}

#############################################################################
// GKE Cluster
#############################################################################
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  network    = google_compute_network.vpc_network.name
  subnetwork = google_compute_subnetwork.subnet.name
}
############################################################################
//Deploy Kubernetes Resources
############################################################################
resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = "prod-namespace"
  }
}

resource "kubernetes_deployment" "api_deployment" {
  metadata {
    name      = "api-deployment"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "api"
      }
    }

    template {
      metadata {
        labels = {
          app = "api"
        }
      }

      spec {
        container {
          name  = "api"
          image = "gcr.io/${var.project_id}/api-image:latest"

          port {
            container_port = 8080
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "api_service" {
  metadata {
    name      = "api-service"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }

  spec {
    selector = {
      app = "api"
    }

    port {
      port        = 80
      target_port = 8080
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_ingress" "api_ingress" {
  metadata {
    name      = "api-ingress"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }

  spec {
    backend {
      service_name = kubernetes_service.api_service.metadata[0].name
      service_port = 80
    }
  }
}
