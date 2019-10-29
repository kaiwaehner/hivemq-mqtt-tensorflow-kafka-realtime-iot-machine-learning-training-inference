variable "node_count" {
  default = 4
}

variable "region" {
  default = "europe-west1"
}

variable "preemptible_nodes" {
  default = "false"
}

variable "daily_maintenance_window_start_time" {
  default = "02:00"
}

variable project {
  type = "string"
  description = "The name of your GCP project to use"
}

variable node_version {
  type = "string"
  default = "1.13.11-gke.9"
}