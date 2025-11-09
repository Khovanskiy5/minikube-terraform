# Ansible runner base image (minor version pinned)
FROM python:3.12-slim

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# System packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client \
    bash \
    ca-certificates \
    curl \
    wget \
    git \
  && rm -rf /var/lib/apt/lists/*

# Python dependencies and tooling (pinned)
# Используем meta-пакет ansible (ветка 10.x) для согласованности с ansible-core 2.17.x
RUN pip install --no-cache-dir \
    ansible==10.5.0 \
    ansible-lint==24.9.0 \
    yamllint==1.35.1 \
    kubernetes==30.1.0 \
    jsonpatch==1.33 \
    openshift==0.13.2 \
    PyYAML==6.0.2 \
    requests==2.32.3

WORKDIR /workspace/infra/ansible

# Install required Ansible collections during build
COPY requirements.yml /workspace/infra/ansible/requirements.yml
RUN ansible-galaxy collection install -r requirements.yml --force

CMD ["bash", "-lc", "ansible-playbook -i inventory.ini playbook.yml -v"]
