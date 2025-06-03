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
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = google_container_cluster.cluster_1.endpoint
    cluster_ca_certificate = base64decode(google_container_cluster.cluster_1.master_auth[0].cluster_ca_certificate)
    token                  = data.google_client_config.default.access_token
    load_config_file       = false
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
resource "helm_release" "prometheus_operator" {
  name             = "prometheus-operator"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "58.1.0" # Optional: stable version

  values = [
    file("${path.module}/prometheus-values.yaml")
  ]

  depends_on = [google_container_cluster.cluster_1]
}
