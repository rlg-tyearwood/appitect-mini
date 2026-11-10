terraform {
  required_version = ">= 1.6.0"

  # S3-compatible remote state backend (Linode Object Storage, Cloudflare R2, MinIO, AWS S3).
  # Dynamic values (bucket, key, endpoints) are supplied via `terraform init -backend-config=backend.hcl`
  # locally or `-backend-config` flags in GitHub Actions.
  backend "s3" {
    region                      = "us-east-1"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }

  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
