SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# ============================================================================
# MAKEFILE ДЛЯ АВТОМАТИЗАЦИИ РАЗВЕРТЫВАНИЯ MINIKUBE + ARGOCD
# ============================================================================
# Этот Makefile предоставляет удобные команды для управления инфраструктурой
# через Terraform и Ansible в Docker контейнерах
#
# Использование: make <команда>
# Пример: make deploy-all

# ==================== ПЕРЕМЕННЫЕ ====================

# Пути
ENV_FILE := ./.env
DOCKER_COMPOSE := docker-compose
TF_DIR := ./infra/terraform
ANS_DIR := ./infra/ansible
CHECKS_DIR := .make/checks

# Тайминги ожидания SSH
SSH_WAIT_PORT_TIMEOUT ?= 300   # общий таймаут ожидания открытого порта (сек)
SSH_WAIT_CONNECT_TRIES ?= 30   # число попыток реального ssh-подключения
SSH_WAIT_CONNECT_DELAY ?= 5    # пауза между попытками (сек)

# Загружаем переменные из .env файла и экспортируем их
ifneq (,$(wildcard $(ENV_FILE)))
include $(ENV_FILE)
export $(shell sed -nE 's/^([A-Za-z_][A-Za-z0-9_]*)=.*/\1/p' $(ENV_FILE))
endif

# ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================

# Функция для выполнения Terraform команд в Docker контейнере
define terraform_run
    $(DOCKER_COMPOSE) run --rm terraform $(1)
endef

# Функция для выполнения Ansible команд в Docker контейнере
define ansible_run
    $(DOCKER_COMPOSE) run --rm ansible $(1)
endef

# ==================== ОСНОВНЫЕ КОМАНДЫ ====================

.PHONY: help
help:
	@echo "╔════════════════════════════════════════════════════════════════════════╗"
	@echo "║   🚀 КОМАНДЫ ДЛЯ УПРАВЛЕНИЯ MINIKUBE + ARGOCD ИНФРАСТРУКТУРОЙ        ║"
	@echo "╚════════════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📋 БЫСТРЫЙ СТАРТ (рекомендуется новичкам):"
	@echo "  make init              🔧 Инициализация проекта (проверки, подготовка)"
	@echo "  make deploy-all        🚀 Полное развертывание (Terraform + Ansible)"
	@echo "  make get-password      🔐 Получить пароль ArgoCD"
	@echo "  make status            📊 Показать статус компонентов"
	@echo ""
	@echo "🏗️  TERRAFORM КОМАНДЫ (управление инфраструктурой в облаке):"
	@echo "  make tf-init           🔧 Инициализация Terraform"
	@echo "  make tf-plan           📋 Показать план создания ресурсов"
	@echo "  make tf-validate       ✓  Проверить синтаксис Terraform файлов"
	@echo "  make tf-fmt            🎨 Отформатировать Terraform код"
	@echo "  make tf-apply          ✅ Создать ВМ в Yandex Cloud (3-5 минут)"
	@echo "  make tf-output         🖥️ Показать информацию о созданной ВМ"
	@echo "  make tf-destroy        🗑️  Удалить ВМ и инфраструктуру"
	@echo ""
	@echo "📦 ANSIBLE КОМАНДЫ (установка компонентов на ВМ):"
	@echo "  make ansible-prepare   📝 Подготовить инвентарь из Terraform"
	@echo "  make ansible-validate  ✓  Проверить синтаксис playbook'а"
	@echo "  make ansible-apply     ✅ Установить Minikube, ArgoCD и компоненты (20-30 минут)"
	@echo "  make ansible-debug     🐛 Показать информацию об окружении"
	@echo ""
	@echo "🔍 ДИАГНОСТИКА И ИНФОРМАЦИЯ:"
	@echo "  make status            📊 Статус всех компонентов"
	@echo "  make logs              📋 Показать логи последней операции"
	@echo "  make ssh-connect       🔗 Подключиться к ВМ по SSH"
	@echo "  make check-env         ✓  Проверить .env файл"
	@echo "  make check-docker      🐳 Проверить Docker установку"
	@echo ""
	@echo "🧹 ОЧИСТКА:"
	@echo "  make clean             🧹 Удалить локальные артефакты"
	@echo "  make checks-reset      ♻️  Сброс кэша проверок (check-*)"
	@echo "  make destroy-all       🗑️  Полное удаление (ВМ + локальные файлы)"
	@echo "  make redeploy          🔄 Переразвертывание (destroy + deploy)"
	@echo ""
	@echo "💡 ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ:"
	@echo ""
	@echo "  Первый запуск:"
	@echo "    1. cp .env.example .env"
	@echo "    2. nano .env                  # Редактируйте переменные"
	@echo "    3. make deploy-all            # Запуск полного развертывания"
	@echo ""
	@echo "  Если нужно изменить компоненты:"
	@echo "    make ansible-apply            # Переустановить компоненты"
	@echo ""
	@echo "  Если нужно полностью переделать:"
	@echo "    make destroy-all              # Удалить всё"
	@echo "    make deploy-all               # Начать заново"
	@echo ""

# ============================================================================
# ИНИЦИАЛИЗАЦИЯ И ПРОВЕРКИ
# ============================================================================

.PHONY: init
init: checks-reset check-docker check-env check-ssh
	@echo "✅ Проект успешно инициализирован и готов к развертыванию!"
	@echo "   Запустите: make deploy-all"

.PHONY: check-docker
check-docker: $(CHECKS_DIR)/docker.ok

$(CHECKS_DIR)/docker.ok:
	@mkdir -p $(CHECKS_DIR)
	@echo "🐳 Проверка Docker..."
	@command -v docker >/dev/null 2>&1 || (echo "❌ Docker не установлен! Установите из https://www.docker.com/products/docker-desktop"; exit 1)
	@command -v docker-compose >/dev/null 2>&1 || (echo "❌ docker-compose не установлен!"; exit 1)
	@echo "✅ Docker и docker-compose установлены"
	@touch $@

.PHONY: check-env
check-env: $(CHECKS_DIR)/env.ok

$(CHECKS_DIR)/env.ok:
	@mkdir -p $(CHECKS_DIR)
	@if [ ! -f $(ENV_FILE) ]; then \
	   echo "❌ Файл .env не найден!"; \
	   echo ""; \
	   echo "📋 Решение:"; \
	   echo "   1. cp .env.example .env"; \
	   echo "   2. nano .env  # и отредактируйте значения"; \
	   exit 1; \
	fi
	@echo "✅ .env файл найден"
	@echo "   Переменные загружены: YC_CLOUD_ID, DOMAIN, EMAIL и т.д."
	@touch $@

.PHONY: check-ssh
check-ssh: $(CHECKS_DIR)/ssh.ok

$(CHECKS_DIR)/ssh.ok:
	@mkdir -p $(CHECKS_DIR)
	@if [ ! -f ~/.ssh/id_rsa ]; then \
	   echo "❌ SSH ключ не найден (~/.ssh/id_rsa)"; \
	   echo ""; \
	   echo "📋 Решение - создайте ключ:"; \
	   echo "   ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ''"; \
	   exit 1; \
	fi
	@echo "✅ SSH ключ найден (~/.ssh/id_rsa)"
	@touch $@

# ============================================================================
# TERRAFORM КОМАНДЫ
# ============================================================================

.PHONY: tf-init
tf-init: check-docker check-env check-ssh
	@echo "🏗️  Инициализация Terraform..."
	@echo "   📥 Скачивание провайдера Yandex..."
	$(call terraform_run,init -upgrade)
	@echo "✅ Terraform инициализирован"

.PHONY: tf-validate
tf-validate: check-docker check-env
	@echo "🔍 Проверка синтаксиса Terraform файлов..."
	$(call terraform_run,validate)
	@echo "✅ Все Terraform файлы корректны"

.PHONY: tf-fmt
tf-fmt: check-docker check-env
	@echo "🎨 Форматирование Terraform файлов..."
	$(call terraform_run,fmt -recursive)
	@echo "✅ Terraform файлы отформатированы"

.PHONY: tf-plan
tf-plan: check-docker check-env
	@echo "📋 Создание плана изменений Terraform..."
	@echo "   Это покажет что будет создано/изменено/удалено"
	$(call terraform_run,plan -out=tfplan)

.PHONY: tf-apply
tf-apply: check-docker check-env tf-validate
	@echo "🚀 Применение Terraform плана..."
	@echo "   ⏳ Это может занять 3-5 минут..."
	@echo "   💡 Не закрывайте это окно!"
	@echo ""
	$(call terraform_run,apply -auto-approve)
	@echo ""
	@echo "✅ ВМ успешно создана в Yandex Cloud"
	@echo ""
	@if ! echo "$(MAKECMDGOALS)" | grep -qE "(^| )(deploy-all|redeploy)( |$$)"; then \
		$(MAKE) tf-output; \
	fi

.PHONY: tf-output
tf-output: check-docker check-env
	@echo "📊 Информация о созданной инфраструктуре:"
	@echo "════════════════════════════════════════════════════════════"
	$(call terraform_run,output)
	@echo "════════════════════════════════════════════════════════════"
	@echo ""
	@echo "💡 ВАЖНО! Создайте A-запись в DNS:"
	@echo "   Доменное имя: $(ARGOCD_SUBDOMAIN).$(DOMAIN)"
	@echo "   Указать на IP: (смотри выше - public_ip)"
	@echo ""
	@echo "⏳ Дождитесь распространения DNS (может быть до 24 часов)"

.PHONY: tf-destroy
tf-destroy: check-docker check-env
	@echo "⚠️  ВНИМАНИЕ! Это удалит ВМ и все данные!"
	@echo ""
	@read -p "Введите 'yes' для подтверждения удаления: " confirm && \
	[ "$$confirm" = "yes" ] || (echo "❌ Отменено"; exit 1)
	@echo ""
	@echo "🗑️  Удаление инфраструктуры..."
	$(call terraform_run,destroy -auto-approve)
	@echo "✅ Инфраструктура удалена"

# ============================================================================
# ОЖИДАНИЕ ГОТОВНОСТИ SSH
# ============================================================================

.PHONY: wait-ssh
wait-ssh: check-docker check-env check-ssh
	@echo "⏳ Ожидание готовности SSH на созданной ВМ..."
	@IP=$$($(call terraform_run,output -raw public_ip) 2>/dev/null); \
	if [ -z "$$IP" ]; then \
	   echo "❌ Не удалось получить IP адрес ВМ"; \
	   echo "   Сначала запустите: make tf-apply"; \
	   exit 1; \
	fi; \
	echo "🔌 Хост: $$IP, пользователь: $${VM_USERNAME:-ubuntu}"; \
	ATT=0; \
	while [ $$ATT -lt $(SSH_WAIT_CONNECT_TRIES) ]; do \
	  if ssh -i ~/.ssh/id_rsa -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 $${VM_USERNAME:-ubuntu}@$$IP "true" >/dev/null 2>&1; then \
	    echo "✅ SSH доступ подтверждён"; \
	    exit 0; \
	  fi; \
	  ATT=$$((ATT+1)); \
	  echo "… попытка $$ATT/$(SSH_WAIT_CONNECT_TRIES), ожидаем $(SSH_WAIT_CONNECT_DELAY)s"; \
	  sleep $(SSH_WAIT_CONNECT_DELAY); \
	done; \
	echo "❌ Не удалось подключиться по SSH после нескольких попыток"; \
	exit 1

# ============================================================================
# ANSIBLE КОМАНДЫ
# ============================================================================

.PHONY: ansible-prepare
ansible-prepare: check-docker check-env
	@echo "📝 Подготовка инвентаря Ansible..."
	@rm -f $(ANS_DIR)/inventory.ini
	@IP=$$($(call terraform_run,output -raw public_ip) 2>/dev/null); \
	if [ -z "$$IP" ]; then \
	   echo "❌ Не удалось получить IP адрес ВМ"; \
	   echo "   Сначала запустите: make tf-apply"; \
	   exit 1; \
	fi; \
	echo "[minikube]" > $(ANS_DIR)/inventory.ini; \
	echo "$$IP ansible_user=$${VM_USERNAME:-ubuntu} ansible_ssh_private_key_file=/root/.ssh/id_rsa ansible_python_interpreter=auto" >> $(ANS_DIR)/inventory.ini
	@echo "✅ Инвентарь подготовлен:"
	@cat $(ANS_DIR)/inventory.ini
	@echo ""

.PHONY: ansible-validate
ansible-validate: check-docker check-env
	@echo "🔍 Проверка синтаксиса Ansible playbook'а..."
	$(call ansible_run,ansible-playbook -i inventory.ini playbook.yml --syntax-check)
	@echo "✅ Playbook синтаксис корректен"

.PHONY: ansible-debug
ansible-debug: check-docker check-env
	@echo "🐛 Информация об окружении:"
	@echo ""
	@echo "Переменные окружения:"
	@env | grep -E "^(YC_|VM_|DOMAIN|EMAIL|KUBECTL|ANSIBLE|LETSENCRYPT_STAGING|ENABLE_|REGISTRY_SUBDOMAIN)" | sort || true
	@echo ""
	@echo "Terraform output (статус инфраструктуры):"
	@$(call terraform_run,output) || echo "(Terraform не инициализирован)"
	@echo ""
	@if [ -f $(ANS_DIR)/inventory.ini ]; then \
	   echo "Инвентарь Ansible (список хостов):"; \
	   cat $(ANS_DIR)/inventory.ini; \
	fi

.PHONY: ansible-apply
ansible-apply: check-docker check-env ansible-prepare wait-ssh ansible-validate
	@echo "📦 Установка Minikube, ArgoCD и компонентов..."
	@echo "   ⏳ Это может занять 20-30 минут..."
	@echo "   💡 Процесс проходит этапы установки Docker, Kubernetes и приложений"
	@echo "   💡 Не закрывайте это окно - даже если долго ничего не выводится!"
	@echo ""
	@sleep 2
	$(call ansible_run,ansible-playbook -i inventory.ini playbook.yml -v)
	@echo ""
	@echo "✅ Установка завершена!"
	@echo ""
	@if ! echo "$(MAKECMDGOALS)" | grep -qE "(^| )(deploy-all|redeploy)( |$$)"; then \
		$(MAKE) show-argocd-info; \
	fi

.PHONY: ansible-apply-debug
ansible-apply-debug: check-docker check-env ansible-prepare wait-ssh
	@echo "🐛 Запуск с повышенным уровнем логирования (очень подробные логи)..."
	$(call ansible_run,ansible-playbook -i inventory.ini playbook.yml -vvv)

# ============================================================================
# КОМБИНИРОВАННЫЕ КОМАНДЫ
# ============================================================================

.PHONY: deploy-all
deploy-all: tf-init tf-apply wait-ssh ansible-apply
	@echo ""
	@echo "╔════════════════════════════════════════════════════════════╗"
	@echo "║        ✅ РАЗВЕРТЫВАНИЕ УСПЕШНО ЗАВЕРШЕНО!               ║"
	@echo "╚════════════════════════════════════════════════════════════╝"
	@echo ""
	@make show-argocd-info

.PHONY: show-argocd-info
show-argocd-info:
	@echo "📋 ИНФОРМАЦИЯ ДЛЯ ДОСТУПА К ARGOCD:"
	@echo "════════════════════════════════════════════════════════════"
	@echo ""
	@echo "🌐 Веб-интерфейс ArgoCD:"
	@echo "   URL: https://$(ARGOCD_SUBDOMAIN).$(DOMAIN)"
	@echo ""
	@echo "👤 Учетные данные:"
	@echo "   Пользователь: admin"
	@echo "   Пароль: (смотрите ниже)"
	@echo ""
	@echo "🔐 Получить пароль:"
	@echo "   make get-password"
	@echo ""
	@echo "📊 Проверить статус компонентов:"
	@echo "   make status"
	@echo ""
	@echo "🔗 Подключиться к ВМ по SSH:"
	@echo "   make ssh-connect"
	@echo ""
	@echo "💡 ВАЖНО! Если сертификат еще не активен:"
	@echo "   - Это нормально, Let's Encrypt может выпускать сертификат"
	@echo "   - Обычно это займет 1-5 минут"
	@echo "   - Если прошло более 10 минут - проверьте DNS запись"
	@echo ""

.PHONY: destroy-all
destroy-all: tf-destroy clean
	@echo "✅ Полное удаление завершено"

.PHONY: redeploy
redeploy: destroy-all deploy-all
	@echo ""
	@echo "✅ Полное переразвертывание завершено!"

# ============================================================================
# ИНФОРМАЦИЯ И ДИАГНОСТИКА
# ============================================================================

.PHONY: status
status: check-docker check-env
	@echo "📊 СТАТУС КОМПОНЕНТОВ"
	@echo "════════════════════════════════════════════════════════════"
	@echo ""
	@echo "1️⃣ TERRAFORM - Статус инфраструктуры:"
	@IP=$$($(call terraform_run,output -raw public_ip) 2>/dev/null); \
	if [ -n "$$IP" ]; then echo "✅ ВМ создана (IP: $$IP)"; else echo "❌ ВМ не создана"; fi
	@echo ""
	@echo "2️⃣ ANSIBLE INVENTORY - Подготовка хостов:"
	@if [ -f $(ANS_DIR)/inventory.ini ]; then \
	   echo "✅ Инвентарь подготовлен:"; \
	   cat $(ANS_DIR)/inventory.ini; \
	else \
	   echo "❌ Инвентарь не подготовлен (запустите: make ansible-prepare)"; \
	fi
	@echo ""
	@echo "3️⃣ DOCKER КОНТЕЙНЕРЫ:"
	@docker ps -a --filter "label=com.docker.compose.project=$${PWD##*/}" 2>/dev/null | tail -5 || echo "Нет контейнеров"
	@echo ""

.PHONY: logs
logs:
	@echo "📋 Логи последней операции:"
	@echo "════════════════════════════════════════════════════════════"
	@docker-compose logs --tail=50 2>/dev/null || echo "Нет логов"

.PHONY: get-password
get-password: check-env
	@echo "🔐 ПОЛУЧЕНИЕ ПАРОЛЯ ARGOCD"
	@echo "════════════════════════════════════════════════════════════"
	@IP=$$($(call terraform_run,output -raw public_ip 2>/dev/null)); \
	if [ -z "$$IP" ]; then \
	   echo "❌ Не удалось получить IP адрес ВМ"; \
	   exit 1; \
	fi; \
	echo "🔌 Подключаюсь к ВМ: $$IP"; \
	echo ""; \
	PASSWORD=$$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes $${VM_USERNAME:-ubuntu}@$$IP \
	   "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d" 2>/dev/null); \
	if [ -n "$$PASSWORD" ]; then \
	    echo "Пароль: $$PASSWORD"; \
	else \
	    echo "⚠️  Не удалось получить пароль. Попробуйте позже или проверьте SSH доступ." ; \
	fi; \
	echo ""; \
	echo "💡 Если пароль не выводится:"; \
	echo "   1. Подождите еще несколько минут"; \
	echo "   2. Запустите: make ssh-connect"; \
	echo "   3. На ВМ выполните: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"

.PHONY: ssh-connect
ssh-connect: check-env
	@VM_IP=$$($(call terraform_run,output -raw public_ip 2>/dev/null)); \
	if [ -z "$$VM_IP" ]; then \
	   echo "❌ Не удалось получить IP адрес ВМ"; \
	   echo "   Сначала запустите: make tf-apply"; \
	   exit 1; \
	fi; \
	echo "🔗 Подключение к ВМ: $${VM_IP}"; \
	echo "   (Введите 'exit' для выхода)"; \
	echo ""; \
	ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no $${VM_USERNAME:-ubuntu}@$$VM_IP

# ============================================================================
# ОЧИСТКА
# ============================================================================

.PHONY: clean
clean:
	@echo "🧹 Очистка локальных артефактов..."
	@rm -rf $(TF_DIR)/.terraform/
	@rm -f $(TF_DIR)/.terraform.lock.hcl
	@rm -f $(TF_DIR)/tfplan
	@rm -f $(TF_DIR)/terraform.tfstate*
	@rm -f $(ANS_DIR)/inventory.ini
	@rm -f $(ANS_DIR)/*.retry
	@rm -rf $(CHECKS_DIR)
	@docker-compose down --remove-orphans 2>/dev/null || true
	@echo "✅ Очистка завершена"

.PHONY: checks-reset
checks-reset:
	@rm -rf $(CHECKS_DIR)
	@echo "♻️  Кэш проверок сброшен (check-docker, check-env, check-ssh)"

.PHONY: distclean
distclean: clean
	@echo "🧹 Полная очистка (включая .env)..."
	@rm -f .env
	@echo "✅ Полная очистка завершена"
	@echo "   ℹ️  Восстановите конфигурацию: cp .env.example .env"

# ============================================================================
# УТИЛИТЫ
# ============================================================================

.PHONY: all
all: deploy-all

.DEFAULT_GOAL := help

# Автозавершение для bash/zsh
.PHONY: completion-bash
completion-bash:
	@echo "# Добавьте эту строку в ~/.bashrc для автодополнения:"
	@echo "complete -W 'help init check-docker check-env check-ssh tf-init tf-validate tf-fmt tf-plan tf-apply tf-output tf-destroy ansible-prepare ansible-validate ansible-debug ansible-apply ansible-apply-debug deploy-all destroy-all redeploy status logs get-password ssh-connect clean checks-reset distclean' make"
