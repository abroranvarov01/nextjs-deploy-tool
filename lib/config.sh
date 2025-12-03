#!/bin/bash

# Функции для работы с конфигурацией проектов

# Загрузка конфигурации проекта
load_project_config() {
    local project_name="$1"
    
    if [ ! -f "$PROJECTS_DIR/$project_name.conf" ]; then
        echo -e "${RED}❌ Проект '$project_name' не найден${NC}"
        return 1
    fi
    
    source "$PROJECTS_DIR/$project_name.conf"
}

# Сохранение конфигурации проекта
save_project_config() {
    local project_name="$1"
    
    cat > "$PROJECTS_DIR/$project_name.conf" <<EOF
PROJECT_NAME="$PROJECT_NAME"
SITE_TYPE="$SITE_TYPE"
SERVER_USER="$SERVER_USER"
SERVER_HOST="$SERVER_HOST"
SERVER_PATH="$SERVER_PATH"
APP_NAME="$APP_NAME"
DOMAIN="$DOMAIN"
PORT=$PORT
GIT_REPO="$GIT_REPO"
GIT_BRANCH="$GIT_BRANCH"
EOF
}

# Показать конфигурацию проекта
show_config() {
    local project_name="$1"
    
    if [ -z "$project_name" ]; then
        echo -e "${RED}❌ Укажите название проекта${NC}"
        echo "Использование: nextdeploy config <project-name>"
        return 1
    fi
    
    if [ ! -f "$PROJECTS_DIR/$project_name.conf" ]; then
        echo -e "${RED}❌ Проект '$project_name' не найден${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}📝 Конфигурация проекта '$project_name':${NC}"
    echo ""
    cat "$PROJECTS_DIR/$project_name.conf"
}