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
    description = "Azure subscription ID"
}

variable "okta_token" {
    description = "The token used to auth to the Okta API"
}