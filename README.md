# 🚀 Minikube и Argo CD в Yandex Cloud — полностью автоматизированный деплой

Эта инструкция описывает автоматизированный деплой Docker, Minikube (локальный Kubernetes), NGINX Ingress, cert-manager, Argo CD с TLS и, опционально, Harbor Registry на одной ВМ в Yandex Cloud. Все операции выполняются через Docker-контейнеры и Makefile — на вашей машине нужны только Docker и GNU Make.

---

## Содержание

- [Обзор и архитектура](#обзор-и-архитектура)
- [Структура проекта](#структура-проекта)
- [Требования](#требования)
- [Быстрый старт](#быстрый-старт)
- [Настройка (.env)](#настройка-env)
- [Развёртывание — шаг за шагом](#развёртывание--шаг-за-шагом)
- [Основные команды Makefile](#основные-команды-makefile)
- [Операции и доступ](#операции-и-доступ)
- [Диагностика и FAQ](#диагностика-и-faq)

---

## Обзор и архитектура

Сценарий развёртывания:

```
Ваш ноутбук (Docker + Make)
   ↓
Terraform — создаёт инфраструктуру в Yandex Cloud: сеть, статический IP и ВМ
   ↓
Ansible — настраивает ВМ: устанавливает Docker, Minikube, Helm, настраивает systemd-юниты, устанавливает Ingress‑контроллер, cert-manager (Let's Encrypt), ClusterIssuer, Argo CD с TLS
   ↓
Доступ к Argo CD: https://<ARGOCD_SUBDOMAIN>.<DOMAIN>
```

**Ключевые компоненты и версии:**

- kubectl: `v1.28.0` (можно изменить)
- cert-manager Helm: `v1.19.1`
- minikube/helm: последние доступные версии
- Остальные — из официальных источников, version pinning по коду

**Главные файлы:**

- `docker-compose.yml` — запуск анонимных окружений для terraform/ansible
- `Makefile` — команды оркестрации
- `infra/terraform/*.tf` — инфраструктура Yandex Cloud
- `infra/ansible/playbook.yml` — сценарии установки ролей Ansible
- `infra/ansible/roles/*` — роли Ansible для установки компонентов

---

## Структура проекта

```
minikube/
├── Makefile                     # основные команды: deploy-all, tf-*, ansible-*
├── docker-compose.yml           # окружения для Terraform и Ansible
├── README.md                    # этот гайд
└── infra/
    ├── terraform/               # инфраструктурные файлы
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── ...
    └── ansible/
        ├── Dockerfile
        ├── playbook.yml
        ├── requirements.yml
        ├── inventory.ini        # авто‑генерируется!
        ├── group_vars/
        │   └── all.yml
        └── roles/
            ├── common/
            ├── docker/
            ├── kubernetes_tools/
            ├── systemd_units/
            ├── ingress_nginx/
            ├── cert_manager/
            ├── cluster_issuer/
            ├── argocd/
            ├── argocd_ingress/
            ├── harbor/
            ├── access/
            ├── cluster_ready/
            └── python_venv_k8s/
```

**Где менять параметры:**

- `.env` — основные настройки облака, домена, фича‑флаги
- `infra/terraform/*.tf` — настройки инфраструктуры
- `infra/ansible/group_vars/all.yml` — версии утилит, компоненты
- `infra/ansible/playbook.yml` — порядок ролей
- `infra/ansible/inventory.ini` — формируется автоматически (`make ansible-prepare`)
- `infra/terraform/terraform.tfstate*` — state Terraform (для командной работы лучше выносить в удалённый backend)

---

## Требования

**Локально:**

- Docker и docker-compose
- GNU Make
- SSH-ключи: `~/.ssh/id_rsa`, `~/.ssh/id_rsa.pub`  
  (создать: `ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""`)

**В Yandex Cloud:**

- Аккаунт и доступ к консоли https://console.cloud.yandex.ru
- `YC_CLOUD_ID`, `YC_FOLDER_ID`, OAuth-токен `YC_OAUTH_TOKEN`

**Домен:**

- Ваш домен + доступ к управлению DNS (A-запись должна указывать на public IP ВМ)

---

## Быстрый старт

```bash
# 1. Клонируйте репозиторий
git clone <REPO_URL>
cd minikube

# 2. Создайте файл .env (см. шаблон в разделе "Настройка (.env)")
cp .env.example .env  # или создайте вручную

# 3. Запустите полный деплой
make deploy-all

# 4. Создайте DNS A-запись:
#    <ARGOCD_SUBDOMAIN>.<DOMAIN> → <public_ip из terraform output>

# 5. Получите пароль и откройте Argo CD
make get-password
# https://<ARGOCD_SUBDOMAIN>.<DOMAIN>
# login: admin
# pass: (вывод команды выше)
```

---

## Настройка (.env)

**Пример .env с комментариями:**

```dotenv
# === YANDEX CLOUD (обязательно) ===
YC_OAUTH_TOKEN=y0_...             # OAuth-токен
YC_CLOUD_ID=b1g...                # Cloud ID
YC_FOLDER_ID=b1g...               # Folder ID
YC_ZONE=ru-central1-a             # (опционально) зона по умолчанию

# === ДОМЕН и EMAIL (обязательно) ===
DOMAIN=example.com
ARGOCD_SUBDOMAIN=argocd
EMAIL=you@example.com

# === ВМ (опционально, есть дефолты) ===
VM_NAME=yc-minikube-argocd
VM_USERNAME=ubuntu
VM_CORES=4
VM_MEMORY=8
VM_DISK_SIZE=50
SSH_PUBLIC_KEY=~/.ssh/id_rsa.pub
# IMAGE_ID=...

# === Kubernetes CLI ===
KUBECTL_VERSION=v1.28.0

# === Фича‑флаги ===
LETSENCRYPT_STAGING=false
ENABLE_INGRESS_NGINX=true
ENABLE_CERT_MANAGER=true
ENABLE_CLUSTER_ISSUER=true
ENABLE_ARGOCD=true
ENABLE_ARGOCD_INGRESS=true
ENABLE_HARBOR=false
REGISTRY_SUBDOMAIN=registry
```

---

## Развёртывание — шаг за шагом

1. Инициализировать проект:
   ```bash
   make init
   ```

2. Создать инфраструктуру (ВМ и сеть в YC):
   ```bash
   make tf-apply
   make tf-output  # посмотреть параметры, включая IP
   ```

3. Создать DNS A-запись `<ARGOCD_SUBDOMAIN>.<DOMAIN>` → `<public_ip>`;

4. Установить компоненты на ВМ:
   ```bash
   make ansible-apply
   ```

5. Получить пароль и открыть Argo CD:
   ```bash
   make get-password
   # https://<ARGOCD_SUBDOMAIN>.<DOMAIN>
   # login: admin
   ```

---

## Основные команды Makefile

```bash
make help                  # Все цели make
make deploy-all            # Полное развёртывание (Terraform + Ansible)
make destroy-all           # Удалить всё (ВМ + локальные state)
make redeploy              # "Чистый" деплой

# Terraform
make tf-init               # Инициализация Terraform
make tf-plan               # Проверить план
make tf-apply              # Применить инфраструктуру
make tf-output             # Показать параметры (IP, SSH)
make tf-destroy            # Удалить инфраструктуру

# Ansible
make ansible-prepare       # Генерировать inventory из output Terraform
make ansible-apply         # Установка всего (Minikube, Ingress, Argo CD и др.)
make ansible-apply-debug   # Установка с подробным выводом
make ansible-validate      # Проверить синтаксис playbook
make ansible-debug         # Диагностика окружения

# Диагностика и доступ
make status                # Статус инфраструктуры и контейнеров
make logs                  # Docker-логи last run
make get-password          # Пароль ArgoCD admin
make ssh-connect           # SSH к ВМ (ubuntu@<IP>)
```

---

## Операции и доступ

- URL Argo CD: `https://<ARGOCD_SUBDOMAIN>.<DOMAIN>`
- Пользователь: `admin`
- Пароль: выводит `make get-password`
- Если сертификат не готов — подождите 1–5 минут после создания DNS A-записи.

**SSH доступ:**
```bash
make ssh-connect
# На ВМ доступны kubectl, helm, minikube
```
