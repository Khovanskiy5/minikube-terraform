# ============================================================================
# ВЫХОДНЫЕ ДАННЫЕ TERRAFORM
# ============================================================================
# Эти значения выводятся после успешного выполнения terraform apply
# и используются для получения информации о созданных ресурсах

# Публичный IP адрес ВМ - самый важный выходной параметр
# Используется для подключения по SSH и настройки DNS
output "public_ip" {
  description = "Публичный IP адрес ВМ - на него должна указывать A-запись домена"
  value       = yandex_compute_instance.vm.network_interface[0].nat_ip_address
}

# Внутренний IP адрес ВМ внутри VPC подсети
output "internal_ip" {
  description = "Внутренний IP адрес ВМ в сети VPC"
  value       = yandex_compute_instance.vm.network_interface[0].ip_address
}

# ID виртуальной машины в Yandex Cloud
output "vm_id" {
  description = "ID виртуальной машины в Yandex Cloud"
  value       = yandex_compute_instance.vm.id
}

# Готовая команда для подключения к ВМ по SSH
output "ssh_command" {
  description = "Готовая команда для подключения к ВМ по SSH"
  value       = "ssh -i ~/.ssh/id_rsa ${var.vm_username}@${yandex_compute_instance.vm.network_interface[0].nat_ip_address}"
}

# ID виртуальной сети
output "network_id" {
  description = "ID виртуальной сети"
  value       = yandex_vpc_network.net.id
}

# ID подсети
output "subnet_id" {
  description = "ID подсети"
  value       = yandex_vpc_subnet.subnet.id
}

# ID группы безопасности
output "security_group_id" {
  description = "ID группы безопасности"
  value       = yandex_vpc_security_group.sg.id
}

# Информация для DNS настройки
output "dns_setup_info" {
  description = "Информация для настройки DNS"
  value = {
    public_ip = yandex_compute_instance.vm.network_interface[0].nat_ip_address
    instruction = "Создайте A-запись в DNS панели вашего домена, где Public IP должен указывать на IP ВМ"
  }
}
