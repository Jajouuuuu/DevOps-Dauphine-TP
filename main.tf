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

