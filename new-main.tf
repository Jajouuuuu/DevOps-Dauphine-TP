terraform {
  backend "gcs" {
    bucket  = "terraform-devops-tp-eval"
    prefix  = "terraform/state"
  }

  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "google" {
  project = "devops-tp-eval"
  region  = "us-central1"
}

# Enable required Google APIs
resource "google_project_service" "gke_api" {
  project = "devops-tp-eval"
  service = "container.googleapis.com"
  disable_on_destroy = false
}

# Create GKE cluster
resource "google_container_cluster" "primary" {
  name     = "gke-dauphine"
  location = "us-central1-a"
  
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  depends_on = [google_project_service.gke_api]
}

# Create node pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-node-pool"
  location   = "us-central1-a"
  cluster    = google_container_cluster.primary.name
  
  node_count = 2

  node_config {
    machine_type = "e2-medium"
    
    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append"
    ]
  }
}

# Get GKE cluster info
data "google_client_config" "default" {}

# Configure kubernetes provider with GKE cluster access
provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

# Storage Class for MySQL
resource "kubernetes_storage_class" "mysql_storage" {
  metadata {
    name = "mysql-storage"
  }
  storage_provisioner = "kubernetes.io/gce-pd"
  parameters = {
    type = "pd-standard"
  }
}

# MySQL StatefulSet
resource "kubernetes_stateful_set" "mysql" {
  metadata {
    name = "mysql"
  }

  spec {
    service_name = "mysql"
    replicas = 1

    selector {
      match_labels = {
        app = "mysql"
      }
    }

    template {
      metadata {
        labels = {
          app = "mysql"
        }
      }

      spec {
        container {
          name  = "mysql"
          image = "mysql:5.7"  # Using 5.7 for better compatibility

          env {
            name  = "MYSQL_ROOT_PASSWORD"
            value = "ilovedevops"
          }
          env {
            name  = "MYSQL_DATABASE"
            value = "wordpress"
          }
          env {
            name  = "MYSQL_USER"
            value = "wordpress"
          }
          env {
            name  = "MYSQL_PASSWORD"
            value = "ilovedevops"
          }

          port {
            container_port = 3306
            name = "mysql"
          }

          volume_mount {
            name       = "mysql-persistent-storage"
            mount_path = "/var/lib/mysql"
          }

          resources {
            limits = {
              memory = "512Mi"
              cpu    = "0.5"
            }
            requests = {
              memory = "256Mi"
              cpu    = "0.25"
            }
          }

          liveness_probe {
            tcp_socket {
              port = 3306
            }
            initial_delay_seconds = 30
            period_seconds = 10
          }

          readiness_probe {
            tcp_socket {
              port = 3306
            }
            initial_delay_seconds = 5
            period_seconds = 2
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "mysql-persistent-storage"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        storage_class_name = kubernetes_storage_class.mysql_storage.metadata[0].name
        resources {
          requests = {
            storage = "10Gi"
          }
        }
      }
    }
  }

  depends_on = [
    google_container_node_pool.primary_nodes,
    kubernetes_storage_class.mysql_storage
  ]
}

# MySQL Service
resource "kubernetes_service" "mysql" {
  metadata {
    name = "mysql"
  }

  spec {
    selector = {
      app = "mysql"
    }

    port {
      port        = 3306
      target_port = 3306
    }

    cluster_ip = "None"  # Headless service
  }
}

# WordPress Deployment
resource "kubernetes_deployment" "wordpress" {
  metadata {
    name = "wordpress"
  }

  spec {
    replicas = 1  # Starting with 1 replica for initial setup

    selector {
      match_labels = {
        app = "wordpress"
      }
    }

    template {
      metadata {
        labels = {
          app = "wordpress"
        }
      }

      spec {
        container {
          name  = "wordpress"
          image = "wordpress:5.8-apache"  # Using specific version

          env {
            name  = "WORDPRESS_DB_HOST"
            value = "mysql:3306"
          }
          env {
            name  = "WORDPRESS_DB_USER"
            value = "wordpress"
          }
          env {
            name  = "WORDPRESS_DB_PASSWORD"
            value = "ilovedevops"
          }
          env {
            name  = "WORDPRESS_DB_NAME"
            value = "wordpress"
          }

          port {
            container_port = 80
            name = "wordpress"
          }

          resources {
            limits = {
              memory = "512Mi"
              cpu    = "0.5"
            }
            requests = {
              memory = "256Mi"
              cpu    = "0.25"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 30
            period_seconds = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds = 2
          }
        }
      }
    }
  }

  depends_on = [kubernetes_stateful_set.mysql]
}

# WordPress Service
resource "kubernetes_service" "wordpress" {
  metadata {
    name = "wordpress"
  }

  spec {
    selector = {
      app = "wordpress"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}