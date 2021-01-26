variable "vault_token" {
    description = "Grab the vault token from the HCP dashboard or create a restricted access token for with admin permissions for Terraform"
}


variable "vault_address" {
  description = "The address for the Vault API. Note for HCP this must be the public address unless you are peering with the HCP VN and using TFC Agents"
}


variable "tenant_id" {
    description = "Your Azure tenant ID"
}

variable "client_id" {
    description = "Your Azure Client ID with correct permissions for managing SPNs"
}


variable "client_secret" {
    description = "The Client secret for your Azure SP"
}

variable "subscription_id" {
    default = "Azure subscription ID"
}