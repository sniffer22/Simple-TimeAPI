terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.47.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
  required_version = ">= 0.13"
}

provider "google" {
  project = var.project_id
  region  = var.region
}
