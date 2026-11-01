variable "resource_group_name" {
  description = "Project resource group, created by bootstrap.ps1."
  type        = string
  default     = "rg-arias-sh"
}

variable "domain" {
  description = "Apex domain hosted in Azure DNS."
  type        = string
  default     = "arias.sh"
}

variable "node_vm_size" {
  description = "VM size for the single AKS node. Covered by a 1-year reservation (Basv2 family), so keep changes within that family."
  type        = string
  default     = "Standard_B2als_v2"
}

variable "admin_object_id" {
  description = "Entra object ID of the human admin (John): kubectl and Key Vault access."
  type        = string
}

variable "deployer_object_id" {
  description = "Principal ID of the GitHub Actions managed identity: kubectl access for pipelines."
  type        = string
}
