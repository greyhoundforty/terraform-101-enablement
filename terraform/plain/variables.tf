# variables.tf
# ---------------------------------------------------------------------------
# Inputs to the configuration, like function parameters in Python. A variable
# with a default is optional; terraform.tfvars (or -var on the command line)
# overrides the default. The first four are the ones shown in the deck.
# ---------------------------------------------------------------------------

variable "region" {
  description = "IBM Cloud region to deploy into."
  type        = string
  default     = "us-south"
}

variable "project_name" {
  description = "Project name. Leave empty to get a generated one."
  type        = string
  default     = ""
  nullable    = false # passing null is treated as "" instead of erroring
}

variable "vsi_profile" {
  description = "Server size. bx2-* are the balanced profiles (bx2-2x8 = 2 vCPU/8 GiB, bx2-4x16 = 4 vCPU/16 GiB)."
  type        = string
  default     = "bx2-2x8"

  validation {
    # The rule lives next to the variable, so a bad value stops the run
    # immediately, before anything is planned or built.
    condition     = startswith(var.vsi_profile, "bx2-")
    error_message = "Use a bx2 profile."
  }
}

# --- Settings for the existing things we look up and the firewall ------------

variable "resource_group_name" {
  description = "Name of an EXISTING resource group. Terraform looks it up; it does not create it."
  type        = string
  default     = "Default"
}

variable "ssh_key_name" {
  description = "Name of an SSH key that ALREADY exists in IBM Cloud, in the same region. No default on purpose."
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "Who may SSH in, as a CIDR. Use your own IP, e.g. 203.0.113.7/32. No default on purpose."
  type        = string

  validation {
    # can() turns an error into false, so a bad CIDR gives our message instead of a stack trace.
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0))
    error_message = "ssh_allowed_cidr must be a CIDR such as 203.0.113.7/32. Edit terraform.tfvars."
  }
}

variable "instance_count" {
  description = "How many servers to create."
  type        = number
  default     = 2
}

variable "subnet_ip_count" {
  description = "How many IP addresses the subnet needs (a power of two). IBM Cloud picks the actual range for you."
  type        = number
  default     = 256

  validation {
    condition     = contains([8, 16, 32, 64, 128, 256, 512, 1024], var.subnet_ip_count)
    error_message = "subnet_ip_count must be a power of two between 8 and 1024."
  }
}

variable "ubuntu_version" {
  description = "Ubuntu release to use, written the way IBM names images (24-04 or 22-04)."
  type        = string
  default     = "24-04"
}

variable "enable_floating_ip" {
  description = "Give each server a public IP so you can SSH to it."
  type        = bool
  default     = true
}

variable "owner_tag" {
  description = "Project owner"
  type        = string
}
