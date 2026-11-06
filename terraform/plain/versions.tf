# versions.tf
# ---------------------------------------------------------------------------
# Pins the tools Terraform needs, so everyone who clones this repo gets the
# same behaviour. Think of it like requirements.txt in Python.
# ---------------------------------------------------------------------------
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    # A "provider" is the plugin that talks to a cloud's API. Terraform
    # downloads it when you run `terraform init`.
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "~> 2.8" # any 2.x release from 2.8 up, but not 3.0
    }

    # Makes the short random project name (random_string.prefix in main.tf).
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6" # any 3.x release from 3.6 up, but not 4.0
    }
  }
}
