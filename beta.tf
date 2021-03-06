

provider "vault" {
    address = var.vault_address
    token = var.vault_token
}


# Create the KVv2 Secrets engine
resource "vault_mount" "kv" {
  path        = "static_secrets"
  type        = "kv-v2"
  description = "Key/Value V2 - with versioning"


  options = {
    version = 2
    max_versions = 3
    cas_enabled = false
  }
}


#Create the Azure secrets engine, with creds that have scope to manage Service Principals
resource "vault_azure_secret_backend" "azure" {
  subscription_id = var.subscription_id
  tenant_id = var.tenant_id
  client_id = var.client_id
  client_secret = var.client_secret
  environment = "AzurePublicCloud"
}

#Define the generated roles for the Azure secrets engine. Scopes can be role or group-based
resource "vault_azure_secret_backend_role" "generated_role" {
  backend                     = vault_azure_secret_backend.azure.path
  role                        = "Sandpit"
  ttl                         = 300
  max_ttl                     = 600

  azure_roles {
    role_name = "Contributor"
    scope =  "/subscriptions/14692f20-9428-451b-8298-102ed4e39c2a/resourceGroups/Sandpit"
  }
}


#Static secret definition 
resource "vault_generic_secret" "rnd" {
    path = "${vault_mount.kv.path}/rnd"
    data_json = <<EOT
    {
        "api_token": "aabbcc112233",
        "scope": "all api resources"
    }
    EOT
}

resource "vault_generic_secret" "prod" {
    path = "${vault_mount.kv.path}/prod"
    data_json = <<EOT
    {
        "username": "resourceadmin",
        "password": "mySafeStaticPassword"
    }
    EOT
}


#Define Transit secret engine
resource "vault_mount" "transit" {
  path                      = "transit"
  type                      = "transit"
  description               = "Encryption as a service endpoint"
  default_lease_ttl_seconds = 3600
  max_lease_ttl_seconds     = 86400
}

resource "vault_transit_secret_backend_key" "key" {
  backend = vault_mount.transit.path
  name    = "rnd"
}


resource "vault_mount" "pki" {
  type = "pki"
  path = "pki"
  default_lease_ttl_seconds = 3600
  max_lease_ttl_seconds = 86400
}

resource "vault_pki_secret_backend_config_urls" "config_urls" {
  backend              = vault_mount.pki.path
  issuing_certificates = ["http://127.0.0.1:8200/v1/pki/ca"]
  crl_distribution_points = ["http://127.0.0.1:8200/v1/pki/crl"]
}

resource "vault_pki_secret_backend_root_cert" "rootca" {
  depends_on = [vault_mount.pki]

  backend = vault_mount.pki.path

  type = "internal"
  common_name = "Root CA"
  ttl = "315360000"
  format = "pem"
  private_key_format = "der"
  key_type = "rsa"
  key_bits = 4096
  exclude_cn_from_sans = true
  ou = "DevOps"
  organization = "DK Corp"
}


resource "vault_pki_secret_backend_role" "prod" {
  backend = vault_mount.pki.path
  name    = "prod"
  allowed_domains = ["dkcorp.local"]
  allow_subdomains = true
  max_ttl = "72h"
}

#Define the Userpass auth method
resource "vault_auth_backend" "userpass" {
  type = "userpass"
  path = "userpass"
}

#Use the generic endpoint to create two users (this is a write only resource and has no specific TF resource)
resource "vault_generic_endpoint" "alice" {
  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/alice"
  ignore_absent_fields = true

  data_json = <<EOT
{
  "password": "alice"
}
EOT
}

resource "vault_generic_endpoint" "bob" {
  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/bob"
  ignore_absent_fields = true

  data_json = <<EOT
{
  "password": "bob"
}
EOT
}

#Create an entity for Alice. Used to map many auth methods to a single user or service. 
resource "vault_identity_entity" "alice" {
  name      = "alice"
}

#Create an alias that maps the auth method (userpass) back to your entity. Entities can have zero to many aliases. 
resource "vault_identity_entity_alias" "alice_userpass" {
  name            = "alice"
  mount_accessor  = vault_auth_backend.userpass.accessor
  canonical_id    = vault_identity_entity.alice.id
}


#Perform the same for Bob
resource "vault_identity_entity" "bob" {
  name      = "bob"
}

resource "vault_identity_entity_alias" "bob_userpass" {
  name            = "bob"
  mount_accessor  = vault_auth_backend.userpass.accessor
  canonical_id    = vault_identity_entity.bob.id
}


#Create groups for your entities to map common policies
resource "vault_identity_group" "rnd" {
  name     = "rnd"
  type     = "internal"
  policies = ["rnd"]
  member_entity_ids = [vault_identity_entity.alice.id]
}


resource "vault_identity_group" "prod" {
  name     = "prod"
  type     = "internal"
  policies = ["prod"]
  member_entity_ids = [vault_identity_entity.bob.id]
}





#Create policies to define path-based CRUD operations against secrets and auth methods within Vault
resource "vault_policy" "rnd" {
  name = "rnd"

  policy = <<EOT
    path "${vault_mount.kv.path}/data/rnd" {
        capabilities = ["list", "read"]
    }
    path "${vault_azure_secret_backend.azure.path}/creds/Sandpit" {
        capabilities = ["read"]
    }
EOT
}

resource "vault_policy" "prod" {
  name = "prod"

  policy = <<EOT
    path "${vault_mount.kv.path}/data/prod" {
        capabilities = ["list", "read"]
    }
    path "${vault_mount.pki.path}/*" {
        capabilities = ["list", "read", "create", "update"]
    }
EOT
}
