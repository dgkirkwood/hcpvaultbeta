resource "vault_mount" "eastpac" {
  path = "eastpac"
  type = "pki"
  default_lease_ttl_seconds = 315360000
  max_lease_ttl_seconds = 315360001
}

resource "vault_pki_secret_backend_config_urls" "eastpac_config_urls" {
  backend              = vault_mount.eastpac.path
  issuing_certificates = ["http://127.0.0.1:8200/v1/pki/ca"]
  crl_distribution_points = ["http://127.0.0.1:8200/v1/pki/crl"]
}

resource "vault_pki_secret_backend_root_cert" "eastpacrootca" {
  depends_on = [vault_mount.eastpac]

  backend = vault_mount.eastpac.path

  type = "internal"
  common_name = "eastpac.net"
  ttl = "315360000"
  format = "pem"
  private_key_format = "der"
  key_type = "rsa"
  key_bits = 4096
  exclude_cn_from_sans = true
  ou = "DevOps"
  organization = "eastpac"
}

resource "vault_pki_secret_backend_intermediate_cert_request" "eastpac_dev_intermediate" {
  depends_on = [vault_mount.eastpac]

  backend = vault_mount.eastpac.path

  type        = "internal"
  common_name = "dev.eastpac.net"
}


resource "vault_pki_secret_backend_role" "eastpacjira" {
  backend = vault_mount.eastpac.path
  name    = "jira"
  allowed_domains = ["jira.dev.eastpac.net"]
  country = ["AU"]
  organization = ["eastpac LTD"]
  postal_code = ["2000"]
  ou = ["EDO"]
  allow_subdomains = true
  max_ttl = "86400s"
  generate_lease = true
}
