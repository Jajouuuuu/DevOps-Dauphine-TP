terraform {
  backend "gcs" {
    bucket  = "terraform-devops-tp-eval"
    prefix  = "terraform/state"
  }
}

provider "google" {
  project = "devops-tp-eval"
  region  = "us-central1"
}

# On crée le dépot Artifact Registry
resource "google_artifact_registry_repository" "website_tools" {
  location      = "us-central1"
  repository_id = "website-tools"
  format        = "DOCKER"
}

# On active les APIs nécessaires
resource "google_project_service" "enable_services" {
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "artifactregistry.googleapis.com",
    "sqladmin.googleapis.com",
    "cloudbuild.googleapis.com"
  ])
  service = each.value
}

# On gère la db wordpress
resource "google_sql_database" "wordpress" {
  name     = "wordpress"
  instance = "main-instance" 
  charset  = "utf8"
  collation = "utf8_general_ci"
}

resource "google_sql_user" "wordpress" {
  name     = "wordpress"
  instance = "main-instance"
  password = "ilovedevops"
}

resource "google_cloud_run_service" "default" {
  name     = "serveur-wordpress"
  location = "us-central1"

  template {
    spec {
      containers {
        image = "us-central1-docker.pkg.dev/devops-tp-eval/website-tools/wordpress:latest"
        ports {
          container_port = 80
        }
      }
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"      = "1000"
        "run.googleapis.com/cloudsql-instances" = "devops-tp-eval:us-central1:main-instance"
        "run.googleapis.com/client-name"        = "terraform"
        "run.googleapis.com/port"               = "8080"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

data "google_iam_policy" "noauth" {
   binding {
      role = "roles/run.invoker"
      members = [
         "allUsers",
      ]
   }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
   location    = google_cloud_run_service.default.location 
   project     = google_cloud_run_service.default.project 
   service     = google_cloud_run_service.default.name 

   policy_data = data.google_iam_policy.noauth.policy_data
}