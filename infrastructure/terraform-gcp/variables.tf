variable "node_count" {
  default = 3
}

variable "region" {
  default = "europe-west1"
}

variable "zone" {
  default = "europe-west1-c"
}

variable "preemptible_nodes" {
  default = "true"
}

variable project {
  type = "string"
  description = "The name of your GCP project to use"
}