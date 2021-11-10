terraform {
  required_providers {
    vault = {
      source = "hashicorp/vault"
      version = "2.23.0"
    }
  }
}

data "terraform_remote_state" "hcp" {
  backend = "remote"

  config = {
    organization = "dk"
    workspaces = {
      name = "hcp-config"
    }
  }
}

provider "vault" {
    address = data.terraform_remote_state.hcp.outputs.vault_public_address
    token = data.terraform_remote_state.hcp.outputs.vault_token
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



# #Create the Azure secrets engine, with creds that have scope to manage Service Principals
# resource "vault_azure_secret_backend" "azure" {
#   subscription_id = var.subscription_id
#   tenant_id = var.tenant_id
#   client_id = var.client_id
#   client_secret = var.client_secret
#   environment = "AzurePublicCloud"
# }

# #Define the generated roles for the Azure secrets engine. Scopes can be role or group-based
# resource "vault_azure_secret_backend_role" "generated_role" {
#   backend                     = vault_azure_secret_backend.azure.path
#   role                        = "Sandpit"
#   ttl                         = 300
#   max_ttl                     = 600

#   azure_roles {
#     role_name = "Contributor"
#     scope =  "/subscriptions/14692f20-9428-451b-8298-102ed4e39c2a/resourceGroups/jamie-wright"
#   }
# }


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
        "password": "myNewPassword"
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
  deletion_allowed = true
}



resource "vault_mount" "dancorp" {
  path = "dancorp"
  type = "pki"
  default_lease_ttl_seconds = 315360000
  max_lease_ttl_seconds = 315360001
}



resource "vault_pki_secret_backend_config_urls" "dancorp_config_urls" {
  backend              = vault_mount.dancorp.path
  issuing_certificates = ["http://127.0.0.1:8200/v1/pki/ca"]
  crl_distribution_points = ["http://127.0.0.1:8200/v1/pki/crl"]
}



resource "vault_pki_secret_backend_root_cert" "dancorprootca" {
  depends_on = [vault_mount.dancorp]

  backend = vault_mount.dancorp.path

  type = "internal"
  common_name = "dancorp.net"
  ttl = "315360000"
  format = "pem"
  private_key_format = "der"
  key_type = "rsa"
  key_bits = 4096
  exclude_cn_from_sans = true
  ou = "DevOps"
  organization = "DanCorp"
}

resource "vault_pki_secret_backend_intermediate_cert_request" "dev_intermediate" {
  depends_on = [vault_mount.dancorp]

  backend = vault_mount.dancorp.path

  type        = "internal"
  common_name = "dev.dancorp.net"
}


resource "vault_pki_secret_backend_role" "dancorp" {
  backend = vault_mount.dancorp.path
  name    = "prod"
  allowed_domains = ["dancorp.net"]
  allow_subdomains = true
  max_ttl = "300s"
  generate_lease = true
}

resource "vault_pki_secret_backend_role" "dancorpdev" {
  backend = vault_mount.dancorp.path
  name    = "dev"
  allowed_domains = ["dev.dancorp.net"]
  allow_subdomains = true
  max_ttl = "300s"
  generate_lease = true
}

resource "vault_okta_auth_backend" "okta" {
    description  = "Vault Okta Dev Account auth"
    organization = "dev-11095918"
    token        = var.okta_token

    group {
        group_name = "cloudNetworks"
        policies   = ["prod"]
    }
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

resource "vault_generic_endpoint" "admin" {
  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/admin"
  ignore_absent_fields = true

  data_json = <<EOT
{
  "password": "admin"
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

resource "vault_identity_entity" "charlie" {
  name      = "charlie"
}

resource "vault_identity_entity_alias" "bob_userpass" {
  name            = "bob"
  mount_accessor  = vault_auth_backend.userpass.accessor
  canonical_id    = vault_identity_entity.bob.id
}

resource "vault_identity_entity" "admin" {
  name      = "admin"
}

resource "vault_identity_entity_alias" "admin_userpass" {
  name            = "admin"
  mount_accessor  = vault_auth_backend.userpass.accessor
  canonical_id    = vault_identity_entity.admin.id
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

resource "vault_identity_group" "admin" {
  name     = "admin"
  type     = "internal"
  policies = ["admin"]
  member_entity_ids = [vault_identity_entity.admin.id]
}





#Create policies to define path-based CRUD operations against secrets and auth methods within Vault
resource "vault_policy" "rnd" {
  name = "rnd"

  policy = <<EOT
    path "${vault_mount.kv.path}/data/rnd" {
        capabilities = ["list", "read"]
    }
    path "${vault_mount.dancorp.path}/issue/dev" {
        capabilities = ["list", "read", "create", "update"]
    }
EOT
}

resource "vault_policy" "prod" {
  name = "prod"

  policy = <<EOT
    path "${vault_mount.kv.path}/data/prod" {
        capabilities = ["list", "read"]
    }
    path "${vault_mount.dancorp.path}/issue/prod" {
        capabilities = ["list", "read", "create", "update"]
    }
EOT
}

resource "vault_policy" "admin" {
  name = "admin"
  policy = <<EOT
    path "*" {
      capabilities = ["sudo","read","create","update","delete","list"]
    }
EOT
}



resource "vault_auth_backend" "approle" {
  type = "approle"
}

resource "vault_approle_auth_backend_role" "prod" {
  backend        = vault_auth_backend.approle.path
  role_name      = "prod"
  token_policies = ["prod"]
  token_ttl = 172800
}

resource "vault_approle_auth_backend_role" "appx" {
  backend        = vault_auth_backend.approle.path
  role_name      = "appx"
  token_policies = ["prod"]
  token_ttl = 172800
}

resource "vault_identity_entity" "appx" {
  name      = "appx"
}

#Create an alias that maps the auth method (userpass) back to your entity. Entities can have zero to many aliases. 
resource "vault_identity_entity_alias" "appx_approle" {
  name            = vault_approle_auth_backend_role.appx.role_id
  mount_accessor  = vault_auth_backend.approle.accessor
  canonical_id    = vault_identity_entity.appx.id
}



resource "vault_approle_auth_backend_role_secret_id" "agent" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.prod.role_name
}


resource "vault_pki_secret_backend_cert" "dancorp" {

  backend = vault_mount.dancorp.path
  name = vault_pki_secret_backend_role.dancorpdev.name
  ttl = 250

  common_name = "mylb.dev.dancorp.net"
  auto_renew = true
  min_seconds_remaining = 120
}

resource "vault_auth_backend" "aws" {
  type = "aws"
}

resource "vault_aws_auth_backend_client" "example" {
  backend    = vault_auth_backend.aws.path
  access_key = var.aws_auth_access_key
  secret_key = var.aws_auth_secret
}

resource "vault_aws_auth_backend_role" "myrole" {
  backend                         = vault_auth_backend.aws.path
  role                            = "aws_prod"
  auth_type                       = "iam"
  bound_iam_role_arns             = ["arn:aws:iam::711129375688:role/moayad-ec2-role"]
  inferred_entity_type            = "ec2_instance"
  inferred_aws_region             = "ap-southeast-2"
  token_ttl                       = 60
  token_max_ttl                   = 120
  token_policies                  = ["default", "prod"]
}



output "cert" {
  value = vault_pki_secret_backend_cert.dancorp.certificate
}


output "roleid" {
  value = vault_approle_auth_backend_role.prod.role_id
}

output "secretid" {
  value = vault_approle_auth_backend_role_secret_id.agent.secret_id
  sensitive = true
}

resource "vault_generic_secret" "approledetails" {
    path = "${vault_mount.kv.path}/approle"
    data_json = <<EOT
    {
        "roleid": "${vault_approle_auth_backend_role.prod.role_id}",
        "secretid": "${vault_approle_auth_backend_role_secret_id.agent.secret_id}"
    }
    EOT
}



# resource "vault_nomad_secret_backend" "config" {
#     backend                   = "nomad"
#     description               = "Nomad tokens"
#     default_lease_ttl_seconds = "3600"
#     max_lease_ttl_seconds     = "7200"
#     max_ttl                   = "240"
#     address                   = "http://tf-lb-20210920031410652900000006-1872773464.ap-southeast-2.elb.amazonaws.com:4646"
#     token                     = "6c5754c0-3b00-5db5-c509-236c492adc06"
#     ttl                       = "120"
# }

# resource "vault_nomad_secret_role" "prodops" {
#   backend   = vault_nomad_secret_backend.config.backend
#   role      = "prodops"
#   type      = "client"
#   policies  = ["prodops"]
# }
