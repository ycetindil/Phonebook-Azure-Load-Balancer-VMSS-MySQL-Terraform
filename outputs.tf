output "Phonebook_LB_Website" {
  value = "http://${azurerm_public_ip.pip.ip_address}"
}

output "Phonebook_LB_Website_DNS" {
  value = "http://${azurerm_public_ip.pip.domain_name_label}.${var.location}.cloudapp.azure.com"
}

output "SSH_Command" {
  value = "ssh -i ${var.vmss_private_key_path}${var.ssh_key_name}.pem ${var.vmss_username}@${azurerm_public_ip.pip.ip_address}"
}