#!/bin/bash

# Функции для управления проектами

# Создание нового проекта
create_project() {
    echo -e "${BLUE}➕ Создание нового проекта${NC}"
    echo ""
    
    read -p "Название проекта (например: my-app): " PROJECT_NAME
    
    if [ -f "$PROJECTS_DIR/$PROJECT_NAME.conf" ]; then
        echo -e "${RED}❌ Проект с таким именем уже существует!${NC}"
        return 1
    fi
    
    # Выбор типа сайта
    echo ""
    echo -e "${YELLOW}Выберите тип сайта:${NC}"
    echo "1) X сайт (основной продукт)"
    echo "2) Z сайт (редирект)"
    echo ""
    read -p "Введите 1 или 2: " SITE_TYPE
    
    if [[ "$SITE_TYPE" == "1" ]]; then
        SITE_TYPE="x"
        echo -e "${GREEN}✅ Выбран X сайт${NC}"
    elif [[ "$SITE_TYPE" == "2" ]]; then
        SITE_TYPE="z"
        echo -e "${GREEN}✅ Выбран Z сайт${NC}"
    else
        echo -e "${RED}❌ Неверный выбор${NC}"
        return 1
    fi
    
    # Ввод данных
    echo ""
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
    
    # Подтверждение
    echo ""
    echo -e "${YELLOW}Проверьте введенные данные:${NC}"
    echo "ПРОЕКТ: $PROJECT_NAME"
    echo "ТИП: $([ "$SITE_TYPE" == "x" ] && echo "X (основной)" || echo "Z (редирект)")"
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
        echo -e "${RED}Создание отменено${NC}"
        return 1
    fi
    
    # Сохранение конфигурации
    save_project_config "$PROJECT_NAME"
    
    echo ""
    echo -e "${GREEN}✅ Проект '$PROJECT_NAME' создан!${NC}"
    echo ""
    echo -e "${YELLOW}Используйте:${NC}"
    echo "  nextdeploy $PROJECT_NAME setup    # настройка сервера"
    echo "  nextdeploy $PROJECT_NAME deploy   # деплой"
}

# Список проектов
list_projects() {
    echo -e "${BLUE}📋 Список проектов:${NC}"
    echo ""
    
    if [ ! "$(ls -A $PROJECTS_DIR 2>/dev/null)" ]; then
        echo -e "${YELLOW}Нет созданных проектов${NC}"
        echo ""
        echo "Создайте новый проект:"
        echo "  nextdeploy add"
        return
    fi
    
    for conf in "$PROJECTS_DIR"/*.conf; do
        source "$conf"
        TYPE_LABEL=$([ "$SITE_TYPE" == "x" ] && echo "X" || echo "Z")
        echo -e "${GREEN}▶${NC} $PROJECT_NAME ${BLUE}($TYPE_LABEL)${NC} - $DOMAIN ($SERVER_HOST)"
    done
    
    echo ""
    echo -e "${YELLOW}Использование:${NC}"
    echo "  nextdeploy <проект> <команда>"
    echo ""
    echo "Пример:"
    echo "  nextdeploy my-app deploy"
}

# Удаление проекта
remove_project() {
    local project_name="$1"
    
    if [ -z "$project_name" ]; then
        echo -e "${RED}❌ Укажите название проекта${NC}"
        echo "Использование: nextdeploy remove <project-name>"
        return 1
    fi
    
    if [ ! -f "$PROJECTS_DIR/$project_name.conf" ]; then
        echo -e "${RED}❌ Проект '$project_name' не найден${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}⚠️  Вы уверены, что хотите удалить проект '$project_name'?${NC}"
    read -p "Введите 'yes' для подтверждения: " CONFIRM
    
    if [ "$CONFIRM" == "yes" ]; then
        rm "$PROJECTS_DIR/$project_name.conf"
        echo -e "${GREEN}✅ Проект '$project_name' удален${NC}"
    else
        echo -e "${YELLOW}Удаление отменено${NC}"
    fi
}