#!/bin/bash

# Функции для деплоя проектов

# Настройка сервера
deploy_setup() {
    echo -e "${GREEN}🔧 Настройка сервера для '$PROJECT_NAME'...${NC}"
    
    ssh $SERVER_USER@$SERVER_HOST 'bash -s' <<'ENDSSH'
set -e

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

sudo DEBIAN_FRONTEND=noninteractive apt update
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# Установка Node.js
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
fi

# Установка PM2
if ! command -v pm2 &> /dev/null; then
    sudo npm install -g pm2
    pm2 startup systemd -u $USER --hp $HOME
    sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u $USER --hp $HOME
fi

# Установка Nginx
if ! command -v nginx &> /dev/null; then
    sudo DEBIAN_FRONTEND=noninteractive apt install -y nginx
    sudo systemctl enable nginx
    sudo systemctl start nginx
fi

# Установка Certbot
if ! command -v certbot &> /dev/null; then
    sudo DEBIAN_FRONTEND=noninteractive apt install -y certbot python3-certbot-nginx
fi

# Настройка firewall
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

echo "✅ Сервер настроен!"
ENDSSH
}

# Настройка Git
deploy_git_setup() {
    echo -e "${GREEN}🔑 Настройка Git для '$PROJECT_NAME'...${NC}"
    
    ssh $SERVER_USER@$SERVER_HOST 'bash -s' <<'ENDSSH'
if [ ! -f ~/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -C "server-deploy-key" -f ~/.ssh/id_ed25519 -N ""
fi

echo ""
echo "📋 Добавьте этот ключ в GitHub/GitLab:"
cat ~/.ssh/id_ed25519.pub
echo ""

ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
ssh-keyscan gitlab.com >> ~/.ssh/known_hosts 2>/dev/null
ENDSSH
}

# Получить конфигурацию Nginx для X сайта
get_nginx_config_x() {
    cat <<'NGINX_EOF'
server {
    server_name $DOMAIN www.$DOMAIN;
    
    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
    
    access_log /var/log/nginx/${APP_NAME}_access.log;
    error_log  /var/log/nginx/${APP_NAME}_error.log;
    
    listen 80;
    listen [::]:80;
}
NGINX_EOF
}

# Получить конфигурацию Nginx для Z сайта
get_nginx_config_z() {
    cat <<'NGINX_EOF'
server {
    listen 80;
    server_name $DOMAIN;

    client_max_body_size 100M;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Host $server_name;
        
        proxy_buffering off;
        proxy_redirect off;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /_next/static {
        proxy_pass http://localhost:$PORT;
        proxy_cache_valid 200 60m;
        proxy_cache_bypass $http_cache_control;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    location ~* \.(ico|css|js|gif|jpeg|jpg|png|woff|woff2|ttf|svg|eot)$ {
        proxy_pass http://localhost:$PORT;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
NGINX_EOF
}

# Основной деплой
deploy_project() {
    echo -e "${GREEN}🚀 Деплой '$PROJECT_NAME'...${NC}"
    
    # Получаем нужную конфигурацию Nginx
    if [ "$SITE_TYPE" == "x" ]; then
        NGINX_CONFIG=$(get_nginx_config_x)
    else
        NGINX_CONFIG=$(get_nginx_config_z)
    fi
    
    ssh $SERVER_USER@$SERVER_HOST "bash -s" -- "$SERVER_PATH" "$GIT_REPO" "$GIT_BRANCH" "$APP_NAME" "$DOMAIN" "$PORT" "$SITE_TYPE" "$NGINX_CONFIG" <<'ENDSSH'
set -e

SERVER_PATH="$1"
GIT_REPO="$2"
GIT_BRANCH="$3"
APP_NAME="$4"
DOMAIN="$5"
PORT="$6"
SITE_TYPE="$7"
NGINX_CONFIG="$8"

# Клонирование или обновление репозитория
if [ -d "$SERVER_PATH" ]; then
    cd "$SERVER_PATH"
    git stash
    git fetch origin
    git checkout "$GIT_BRANCH"
    git pull origin "$GIT_BRANCH"
else
    sudo mkdir -p $(dirname "$SERVER_PATH")
    sudo chown -R $USER:$USER $(dirname "$SERVER_PATH")
    git clone -b "$GIT_BRANCH" "$GIT_REPO" "$SERVER_PATH"
    cd "$SERVER_PATH"
fi

# Установка зависимостей
echo "📦 Установка зависимостей..."
npm install --force

# Сборка проекта
echo "🔨 Сборка проекта..."
npm run build

# Управление PM2
echo "🔄 Управление PM2..."
if pm2 list | grep -q "$APP_NAME"; then
    pm2 restart "$APP_NAME"
else
    pm2 start npm --name "$APP_NAME" -- start
fi
pm2 save

# Настройка Nginx (если еще не настроен)
if [ ! -f "/etc/nginx/sites-available/$APP_NAME" ]; then
    echo "🌐 Настройка Nginx..."
    
    echo "$NGINX_CONFIG" | sudo tee /etc/nginx/sites-available/$APP_NAME > /dev/null
    sudo ln -s /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl reload nginx
    
    # Установка SSL
    echo "🔒 Установка SSL..."
    if [ "$SITE_TYPE" == "x" ]; then
        sudo certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" --non-interactive --agree-tos --email "admin@$DOMAIN" || true
    else
        sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "admin@$DOMAIN" || true
    fi
fi

echo "✅ Деплой завершен!"
pm2 status "$APP_NAME"
ENDSSH
}