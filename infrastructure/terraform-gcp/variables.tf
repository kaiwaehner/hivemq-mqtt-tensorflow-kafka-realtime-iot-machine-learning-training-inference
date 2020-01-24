variable "node_count" {
  default = 9
}

variable "region" {
  default = "europe-west1"
}


variable "zone" {
  default = "europe-west1-b"
}

variable "preemptible_nodes" {
  default = "false"
}

variable "daily_maintenance_window_start_time" {
  default = "02:00"
}


variable name {
  type = "string"
  default = "car-demo-cluster"
  description = "Name for the GKE cluster"
}

variable project {
  type = "string"
  description = "todo-add-your-gcp-project-name"
}

variable node_version {
  type = "string"
  default = "1.13.11-gke.9"
}