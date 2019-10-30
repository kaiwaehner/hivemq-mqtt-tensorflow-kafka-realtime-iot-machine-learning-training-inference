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
  description = "todo-add-your-project-name-here"
}