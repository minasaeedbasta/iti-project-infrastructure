# GKE service account
resource "google_service_account" "custom_service_account" {
  account_id   = "jenkins"
  display_name = "GKE Custom Service Account"
}

# assign roles to service account
resource "google_project_iam_member" "container_admin_binding" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.custom_service_account.email}"
}

# Get all zones available in the region 
data "google_compute_zones" "available_zones" {
  region = var.region
}

# My public IP
data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

# GKE cluster
resource "google_container_cluster" "primary" {
  name     = "${var.project_id}-gke"
  location =  data.google_compute_zones.available_zones.names[0]    #var.region
  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
  initial_node_count = 1

  # Private Cluster Configuration
  private_cluster_config {
    # enable_private_endpoint = true
    enable_private_nodes   = true 
    master_ipv4_cidr_block = "10.13.0.0/28"
  }
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "10.11.0.0/21"
    services_ipv4_cidr_block = "10.12.0.0/21"
  }
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "${chomp(data.http.myip.response_body)}/32"
      display_name = "net1"
    }
  }

  # Enable Workload Identity
  workload_identity_config {
    workload_pool  = "${var.project_id}.svc.id.goog"
  }

  # cluster nodes configurations
  node_config {
    preemptible  = true
    machine_type = "e2-small"
    disk_size_gb = 30
    tags         = ["gke-node", "${var.project_id}-gke"]
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}