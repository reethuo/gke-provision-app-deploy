provider "google" {
  project = "static-epigram-458808-h4"
  region  = "us-west1"
  zone    = "us-west1-c"
}
resource "google_container_cluster" "cluster_1" {
  name     = "cluster-1"
  location = "us-west1-c"
  release_channel {
    channel = "REGULAR"
  }
  initial_node_count = 2
  node_config {
    machine_type = "e2-standard-2"
    image_type   = "COS_CONTAINERD"
    disk_size_gb = 20
  }
}
