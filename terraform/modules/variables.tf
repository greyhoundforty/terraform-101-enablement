# variables.tf
# ---------------------------------------------------------------------------
# Inputs to the configuration, like function parameters in Python. Defaults
# are used unless terraform.tfvars (or -var on the CLI) overrides them.
# ---------------------------------------------------------------------------

variable "workspace_targets" {
  description = <<-EOT
    Which region and zone each Terraform WORKSPACE deploys to. A workspace is a
    separate copy of the state, so the same code can be applied once per region.
    Create one with `terraform workspace new eu-de`; the name must be a key here.
  EOT
  type = map(object({
    region = string
    zone   = string
  }))
  default = {
    default = { region = "us-south", zone = "us-south-1" }
    eu-de   = { region = "eu-de", zone = "eu-de-1" }
    jp-tok  = { region = "jp-tok", zone = "jp-tok-1" }
  }
}

variable "resource_group_name" {
  description = "Name of an EXISTING resource group. Terraform looks it up; it does not create it."
  type        = string
  default     = "Default"
}

variable "vsi_profile" {
  description = "Server size. bx2-* are the balanced profiles (bx2-2x8 = 2 vCPU/8 GiB, bx2-4x16 = 4 vCPU/16 GiB)."
  type        = string
  default     = "bx2-2x8"

  validation {
    condition     = startswith(var.vsi_profile, "bx2-")
    error_message = "Use a bx2 profile."
  }
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

variable "instance_count" {
  description = "How many servers to create in the subnet."
  type        = number
  default     = 2
}

variable "ubuntu_version" {
  description = "Ubuntu release to use, written the way IBM names images (24-04 or 22-04)."
  type        = string
  default     = "24-04"
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

variable "enable_floating_ip" {
  description = "Give each server a public IP so you can SSH to it."
  type        = bool
  default     = true
}

variable "project_prefix" {
  description = <<-EOT
    Optional name prefix for every resource (for example "acme-poc").
    Leave empty and a random 6-letter prefix is generated instead.
    Lowercase letters, numbers and hyphens; must start with a letter; 2-20 characters.
  EOT
  type        = string
  default     = ""

  validation {
    # An empty string is allowed (= use the random prefix). Otherwise the value
    # must match the pattern. can() turns a regex failure into false, so the
    # message below is shown instead of a stack trace.
    condition     = var.project_prefix == "" || can(regex("^[a-z][a-z0-9-]{0,18}[a-z0-9]$", var.project_prefix))
    error_message = "project_prefix must be 2-20 characters: lowercase letters, numbers and hyphens, starting with a letter and not ending with a hyphen."
  }
}

variable "existing_ssh_key" {
  description = "Name of an SSH key that already exists in IBM Cloud. Leave empty to generate a new key pair."
  type        = string
  default     = ""
}
