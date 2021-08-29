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