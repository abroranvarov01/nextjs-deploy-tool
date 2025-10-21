#!/bin/bash

# Установка deploy скрипта в систему

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 Установка NextJS Deploy Tool${NC}"
echo ""

# Запрос конфигурации
echo -e "${YELLOW}Введите данные для подключения:${NC}"
echo ""

read -p "Пользователь сервера (например: ubuntu): " SERVER_USER
read -p "IP адрес сервера (например: 123.45.67.89): " SERVER_HOST
read -p "Путь на сервере (например: /var/www/my-app): " SERVER_PATH
read -p "Название приложения (например: my-app): " APP_NAME
read -p "Домен (например: mysite.com): " DOMAIN
read -p "Порт Next.js (по умолчанию 3000): " PORT
PORT=${PORT:-3000}
read -p "Git репозиторий (например: git@github.com:user/repo.git): " GIT_REPO
read -p "Git ветка (по умолчанию main): " GIT_BRANCH
GIT_BRANCH=${GIT_BRANCH:-main}

echo ""
echo -e "${YELLOW}Проверьте введенные данные:${NC}"
echo "SERVER_USER: $SERVER_USER"
echo "SERVER_HOST: $SERVER_HOST"
echo "SERVER_PATH: $SERVER_PATH"
echo "APP_NAME: $APP_NAME"
echo "DOMAIN: $DOMAIN"
echo "PORT: $PORT"
echo "GIT_REPO: $GIT_REPO"
echo "GIT_BRANCH: $GIT_BRANCH"
echo ""

read -p "Все верно? (y/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Установка отменена. Запустите скрипт заново.${NC}"
    exit 1
fi

# Создание конфигурационного файла
CONFIG_DIR="$HOME/.nextjs-deploy"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/config" <<EOF
SERVER_USER="$SERVER_USER"
SERVER_HOST="$SERVER_HOST"
SERVER_PATH="$SERVER_PATH"
APP_NAME="$APP_NAME"
DOMAIN="$DOMAIN"
PORT=$PORT
GIT_REPO="$GIT_REPO"
GIT_BRANCH="$GIT_BRANCH"
EOF

echo ""
echo -e "${GREEN}✅ Конфигурация сохранена${NC}"

# Создание исполняемого файла
INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

cat > "$INSTALL_DIR/nextdeploy" <<'SCRIPT_EOF'
#!/bin/bash

# Загрузка конфигурации
CONFIG_FILE="$HOME/.nextjs-deploy/config"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Конфигурация не найдена! Запустите install.sh"
    exit 1
fi

source "$CONFIG_FILE"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Проверка аргументов
case "$1" in
    setup)
        echo -e "${GREEN}🔧 Настройка сервера...${NC}"
        ssh $SERVER_USER@$SERVER_HOST 'bash -s' <<'ENDSSH'
set -e

# Настройка неинтерактивного режима для apt
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# Обновление системы без интерактивных запросов
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
        ;;
        
    git-setup)
        echo -e "${GREEN}🔑 Настройка Git...${NC}"
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
        ;;
        
    deploy|"")
        echo -e "${GREEN}🚀 Деплой приложения...${NC}"
        
        ssh $SERVER_USER@$SERVER_HOST "bash -s" <<ENDSSH
set -e

if [ -d "$SERVER_PATH" ]; then
    cd $SERVER_PATH
    git stash
    git fetch origin
    git checkout $GIT_BRANCH
    git pull origin $GIT_BRANCH
else
    sudo mkdir -p \$(dirname $SERVER_PATH)
    sudo chown -R \$USER:\$USER \$(dirname $SERVER_PATH)
    git clone -b $GIT_BRANCH $GIT_REPO $SERVER_PATH
    cd $SERVER_PATH
fi

echo "📦 Установка зависимостей..."
npm install --force

echo "🔨 Сборка проекта..."
npm run build

echo "🔄 Перезапуск PM2..."
if pm2 list | grep -q "$APP_NAME"; then
    pm2 restart $APP_NAME
else
    pm2 start npm --name "$APP_NAME" -- start
fi
pm2 save

if [ ! -f /etc/nginx/sites-available/$APP_NAME ]; then
    echo "🌐 Настройка Nginx..."
    sudo tee /etc/nginx/sites-available/$APP_NAME > /dev/null <<'NGINX_EOF'
server {
    listen 80;
    server_name $DOMAIN;

    client_max_body_size 100M;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Host \$server_name;
        
        proxy_buffering off;
        proxy_redirect off;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /_next/static {
        proxy_pass http://localhost:$PORT;
        proxy_cache_valid 200 60m;
        proxy_cache_bypass \$http_cache_control;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    location ~* \.(ico|css|js|gif|jpeg|jpg|png|woff|woff2|ttf|svg|eot)$ {
        proxy_pass http://localhost:$PORT;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
NGINX_EOF
    
    sudo ln -s /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl reload nginx
    
    echo "🔒 Установка SSL..."
    sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN || true
fi

echo "✅ Деплой завершен!"
pm2 status $APP_NAME
ENDSSH
        ;;
        
    logs)
        ssh $SERVER_USER@$SERVER_HOST "pm2 logs $APP_NAME"
        ;;
        
    status)
        ssh $SERVER_USER@$SERVER_HOST "pm2 status $APP_NAME"
        ;;
        
    restart)
        echo -e "${YELLOW}🔄 Перезапуск...${NC}"
        ssh $SERVER_USER@$SERVER_HOST "pm2 restart $APP_NAME"
        echo -e "${GREEN}✅ Перезапущено!${NC}"
        ;;
        
    stop)
        echo -e "${YELLOW}⏸️  Остановка...${NC}"
        ssh $SERVER_USER@$SERVER_HOST "pm2 stop $APP_NAME"
        ;;
        
    start)
        echo -e "${GREEN}▶️  Запуск...${NC}"
        ssh $SERVER_USER@$SERVER_HOST "pm2 start $APP_NAME"
        ;;
        
    ssh)
        ssh $SERVER_USER@$SERVER_HOST
        ;;
        
    config)
        echo -e "${YELLOW}📝 Текущая конфигурация:${NC}"
        cat "$CONFIG_FILE"
        ;;
        
    reinstall)
        echo -e "${YELLOW}🔄 Переустановка конфигурации...${NC}"
        curl -fsSL https://raw.githubusercontent.com/abroranvarov01/nextjs-deploy-tool/main/install.sh | bash
        ;;
        
    *)
        echo "NextJS Deploy Tool"
        echo ""
        echo "Использование: nextdeploy [команда]"
        echo ""
        echo "Команды:"
        echo "  deploy          Деплой приложения (по умолчанию)"
        echo "  setup           Первоначальная настройка сервера"
        echo "  git-setup       Настройка Git доступа"
        echo "  logs            Показать логи приложения"
        echo "  status          Статус приложения"
        echo "  restart         Перезапустить приложение"
        echo "  stop            Остановить приложение"
        echo "  start           Запустить приложение"
        echo "  ssh             Подключиться к серверу"
        echo "  config          Показать конфигурацию"
        echo "  reinstall       Переустановить конфигурацию"
        echo ""
        echo "Примеры:"
        echo "  nextdeploy              # деплой"
        echo "  nextdeploy setup        # настройка сервера"
        echo "  nextdeploy logs         # смотреть логи"
        ;;
esac
SCRIPT_EOF

chmod +x "$INSTALL_DIR/nextdeploy"

echo -e "${GREEN}✅ Команда nextdeploy создана${NC}"

# Добавление в PATH если нужно
SHELL_RC=""
if [ -n "$BASH_VERSION" ]; then
    SHELL_RC="$HOME/.bashrc"
elif [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
else
    SHELL_RC="$HOME/.profile"
fi

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "" >> "$SHELL_RC"
    echo "# NextJS Deploy Tool" >> "$SHELL_RC"
    echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$SHELL_RC"
    echo -e "${GREEN}✅ PATH обновлен в $SHELL_RC${NC}"
fi

echo ""
echo -e "${GREEN}✅ Установка завершена!${NC}"
echo ""
echo -e "${YELLOW}Выполните для применения изменений:${NC}"
echo "source $SHELL_RC"
echo ""
echo -e "${GREEN}Или просто перезапустите терминал${NC}"
echo ""
echo -e "${YELLOW}Теперь доступны команды:${NC}"
echo "  nextdeploy setup      # первая настройка сервера"
echo "  nextdeploy git-setup  # настройка Git (если приватный репо)"
echo "  nextdeploy            # деплой приложения"
echo "  nextdeploy logs       # логи"
echo "  nextdeploy status     # статус"
echo "  nextdeploy restart    # перезапуск"
echo ""
