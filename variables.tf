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

variable "aws_auth_access_key" {
    description = "The access key for the IAM user used for AWS auth"
}

variable "aws_auth_secret" {
    description = "The secret for your IAM user"
}

variable "oidc_id" {
    description = "OKTA client id"
}

variable "oidc_secret" {
    description = "OKTA client secret"
}

variable "oidc_audience" {
    description = "OKTA audience"
}