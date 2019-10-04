variable "node_count" {
  default = 10
}

variable "region" {
  default = "europe-west1"
}

variable "zone1" {
  default = "europe-west1-b"
}


variable "preemptible_nodes" {
  default = "true"
}

variable "replicas" {
  default = "1"
}


variable project {
  type = "string"
  description = "The name of your GCP project to use"
}