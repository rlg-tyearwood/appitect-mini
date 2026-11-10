variable "linode_token" {
  description = "Linode APIv4 Personal Access Token (optional if the LINODE_TOKEN environment variable is set)."
  type        = string
  default     = null
  sensitive   = true
}

variable "cluster_name" {
  description = "Short lowercase identifier for this shared hosting VPS (e.g. 'shared-01', 'mini-us-east')."
  type        = string
  default     = "shared-01"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.cluster_name))
    error_message = "cluster_name must be 2-20 lowercase alphanumeric characters or hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment name (e.g. 'production', 'staging')."
  type        = string
  default     = "production"
}

variable "linode_region" {
  description = "Linode datacenter region (e.g. 'us-east', 'us-mia', 'eu-central')."
  type        = string
  default     = "us-east"
}

variable "vps_type" {
  description = "Linode instance plan ID for the shared multi-app VPS (e.g. 'g6-standard-2' for 4GB RAM or 'g6-standard-4' for 8GB RAM)."
  type        = string
  default     = "g6-standard-2"
}

variable "vps_image" {
  description = "Linode OS image ID. Must support cloud-init via Linode Metadata."
  type        = string
  default     = "linode/ubuntu24.04"
}

variable "backups_enabled" {
  description = "Enable Linode automated daily/weekly VPS backups."
  type        = bool
  default     = true
}

variable "swap_size_gb" {
  description = "Swap file size in GiB provisioned on the shared VPS to absorb multi-application memory spikes without OOM kills (0 to disable)."
  type        = number
  default     = 4

  validation {
    condition     = var.swap_size_gb >= 0 && var.swap_size_gb <= 16
    error_message = "swap_size_gb must be between 0 and 16."
  }
}

variable "ssh_public_key" {
  description = "OpenSSH public key injected for both root and the 'deploy' CI/CD user."
  type        = string
}

variable "ssh_allowed_ipv4" {
  description = "IPv4 CIDR blocks permitted to reach SSH port 22 through the Linode Cloud Firewall."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_allowed_ipv6" {
  description = "IPv6 CIDR blocks permitted to reach SSH port 22 through the Linode Cloud Firewall."
  type        = list(string)
  default     = ["::/0"]
}

variable "rlg_support_email" {
  description = "RLG Support Email address used by Caddy for Let's Encrypt ACME TLS certificate notifications across all hosted tenant domains."
  type        = string
}

variable "hosted_apps" {
  description = "Map of low-usage tenant applications hosted on this shared VPS, keyed by app_slug."
  type = map(object({
    domain             = string
    upstream_container = string
    upstream_port      = optional(number, 3000)
    waf_mode           = optional(string, "On")
    max_body_mb        = optional(number, 10)
  }))
  default = {}

  validation {
    condition = alltrue([
      for slug, app in var.hosted_apps :
      can(regex("^[a-z][a-z0-9-]{1,19}$", slug)) && contains(["On", "DetectionOnly"], app.waf_mode)
    ])
    error_message = "Each hosted_apps key must be 2-20 lowercase alphanumeric/hyphen chars starting with a letter, and waf_mode must be 'On' or 'DetectionOnly'."
  }
}

variable "panel_port" {
  description = "Internal host port for the 1Panel management UI (not opened on the public firewall by default)."
  type        = number
  default     = 10086
}

variable "panel_username" {
  description = "Administrator username for 1Panel."
  type        = string
  default     = "paneladmin"
}

variable "panel_password" {
  description = "Administrator password for 1Panel. Leave empty to generate a strong random password automatically."
  type        = string
  default     = ""
  sensitive   = true
}

variable "panel_entrance" {
  description = "Secret URL path entrance for 1Panel. Leave empty to generate a random 12-character slug automatically."
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_panel_subdomain" {
  description = "Expose 1Panel over HTTPS via Caddy on var.panel_domain (otherwise access securely via SSH port forwarding)."
  type        = bool
  default     = false
}

variable "panel_domain" {
  description = "Subdomain FQDN for 1Panel when enable_panel_subdomain is true (e.g. 'panel.shared.yourdomain.com')."
  type        = string
  default     = ""
}

variable "enable_shared_managed_postgres" {
  description = "Provision a shared Linode Managed PostgreSQL cluster in the same region (use scripts/create-tenant-db.sh to create isolated DBs/roles per app)."
  type        = bool
  default     = false
}

variable "postgres_engine_id" {
  description = "Linode Managed PostgreSQL engine ID (format: 'postgresql/<major_version>')."
  type        = string
  default     = "postgresql/16"
}

variable "postgres_node_type" {
  description = "Linode plan ID for Managed PostgreSQL nodes (e.g. 'g6-nanode-1', 'g6-standard-1')."
  type        = string
  default     = "g6-nanode-1"
}

variable "postgres_cluster_size" {
  description = "Number of nodes in the shared Managed PostgreSQL cluster (1 for standalone, 3 for High Availability)."
  type        = number
  default     = 1

  validation {
    condition     = contains([1, 3], var.postgres_cluster_size)
    error_message = "postgres_cluster_size must be 1 or 3."
  }
}

variable "postgres_extra_allow_cidrs" {
  description = "Optional extra IPv4/IPv6 CIDR blocks allowed to connect to the shared Managed PostgreSQL cluster."
  type        = list(string)
  default     = []
}
