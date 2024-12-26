#!/usr/bin/env bash
EPS_BASE_URL=${EPS_BASE_URL:-}
EPS_OS_DISTRO=${EPS_OS_DISTRO:-alpine}
EPS_UTILS_COMMON=${EPS_UTILS_COMMON:-}
EPS_UTILS_DISTRO=${EPS_UTILS_DISTRO:-}
EPS_APP_CONFIG=${EPS_APP_CONFIG:-}
EPS_CLEANUP=${EPS_CLEANUP:-false}
EPS_CT_INSTALL=${EPS_CT_INSTALL:-false}

if [ -z "$EPS_BASE_URL" -o -z "$EPS_UTILS_COMMON" -o -z "$EPS_UTILS_DISTRO" -o -z "$EPS_APP_CONFIG" ]; then
  printf "Script loaded incorrectly!\n\n";
  exit 1;
fi

source <(echo -n "$EPS_UTILS_COMMON")
source <(echo -n "$EPS_UTILS_DISTRO")
source <(echo -n "$EPS_APP_CONFIG")

pms_bootstrap
pms_settraps

if [ $EPS_CT_INSTALL = false ]; then
  pms_header
  pms_check_os
fi

EPS_OS_ARCH=$(uname -m)
EPS_OS_VERSION="3.18"

# Проверка и обновление системы
step_start "Operating System" "Updating" "Updated"
  apk update && apk upgrade --available
step_end "Operating System Updated"

# Установка зависимостей
step_start "Dependencies" "Installing" "Installed"
  apk add --no-cache \
    ca-certificates \
    curl \
    gnupg \
    openssl \
    python3 \
    py3-pip \
    build-base \
    git \
    tar \
    bash \
    libc6-compat \
    logrotate \
    nginx \
    nodejs \
    npm \
    yarn
step_end "Dependencies Installed"

# Установка Rust
step_start "Rust" "Installing" "Installed"
  curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain stable
  export PATH="$HOME/.cargo/bin:$PATH"
  rustc --version
step_end "Rust Installed"

# Установка Python и pip
step_start "Python" "Installing" "Installed"
  python3 -m ensurepip
  python3 -m pip install --upgrade pip
  pip install --no-cache-dir cryptography cffi certbot
  python3 --version
step_end "Python Installed"

# Установка Node.js и Yarn
step_start "Node.js and Yarn" "Installing" "Installed"
  apk add --no-cache nodejs npm
  npm install -g yarn
  node -v
  yarn -v
step_end "Node.js and Yarn Installed"

# Установка OpenResty
step_start "OpenResty" "Installing" "Installed"
  apk add --no-cache openresty
  ln -sf /usr/local/openresty/nginx/sbin/nginx /usr/sbin/nginx
  openresty -v
step_end "OpenResty Installed"

# Загрузка и настройка Nginx Proxy Manager
step_start "Nginx Proxy Manager" "Downloading" "Downloaded"
  NPM_VERSION=$(curl -s https://api.github.com/repos/NginxProxyManager/nginx-proxy-manager/releases/latest | grep "tag_name" | awk -F'"' '{print $4}')
  curl -L https://github.com/NginxProxyManager/nginx-proxy-manager/archive/refs/tags/${NPM_VERSION}.tar.gz | tar xz
  cd nginx-proxy-manager-${NPM_VERSION#v}
step_end "Nginx Proxy Manager Downloaded"

# Сборка фронтенда
step_start "Frontend" "Building" "Built"
  cd frontend
  export NODE_OPTIONS=--openssl-legacy-provider
  yarn install
  yarn build
  cd ..
step_end "Frontend Built"

# Инициализация бэкенда
step_start "Backend" "Initializing" "Initialized"
  cd backend
  yarn install
  cd ..
step_end "Backend Initialized"

# Настройка окружения
step_start "Environment" "Configuring" "Configured"
  mkdir -p /data/nginx /data/logs /data/ssl /data/config
  cp -r ./docker/rootfs/etc/nginx/* /etc/nginx/
step_end "Environment Configured"

# Запуск сервиса
step_start "Services" "Starting" "Started"
  openresty
  echo "Nginx Proxy Manager is running."
step_end "Services Started"

printf "\nNginx Proxy Manager should be reachable at ${CLR_CYB}http://<your-ip>:81${CLR}\n\n"
