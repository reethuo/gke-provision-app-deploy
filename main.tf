terraform {
  required_providers {
    null = {
      source  = "hashicorp/null" 
      version = "~> 3.2" #ensures that Terraform uses version ~> 3.2
    }
  }
}
provider "google" {
  project = "static-epigram-458808-h4"
  region  = "us-west1"
  zone    = "us-west1-c"
}

data "google_client_config" "default" {} #✅ Purpose
#This is a Terraform data source from the google provider that fetches information about the currently authenticated Google Cloud client used by Terraform. It's especially useful when you need details like:
#Project,Region/Zone,Access token and Account being used
#This is useful in dynamic environments where you want Terraform to adapt to the current GCP configuration((for example, based on gcloud auth login).

resource "google_container_cluster" "cluster_1" {
  name     = "cluster-1"
  location = "us-west1-c"

  release_channel {      #🎯 Purpose
    channel = "REGULAR"  #release_channel block tells GKE how often your cluster should get Kubernetes and node updates.
  }                      #Choosing REGULAR helps you stay reasonably up-to-date without risking the instability of very new versions.

  initial_node_count = 2

  node_config {
    machine_type = "e2-standard-2"
    image_type   = "COS_CONTAINERD" #COS stands for Container-Optimized OS, a lightweight, secure OS maintained by Google, specifically designed for running containers.
    disk_size_gb = 20 #CONTAINERD indicates that the node will use containerd as the container runtime (instead of the older docker runtime).
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


provider "kubernetes" { #This Terraform block defines the Kubernetes provider configuration and enables Terraform to interact with your Google Kubernetes Engine (GKE) cluster. 
  host                   = "https://${google_container_cluster.cluster_1.endpoint}"
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
          port {
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


resource "helm_release" "prometheus_operator" { #To deploy Prometheus, Alertmanager, Grafana, and supporting components into the Kubernetes cluster via Helm, with custom configuration, managed by Terraform.
  name       = "kube-prometheus-stack"
  chart      = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  namespace  = "monitoring"
  create_namespace = true
  values     = [file("${path.module}/prometheus-values.yaml")]
  depends_on = [google_container_cluster.cluster_1]

  set {
    name  = "defaultRules.create"
    value = "true"
  }

  set {
    name  = "alertmanager.config"
    value = file("${path.module}/alertmanager-config.yaml")
  }
}


provider "helm" { #It allows Terraform to run Helm commands (like installing charts) against your Kubernetes cluster, by setting up authentication and cluster access.
  kubernetes {
    host                   = "https://${google_container_cluster.cluster_1.endpoint}"
    cluster_ca_certificate = base64decode(google_container_cluster.cluster_1.master_auth[0].cluster_ca_certificate)
    token                  = data.google_client_config.default.access_token
  }
}


locals {
  auth_string  = base64encode("${var.docker_username}:${var.docker_password}")
  registry_url = "https://trialq2a49v.jfrog.io"

  dockerconfigjson = templatefile("${path.module}/dockerconfig.tpl.json", {
    registry_url = local.registry_url,
    auth_string  = local.auth_string
  })
}

resource "kubernetes_namespace" "hello" {
  metadata {
    name = "hello"
  }
}


resource "helm_release" "hello_world" {
  name             = "hello-world"
  chart            = "./hello-world"
  namespace        = "hello"
  create_namespace = true

  values = [file("${path.module}/hello-values.yaml")]
  depends_on = [
    helm_release.prometheus_operator,     # ← Wait until Prometheus is installed
    kubernetes_namespace.hello,  # ← Wait for namespace to exist
    google_container_cluster.cluster_1
  ]
}



resource "kubernetes_secret" "regcred" {
  metadata {
    name      = "regcred"
    namespace = kubernetes_namespace.hello.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = local.dockerconfigjson
  }

  depends_on = [kubernetes_namespace.hello]
}


resource "kubernetes_secret" "prometheus_remote_write_auth" {
  metadata {
    name      = "prometheus-remote-write-auth"
    namespace = "monitoring"
  }

  type = "Opaque"

  data = {
    username = "2478155"
    password = "glc_eyJvIjoiMTQ0NzM3NiIsIm4iOiJzdGFjay0xMjc2OTYwLWhtLXJlYWQtbWV0cmljcy1wcm9tIiwiayI6InIwNmZwcFlxaTA3MXc4Y3E4N3FFWjBXMCIsIm0iOnsiciI6InByb2QtYXAtc291dGgtMSJ9fQ=="
  }

  depends_on = [helm_release.prometheus_operator]
}



