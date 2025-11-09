# ============================================================================
# ПЕРЕМЕННЫЕ TERRAFORM
# ============================================================================
# Все переменные берутся из .env файла через docker-compose
# Используются в main.tf для конфигурации инфраструктуры

# ============================================================================
# ПЕРЕМЕННЫЕ YANDEX CLOUD
# ============================================================================

variable "yc_oauth_token" {
  description = "OAuth Token для аутентификации в Yandex Cloud (приоритет выше чем IAM токен)"
  type        = string
  sensitive   = true  # Не выводить в логах

  validation {
    condition     = length(var.yc_oauth_token) > 0
    error_message = "YC_OAUTH_TOKEN не может быть пустым"
  }
}

variable "yc_cloud_id" {
  description = "ID облака в Yandex Cloud (найти в консоли https://console.cloud.yandex.ru)"
  type        = string

  validation {
    condition     = length(var.yc_cloud_id) > 0
    error_message = "YC_CLOUD_ID не может быть пустым"
  }
}

variable "yc_folder_id" {
  description = "ID каталога (папки) внутри облака"
  type        = string

  validation {
    condition     = length(var.yc_folder_id) > 0
    error_message = "YC_FOLDER_ID не может быть пустым"
  }
}

variable "yc_zone" {
  description = "Зона Yandex Cloud для размещения ВМ"
  type        = string
  default     = "ru-central1-a"

  validation {
    condition     = contains(["ru-central1-a", "ru-central1-b", "ru-central1-c"], var.yc_zone)
    error_message = "Недопустимая зона. Используйте: ru-central1-a, ru-central1-b или ru-central1-c"
  }
}

# ============================================================================
# ПЕРЕМЕННЫЕ ВИРТУАЛЬНОЙ МАШИНЫ
# ============================================================================

variable "vm_name" {
  description = "Имя ВМ (будет видно в консоли Yandex Cloud)"
  type        = string
  default     = "yc-minikube-argocd"

  validation {
    condition     = can(regex("^[a-z][-a-z0-9]*$", var.vm_name)) && length(var.vm_name) <= 63
    error_message = "VM_NAME должно начинаться с буквы, содержать только буквы, цифры и дефисы, и быть не длиннее 63 символов"
  }
}

variable "vm_username" {
  description = "Пользователь для SSH доступа (обычно 'ubuntu' для Ubuntu образов)"
  type        = string
  default     = "ubuntu"

  validation {
    condition     = length(var.vm_username) > 0
    error_message = "VM_USERNAME не может быть пустым"
  }
}

variable "ssh_public_key" {
  description = "Путь к публичному SSH ключу (например: ~/.ssh/id_rsa.pub) или содержимое ключа"
  type        = string

  validation {
    condition     = length(var.ssh_public_key) > 0
    error_message = "SSH_PUBLIC_KEY не может быть пустым"
  }
}

variable "image_id" {
  description = "ID образа ВМ (если пусто, используется Ubuntu 24.04 LTS автоматически)"
  type        = string
  default     = ""
}

variable "vm_cores" {
  description = "Количество виртуальных процессоров (минимум 4 для Minikube, рекомендуется 4-8)"
  type        = number
  default     = 4

  validation {
    condition     = var.vm_cores >= 2 && var.vm_cores <= 96
    error_message = "VM_CORES должно быть от 2 до 96"
  }
}

variable "vm_memory" {
  description = "Объем оперативной памяти в ГБ (минимум 8 для Minikube, рекомендуется 8-16)"
  type        = number
  default     = 8

  validation {
    condition     = var.vm_memory >= 2 && var.vm_memory <= 384
    error_message = "VM_MEMORY должно быть от 2 до 384 ГБ"
  }
}

variable "vm_disk_size" {
  description = "Размер загрузочного диска в ГБ (минимум 30, рекомендуется 50+)"
  type        = number
  default     = 50

  validation {
    condition     = var.vm_disk_size >= 20
    error_message = "VM_DISK_SIZE должно быть минимум 20 ГБ"
  }
}
