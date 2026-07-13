resource "google_artifact_registry_repository" "images" {
  location      = var.region
  repository_id = "taskflow"
  description   = "Container images for the taskflow-api sample app"
  format        = "DOCKER"

  labels = local.labels

  depends_on = [google_project_service.apis]
}

data "google_project" "current" {
  project_id = var.project_id
}

# GKE Autopilot nodes pull images as the default Compute Engine service account;
# grant it read access so pods can actually pull from this repo.
resource "google_artifact_registry_repository_iam_member" "gke_node_pull" {
  location   = google_artifact_registry_repository.images.location
  repository = google_artifact_registry_repository.images.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}
