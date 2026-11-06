# versions.tf
# ---------------------------------------------------------------------------
# Pins the tools Terraform needs, so everyone who clones this repo gets the
# same behaviour. Think of it like requirements.txt in Python.
# ---------------------------------------------------------------------------
terraform {
  # Terraform CLI version this code was written against.
  required_version = ">= 1.9.0"

  required_providers {
    # A "provider" is the plugin that talks to a cloud's API. Terraform
    # downloads it on `terraform init`.
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "~> 2.8" # any 2.x release from 2.8 up, but not 3.0
    }
    random = {
      source  = "hashicorp/random" # random_string.prefix
      version = "~> 3.6"           # any 3.x release from 3.6 up, but not 4.0
    }
    tls = {
      source  = "hashicorp/tls" # tls_private_key.ssh
      version = "~> 4.0"        # any 4.x release, but not 5.0
    }
  }
}

# The provider reads your API key from the environment (IC_API_KEY or
# IBMCLOUD_API_KEY), so no secret ever appears in the code.
# The region is picked from the active workspace (see locals.tf), so
# `terraform workspace select eu-de` is all it takes to target another region.
provider "ibm" {
  region = local.region
}
