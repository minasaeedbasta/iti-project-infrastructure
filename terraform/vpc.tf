variable "project_id" {
  description = "project id"
}

variable "region" {
  description = "region"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# VPC
resource "google_compute_network" "vpc" {
  name                    = "${var.project_id}-vpc"
  auto_create_subnetworks = "false"
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.project_id}-subnet"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.0.0.0/24"
}

# create cloud router for nat gateway
resource "google_compute_router" "router" {
  name    = "nat-router"
  project = var.project_id
  network = google_compute_network.vpc.name
  region  = var.region
}

# Create Nat Gateway
resource "google_compute_router_nat" "nat" {
  name                               = "my-router-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall Rule
resource "google_compute_firewall" "rules" {
  project     = var.project_id
  name        = "jenkins-rule"
  network     = google_compute_network.vpc.name
  description = "Allow ssh protocol"

  allow {
    protocol  = "tcp"
    ports     = ["22"]
  }
  source_ranges = [ "0.0.0.0/0" ]
}