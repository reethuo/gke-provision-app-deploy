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

# Needed to retrieve the cluster credentials
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = google_container_cluster.cluster_1.endpoint
  cluster_ca_certificate = base64decode(google_container_cluster.cluster_1.master_auth[0].cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}

provider "helm" {
  kubernetes {
    host                   = google_container_cluster.cluster_1.endpoint
    cluster_ca_certificate = base64decode(google_container_cluster.cluster_1.master_auth[0].cluster_ca_certificate)
    token                  = data.google_client_config.default.access_token
  }
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  create_namespace = true

  depends_on = [google_container_cluster.cluster_1]
}
