output "vps_id" {
  description = "Linode instance ID of the shared multi-tenant VPS."
  value       = linode_instance.vps.id
}

output "vps_public_ipv4" {
  description = "Primary public IPv4 address of the shared VPS (point all hosted app DNS A records here)."
  value       = local.public_ipv4
}

output "vps_public_ipv6" {
  description = "Public IPv6 address of the shared VPS (point all hosted app DNS AAAA records here)."
  value       = local.public_ipv6
}

output "ssh_deploy_command" {
  description = "SSH command to connect as the hardened 'deploy' user."
  value       = "ssh deploy@${local.public_ipv4}"
}

output "hosted_tenant_topology" {
  description = "Deployment directory, public domain, and isolated internal Docker network for each configured tenant app."
  value = {
    for slug, app in var.hosted_apps : slug => {
      domain             = app.domain
      deploy_directory   = "/opt/apps/${slug}"
      edge_network       = "vps_edge"
      internal_network   = local.tenant_networks[slug]
      upstream_container = "${app.upstream_container}:${app.upstream_port}"
      waf_mode           = app.waf_mode
    }
  }
}

output "rendered_caddyfile" {
  description = "Rendered global Caddyfile for Day-2 sync via scripts/sync-tenants.sh."
  value       = local.rendered_caddyfile
}

output "rendered_tenant_sites" {
  description = "Map of rendered per-tenant Caddy + Coraza WAF site files for Day-2 sync via scripts/sync-tenants.sh."
  value       = local.rendered_tenant_sites
}

output "onepanel_ssh_tunnel_command" {
  description = "SSH local port-forwarding command to securely access the 1Panel Web UI."
  value       = "ssh -L ${var.panel_port}:127.0.0.1:${var.panel_port} deploy@${local.public_ipv4}"
}

output "onepanel_credentials" {
  description = "1Panel login URL, username, password, and security entrance slug."
  sensitive   = true
  value = {
    local_tunnel_url = "http://localhost:${var.panel_port}/${local.effective_panel_slug}"
    subdomain_url    = var.enable_panel_subdomain && var.panel_domain != "" ? "https://${var.panel_domain}/${local.effective_panel_slug}" : null
    username         = var.panel_username
    password         = local.effective_panel_pass
    entrance         = local.effective_panel_slug
  }
}

output "shared_managed_postgres" {
  description = "Admin connection details for the shared Linode Managed PostgreSQL cluster (pass connection_uri to scripts/create-tenant-db.sh)."
  sensitive   = true
  value = var.enable_shared_managed_postgres ? {
    id             = linode_database_postgresql_v2.shared_db[0].id
    host_primary   = linode_database_postgresql_v2.shared_db[0].host_primary
    host_secondary = linode_database_postgresql_v2.shared_db[0].host_secondary
    port           = linode_database_postgresql_v2.shared_db[0].port
    username       = linode_database_postgresql_v2.shared_db[0].root_username
    password       = linode_database_postgresql_v2.shared_db[0].root_password
    ca_cert        = linode_database_postgresql_v2.shared_db[0].ca_cert
    connection_uri = "postgres://${linode_database_postgresql_v2.shared_db[0].root_username}:${urlencode(linode_database_postgresql_v2.shared_db[0].root_password)}@${linode_database_postgresql_v2.shared_db[0].host_primary}:${linode_database_postgresql_v2.shared_db[0].port}/defaultdb?sslmode=require"
  } : null
}
