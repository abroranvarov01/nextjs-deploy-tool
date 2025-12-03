#!/bin/bash

# Установка NextJS Deploy Tool

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 Установка NextJS Deploy Tool${NC}"
echo ""

# Определение директорий
CONFIG_DIR="$HOME/.nextjs-deploy"
PROJECTS_DIR="$CONFIG_DIR/projects"
LIB_DIR="$CONFIG_DIR/lib"
INSTALL_DIR="$HOME/.local/bin"

# Создание структуры директорий
mkdir -p "$PROJECTS_DIR"
mkdir -p "$LIB_DIR"
mkdir -p "$INSTALL_DIR"

# Копирование библиотек
echo "📦 Копирование библиотек..."
cp lib/*.sh "$LIB_DIR/"
chmod +x "$LIB_DIR"/*.sh

# Создание главного исполняемого файла
echo "🔨 Создание команды nextdeploy..."
cp bin/nextdeploy "$INSTALL_DIR/nextdeploy"
chmod +x "$INSTALL_DIR/nextdeploy"

# Обновление путей в nextdeploy
sed -i "s|LIB_DIR=\".*\"|LIB_DIR=\"$LIB_DIR\"|g" "$INSTALL_DIR/nextdeploy"

echo -e "${GREEN}✅ Команда nextdeploy создана${NC}"

# Добавление в PATH
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
echo -e "${YELLOW}Начните работу:${NC}"
echo "  nextdeploy add                # добавить новый проект"
echo "  nextdeploy                    # список проектов"
echo "  nextdeploy my-app deploy      # деплой проекта"
echo ""