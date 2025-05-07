
variable "project_id" {
  default = "your-project-id"
}
variable "region" {
  default =  "gcp-region"
}
variable "zone" {
  default = "gcp-zone"
}
variable "worker_join_token" {
  description = "Docker Swarm Worker join token"
  type        = string
}
