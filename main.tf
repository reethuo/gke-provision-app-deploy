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
deletion_protection=false
}


module "delegate" {
  source = "harness/harness-delegate/kubernetes"
  version = "0.2.2"

  account_id = "ucHySz2jQKKWQweZdXyCog"
  delegate_token = "NTRhYTY0Mjg3NThkNjBiNjMzNzhjOGQyNjEwOTQyZjY="
  delegate_name = "terraform-delegate-reethu"
  deploy_mode = "KUBERNETES"
  namespace = "harness-delegate-ng"
  manager_endpoint = "https://app.harness.io"
  delegate_image = "us-docker.pkg.dev/gar-prod-setup/harness-public/harness/delegate:25.05.85903"
  replicas = 1
  upgrader_enabled = true
  depends_on = [google_container_cluster.cluster_1]
}


provider "kubernetes" {
  host                   = google_container_cluster.cluster_1.endpoint
  cluster_ca_certificate = base64decode(google_container_cluster.cluster_1.master_auth[0].cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}


resource "kubernetes_namespace" "nginx" {
  metadata {
    name = "nginx"
  }
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx-deployment"
    namespace = kubernetes_namespace.nginx.metadata[0].name
    labels = {
      app = "nginx"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:latest"
          ports {
            container_port = 80
          }
        }
      }
    }
  }

  depends_on = [google_container_cluster.cluster_1]
}

resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx-service"
    namespace = kubernetes_namespace.nginx.metadata[0].name
  }

  spec {
    selector = {
      app = kubernetes_deployment.nginx.metadata[0].labels.app
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}



