#!/bin/bash

# NextJS Deploy Tool - Главный файл

set -e

# Конфигурация
CONFIG_DIR="$HOME/.nextjs-deploy"
PROJECTS_DIR="$CONFIG_DIR/projects"
LIB_DIR="$CONFIG_DIR/lib"

# Загрузка библиотек
source "$LIB_DIR/colors.sh"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/project.sh"
source "$LIB_DIR/deploy.sh"
source "$LIB_DIR/urls.sh"

# Показать помощь
show_help() {
    echo "NextJS Deploy Tool"
    echo ""
    echo "Управление проектами:"
    echo "  nextdeploy              # список проектов"
    echo "  nextdeploy add          # добавить новый проект"
    echo "  nextdeploy list         # список проектов"
    echo "  nextdeploy remove <name> # удалить проект"
    echo ""
    echo "Работа с проектом:"
    echo "  nextdeploy <project> deploy      # деплой"
    echo "  nextdeploy <project> setup       # настройка сервера"
    echo "  nextdeploy <project> git-setup   # настройка Git"
    echo "  nextdeploy <project> replace-url # замена URL в проекте"
    echo "  nextdeploy <project> logs        # логи"
    echo "  nextdeploy <project> status      # статус"
    echo "  nextdeploy <project> restart     # перезапуск"
    echo "  nextdeploy <project> stop        # остановка"
    echo "  nextdeploy <project> start       # запуск"
    echo "  nextdeploy <project> ssh         # подключение"
    echo "  nextdeploy <project> config      # показать конфиг"
}

# Главная логика
main() {
    # Без аргументов - показать список проектов
    if [ -z "$1" ]; then
        list_projects
        exit 0
    fi

    # Команды без указания проекта
    case "$1" in
        add|new|create)
            create_project
            exit 0
            ;;
        list|ls)
            list_projects
            exit 0
            ;;
        remove|delete|rm)
            remove_project "$2"
            exit 0
            ;;
        help|-h|--help)
            show_help
            exit 0
            ;;
    esac

    # Команды для конкретного проекта
    PROJECT_NAME="$1"
    COMMAND="${2:-deploy}"

    # Проверка существования проекта
    if [ ! -f "$PROJECTS_DIR/$PROJECT_NAME.conf" ]; then
        echo -e "${RED}❌ Проект '$PROJECT_NAME' не найден${NC}"
        echo ""
        echo "Доступные проекты:"
        list_projects
        exit 1
    fi

    # Загрузка конфигурации проекта
    load_project_config "$PROJECT_NAME"

    # Выполнение команды
    case "$COMMAND" in
        setup)
            deploy_setup
            ;;
        git-setup)
            deploy_git_setup
            ;;
        deploy)
            deploy_project
            ;;
        replace-url)
            replace_urls "$PROJECT_NAME"
            ;;
        logs)
            ssh $SERVER_USER@$SERVER_HOST "pm2 logs $APP_NAME"
            ;;
        status)
            ssh $SERVER_USER@$SERVER_HOST "pm2 status $APP_NAME"
            ;;
        restart)
            echo -e "${YELLOW}🔄 Перезапуск '$PROJECT_NAME'...${NC}"
            ssh $SERVER_USER@$SERVER_HOST "pm2 restart $APP_NAME"
            echo -e "${GREEN}✅ Перезапущено!${NC}"
            ;;
        stop)
            echo -e "${YELLOW}⏸️  Остановка '$PROJECT_NAME'...${NC}"
            ssh $SERVER_USER@$SERVER_HOST "pm2 stop $APP_NAME"
            ;;
        start)
            echo -e "${GREEN}▶️  Запуск '$PROJECT_NAME'...${NC}"
            ssh $SERVER_USER@$SERVER_HOST "pm2 start $APP_NAME"
            ;;
        ssh)
            ssh $SERVER_USER@$SERVER_HOST
            ;;
        config)
            show_config "$PROJECT_NAME"
            ;;
        *)
            echo -e "${RED}❌ Неизвестная команда: $COMMAND${NC}"
            echo ""
            echo "Доступные команды:"
            echo "  deploy, setup, git-setup, replace-url, logs, status, restart, stop, start, ssh, config"
            exit 1
            ;;
    esac
}

# Запуск
main "$@"