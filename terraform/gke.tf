# GKE service account
resource "google_service_account" "custom_service_account" {
  account_id   = "jenkins-deployer"
  display_name = "GKE Custom Service Account"
}

#GKE service account key
# resource "google_service_account_key" "mykey" {
#   service_account_id = google_service_account.custom_service_account.name
#   public_key_type    = "TYPE_X509_PEM_FILE"
# }

# module "my-app-workload-identity" {
#   source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
#   use_existing_gcp_sa = true
#   name                = google_service_account.custom_service_account.account_id
#   project_id          = var.project_id

#   # wait for the custom GSA to be created to force module data source read during apply
#   # https://github.com/terraform-google-modules/terraform-google-kubernetes-engine/issues/1059
#   depends_on = [google_service_account.custom_service_account]
# }


# GKE cluster
resource "google_container_cluster" "primary" {
  name     = "${var.project_id}-gke"
  location = "us-central1-a"#var.region
  
  remove_default_node_pool = true
  initial_node_count       = 1

  # Enable Workload Identity
  workload_identity_config {
    workload_pool  = "${var.project_id}.svc.id.goog"
  }
  
  
  node_config {
    preemptible  = true
    machine_type = "e2-small"
    disk_size_gb = 30
    tags         = ["gke-node", "${var.project_id}-gke"]
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
}

# Separately Managed Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = google_container_cluster.primary.name
  location   = "us-central1-a"#var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1
  
  node_config {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.custom_service_account.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      env = var.project_id
    }

    preemptible  = true
    machine_type = "e2-small"
    disk_size_gb = 30
    tags         = ["gke-node", "${var.project_id}-gke"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}