terraform {
  required_version = ">= 1.5.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.150.0"
    }
  }
}

# ============================================================================
# АУТЕНТИФИКАЦИЯ YANDEX CLOUD
# ============================================================================
provider "yandex" {
  token     = var.yc_oauth_token != "" ? var.yc_oauth_token : null
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_zone
}

# ============================================================================
# ЛОКАЛЬНЫЕ ПЕРЕМЕННЫЕ
# ============================================================================
locals {
  # Расширяем путь к SSH ключу (превращаем ~ в домашнюю директорию)
  ssh_public_key_path    = pathexpand(var.ssh_public_key)
  ssh_public_key_content = can(file(local.ssh_public_key_path)) ? trimspace(file(local.ssh_public_key_path)) : trimspace(var.ssh_public_key)
}

# ============================================================================
# ВИРТУАЛЬНАЯ СЕТЬ (VPC)
# ============================================================================
# Создаем виртуальную сеть для ВМ
resource "yandex_vpc_network" "net" {
  name        = "${var.vm_name}-net"
  description = "Виртуальная сеть для Minikube и ArgoCD"
}

# ============================================================================
# ПОДСЕТЬ (SUBNET)
# ============================================================================
# Создаем подсеть в указанной зоне
resource "yandex_vpc_subnet" "subnet" {
  name           = "${var.vm_name}-subnet"
  zone           = var.yc_zone
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["10.1.0.0/24"]
}

# ============================================================================
# ГРУППА БЕЗОПАСНОСТИ (SECURITY GROUP)
# ============================================================================
# Настраиваем правила входящего и исходящего трафика
resource "yandex_vpc_security_group" "sg" {
  name        = "${var.vm_name}-sg"
  description = "Security group для Minikube - открыты SSH, HTTP, HTTPS"
  network_id  = yandex_vpc_network.net.id

  # Входящий трафик: SSH для управления
  ingress {
    description    = "SSH - управление ВМ"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Входящий трафик: HTTP для Let's Encrypt валидации и редиректа
  ingress {
    description    = "HTTP - Let's Encrypt и редирект"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Входящий трафик: HTTPS для ArgoCD
  ingress {
    description    = "HTTPS - ArgoCD и приложения"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Исходящий трафик: разрешаем всё (важно для скачивания образов Docker)
  egress {
    description    = "Весь исходящий трафик"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ============================================================================
# ПОИСК ОБРАЗА ОС
# ============================================================================
# Ищем последний доступный образ Ubuntu 24.04 LTS
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2404-lts"
}

# ============================================================================
# СТАТИЧЕСКИЙ IP АДРЕС
# ============================================================================
# Зарезервируем статический публичный IP для стабильности
resource "yandex_vpc_address" "static_ip" {
  name = "${var.vm_name}-static-ip"

  external_ipv4_address {
    zone_id = var.yc_zone
  }
}

# ============================================================================
# ВЫЧИСЛИТЕЛЬНЫЙ ЭКЗЕМПЛЯР (ВМ)
# ============================================================================
# Создаем виртуальную машину для запуска Minikube и ArgoCD
resource "yandex_compute_instance" "vm" {
  name        = var.vm_name
  platform_id = "standard-v3"  # Новая поколение платформы (оптимально)
  zone        = var.yc_zone

  # Конфигурация вычислительных ресурсов
  resources {
    cores  = var.vm_cores        # Количество vCPU
    memory = var.vm_memory       # ОЗУ в ГБ
  }

  # Конфигурация загрузочного диска
  boot_disk {
    initialize_params {
      # Используем указанный образ или Ubuntu 24.04 LTS
      image_id = var.image_id != "" ? var.image_id : data.yandex_compute_image.ubuntu.id
      size     = var.vm_disk_size
      type     = "network-ssd"  # SSD диск для быстроты
    }
  }

  # Сетевой интерфейс ВМ
  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet.id
    nat                = true  # Включаем NAT для доступа в интернет
    nat_ip_address     = yandex_vpc_address.static_ip.external_ipv4_address[0].address  # Привязываем статический IP
    security_group_ids = [yandex_vpc_security_group.sg.id]  # Применяем security group
  }

  # Метаданные ВМ (SSH ключ для доступа)
  metadata = {
    ssh-keys = "${var.vm_username}:${local.ssh_public_key_content}"
  }

  # Позволяем останавливать ВМ вместо удаления (безопаснее)
  allow_stopping_for_update = true

  # Тэги для организации
  labels = {
    service = "minikube"
    role    = "infra"
    managed    = "terraform"
  }
}
