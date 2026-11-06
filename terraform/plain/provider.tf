# provider.tf
# ---------------------------------------------------------------------------
# Tells the IBM provider which region to work in. The API key is NOT here: the
# provider reads it from the IC_API_KEY environment variable, so no secret
# ever appears in the code (run Terraform with `fnox exec -- ...`).
# ---------------------------------------------------------------------------
provider "ibm" {
  region = var.region
}
