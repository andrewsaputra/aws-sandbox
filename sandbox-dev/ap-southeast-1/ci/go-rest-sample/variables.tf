variable "stack_identifier" {
  type = string
}

variable "repository_url" {
  type = string
}

variable "log_retention_days" {
  type = number
}

variable "codebuild_specs" {
  type = object({
    compute_type    = string
    image           = string
    container       = string
    privileged_mode = bool
  })
}

variable "remote_state_backend" {
  type = string
}

variable "remote_state_bucket" {
  type = string
}

variable "remote_state_region" {
  type = string
}

variable "remote_state_key_global_cicd" {
  type = string
}