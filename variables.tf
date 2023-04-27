variable "prefix" {
  default = "phonebook"
}

# GitHub
variable "github_token_path" {
  default = "~/Documents/DevOps/GitHub/"
}

variable "github_token_filename" {
  default = "github_token.txt"
}

variable "github_repo_name" {
  description = "Should match with 'phonebook-app.py' line #13"
  default     = "Phonebook-Azure-Load-Balancer-VMSS-MySQL-Terraform"
}

variable "github_repo_branch" {
  default = "main"
}

# Resource group
variable "location" {
  default = "eastus"
}

# MySQL Flexible Database
variable "db_server_name" {
  description = "Should be unique"
  default     = "ycetindil-phonebook-app"
}

variable "db_username" {
  description = "Should match with 'phonebook-app.py' line #20"
  default     = "phonebook"
}

variable "db_password" {
  description = "Should match with 'phonebook-app.py' line #21"
  default     = "Password1234"
}

# VMSS
variable "ssh_key_rg" {
  default = "ycetindil"
}

variable "ssh_key_name" {
  default = "ycetindil"
}

variable "vmss_private_key_path" {
  default = "~/Documents/DevOps/Azure/"
}

variable "vmss_username" {
  description = "Should match with 'phonebook-app.py' line #13"
  default     = "clouduser"
}