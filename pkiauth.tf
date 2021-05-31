
resource "vault_pki_secret_backend" "pkiauth" {
  path = "pkiauth"
  default_lease_ttl_seconds = 3600
  max_lease_ttl_seconds = 86400
}



resource "vault_pki_secret_backend_config_urls" "pkiauth_config_urls" {
  backend              = vault_pki_secret_backend.pkiauth.path
  issuing_certificates = ["http://127.0.0.1:8200/v1/pki/ca"]
  crl_distribution_points = ["http://127.0.0.1:8200/v1/pki/crl"]
}



resource "vault_pki_secret_backend_root_cert" "pkiauthrootca" {
  depends_on = [vault_pki_secret_backend.pkiauth]

  backend = vault_pki_secret_backend.pkiauth.path

  type = "internal"
  common_name = "pkiauth.net"
  ttl = "10000h"
  format = "pem"
  private_key_format = "der"
  key_type = "rsa"
  key_bits = 4096
  exclude_cn_from_sans = true
  ou = "DevOps"
  organization = "pkiauth"
}



resource "vault_pki_secret_backend_role" "pkiauth" {
  backend = vault_pki_secret_backend.pkiauth.path
  name    = "prod"
  allowed_domains = ["pkiauth.net"]
  allow_subdomains = true
  max_ttl = "300s"
  generate_lease = true
}

#Define the Userpass auth method
