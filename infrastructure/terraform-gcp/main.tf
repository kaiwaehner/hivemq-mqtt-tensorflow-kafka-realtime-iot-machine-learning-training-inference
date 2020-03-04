provider "google" {
  credentials = file("account.json")
  project = var.project
  region = var.region
  version = "3.5.0"
}

resource "google_container_cluster" "cluster" {
  timeouts {
    delete = "120m"
  }

  name = var.name
  location = var.region

  remove_default_node_pool = true
  initial_node_count = 1

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }

  /* Calico might be an option for improved ingress performance if we connect MQTT clients from the edge, currently not the case

  network_policy {
    enabled = true
    provider = "CALICO"
  }

  addons_config {
    network_policy_config {
      disabled = false
    }
  }*/
}

resource "google_container_node_pool" "primary_nodes" {
  name = "car-demo-node-pool-${var.name}"
  location = var.region

  cluster = google_container_cluster.cluster.name
  node_count = var.node_count
  //version = var.node_version
  node_config {
    // We use preemptible nodes because they're cheap (for testing purposes). Set this to false if you want consistent performance.
    preemptible = var.preemptible_nodes
    machine_type = "n1-standard-8"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }

  autoscaling {
    max_node_count = var.node_count
    min_node_count = 1
  }

  management {
    auto_upgrade = false
  }
}

resource "null_resource" "setup-cluster" {
  depends_on = [
    google_container_cluster.cluster
  ]
  triggers = {
    id = google_container_cluster.cluster.id
    reg = var.region
    prj = var.project
    // Re-run script on deployment script changes
    script = sha1(file("00_setup_GKE.sh"))
  }

  provisioner "local-exec" {
    command = "./00_setup_GKE.sh ${google_container_cluster.cluster.name} ${var.region} ${var.project}"
  }
}

resource "null_resource" "setup-messaging" {
  depends_on = [
    null_resource.setup-cluster
  ]

  provisioner "local-exec" {
    command = "../confluent/01_installConfluentPlatform.sh"
  }

  provisioner "local-exec" {
    environment = {
      SA_KEY = google_service_account_key.storage-key.private_key
    }

    command = "../hivemq/setup_evaluation.sh"
  }

  provisioner "local-exec" {
    command = "./destroy.sh"
    when = "destroy"
  }
}

# Object storage for model updates

resource "google_service_account" "storage-account" {
  account_id = "car-demo-storage-account"
  display_name = "car-demo-storage-account-${var.name}"
}

resource "google_storage_bucket" "model-bucket" {
  name = "tf-models_${var.project}_${var.name}"
  location = "EU"
  force_destroy = true
}

resource "google_storage_bucket_iam_binding" "model-bucket-access" {
  depends_on = [
    google_service_account.storage-account,
    google_storage_bucket.model-bucket
  ]

  bucket = google_storage_bucket.model-bucket.name

  members = [
    "serviceAccount:${google_service_account.storage-account.email}"
  ]
  role = "roles/storage.objectAdmin"
}


resource "google_storage_bucket_iam_binding" "storage-account-access2" {
  depends_on = [
    google_service_account.storage-account,
    google_storage_bucket.model-bucket
  ]

  bucket = google_storage_bucket.model-bucket.name

  members = [
    "serviceAccount:${google_service_account.storage-account.email}"
  ]

  role = "roles/storage.legacyBucketWriter"
}
resource "google_service_account_key" "storage-key" {
  depends_on = [
    google_service_account.storage-account]
  service_account_id = google_service_account.storage-account.name
}