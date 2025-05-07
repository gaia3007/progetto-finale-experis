 output "vm_private_ips" {
  description = "Indirizzi IP privati delle VM"
  value = [
    for nic in azurerm_network_interface.nic : nic.private_ip_address
  ]
}

output "vm_public_ips" {
  description = "Indirizzi IP pubblici delle VM"
  value = [
    for ip in azurerm_public_ip.public_ip : ip.ip_address
  ]
}

output "vm_names" {
  description = "Nomi delle macchine virtuali"
  value = [
    for vm in azurerm_linux_virtual_machine.vm : vm.name
  ]
} 