#!/bin/bash

# Функции для замены URL в проектах

# Простая замена одного URL
replace_single_url() {
    local old_url="$1"
    local new_url="$2"
    
    echo ""
    echo -e "${YELLOW}Будет выполнена ТОЧНАЯ замена:${NC}"
    echo "  Старый URL: $old_url"
    echo "  Новый URL: $new_url"
    echo ""
    
    read -p "Продолжить? (y/n): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Замена отменена${NC}"
        return 1
    fi
    
    echo -e "${GREEN}🔍 Поиск и замена URL на сервере...${NC}"
    
    # Кодируем URL в base64 для безопасной передачи
    local old_url_b64=$(echo -n "$old_url" | base64 | tr -d '\n')
    local new_url_b64=$(echo -n "$new_url" | base64 | tr -d '\n')
    
    ssh $SERVER_USER@$SERVER_HOST "bash -s" -- "$SERVER_PATH" "$APP_NAME" "$old_url_b64" "$new_url_b64" <<'ENDSSH'
set -e

SERVER_PATH="$1"
APP_NAME="$2"
OLD_URL_B64="$3"
NEW_URL_B64="$4"

# Декодируем URL
OLD_URL=$(echo "$OLD_URL_B64" | base64 -d)
NEW_URL=$(echo "$NEW_URL_B64" | base64 -d)

cd "$SERVER_PATH"

echo "🔍 Поиск файлов с точным совпадением URL..."

# Поиск файлов
FILES_WITH_OLD_URL=$(grep -rlF "$OLD_URL" . \
    --exclude-dir=node_modules \
    --exclude-dir=.next \
    --exclude-dir=.git \
    --exclude-dir=.npm \
    --exclude-dir=dist \
    --exclude-dir=build \
    --exclude="*.log" \
    --exclude="package-lock.json" \
    --exclude="yarn.lock" \
    2>/dev/null || true)

if [ -z "$FILES_WITH_OLD_URL" ]; then
    echo "ℹ️  URL не найден в проекте"
    exit 0
fi

echo "📋 Найдены файлы:"
echo "$FILES_WITH_OLD_URL"
echo ""

TOTAL_COUNT=$(echo "$FILES_WITH_OLD_URL" | wc -l)
echo "📊 Всего файлов для замены: $TOTAL_COUNT"
echo ""

echo "🔄 Выполняется ТОЧНАЯ замена..."
REPLACED_COUNT=0

for file in $FILES_WITH_OLD_URL; do
    if [ -f "$file" ]; then
        # Точная замена с помощью awk
        awk -v old="$OLD_URL" -v new="$NEW_URL" '
        {
            result = $0
            while (index(result, old) > 0) {
                pos = index(result, old)
                result = substr(result, 1, pos-1) new substr(result, pos+length(old))
            }
            print result
        }' "$file" > "$file.tmp"
        
        # Проверяем замену
        if grep -qF "$NEW_URL" "$file.tmp"; then
            mv "$file.tmp" "$file"
            echo "✅ Обновлен: $file"
            REPLACED_COUNT=$((REPLACED_COUNT + 1))
        else
            rm "$file.tmp"
            echo "⚠️  Не изменен: $file"
        fi
    fi
done

echo ""
echo "✅ Замена завершена!"
echo "📊 Успешно обновлено файлов: $REPLACED_COUNT из $TOTAL_COUNT"

# Пересборка и перезапуск
echo ""
echo "📦 Установка зависимостей..."
npm install --force

echo ""
echo "🔨 Сборка проекта..."
npm run build

echo ""
echo "🔄 Перезапуск PM2..."
pm2 restart "$APP_NAME"

echo ""
echo "✅ Все готово!"
pm2 status "$APP_NAME"
ENDSSH
}

# Массовая замена URL
replace_multiple_urls() {
    local -n old_urls_ref=$1
    local -n new_urls_ref=$2
    
    echo ""
    echo -e "${YELLOW}Будет выполнена ТОЧНАЯ замена ${#old_urls_ref[@]} URL:${NC}"
    for i in "${!old_urls_ref[@]}"; do
        echo -e "${BLUE}[$((i+1))]${NC}"
        echo "  Старый: ${old_urls_ref[$i]}"
        echo "  Новый:  ${new_urls_ref[$i]}"
        echo ""
    done
    
    read -p "Продолжить? (y/n): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Замена отменена${NC}"
        return 1
    fi
    
    echo -e "${GREEN}🔍 Массовая замена URL на сервере...${NC}"
    
    # Создаем данные для замены в формате base64
    local replacements_data=""
    for i in "${!old_urls_ref[@]}"; do
        local old_b64=$(echo -n "${old_urls_ref[$i]}" | base64 | tr -d '\n')
        local new_b64=$(echo -n "${new_urls_ref[$i]}" | base64 | tr -d '\n')
        replacements_data+="${old_b64}|||${new_b64}"$'\n'
    done
    
    # Отправляем на сервер
    ssh $SERVER_USER@$SERVER_HOST "bash -s" -- "$SERVER_PATH" "$APP_NAME" <<ENDSSH
set -e

SERVER_PATH="\$1"
APP_NAME="\$2"

cd "\$SERVER_PATH"

# Создаем временный файл с парами замен
cat > /tmp/url_replacements.txt <<'REPLACEMENTS_EOF'
$replacements_data
REPLACEMENTS_EOF

echo "🔍 Начинаем массовую замену..."
echo ""

TOTAL_REPLACED=0
TOTAL_PAIRS=0

# Читаем пары URL
while IFS='|||' read -r OLD_URL_B64 NEW_URL_B64; do
    if [ -z "\$OLD_URL_B64" ] || [ -z "\$NEW_URL_B64" ]; then
        continue
    fi
    
    # Декодируем
    OLD_URL=\$(echo "\$OLD_URL_B64" | base64 -d)
    NEW_URL=\$(echo "\$NEW_URL_B64" | base64 -d)
    
    TOTAL_PAIRS=\$((TOTAL_PAIRS + 1))
    
    echo "[\$TOTAL_PAIRS] 🔍 Поиск: \${OLD_URL:0:60}..."
    
    # Поиск файлов
    FILES_WITH_OLD_URL=\$(grep -rlF "\$OLD_URL" . \
        --exclude-dir=node_modules \
        --exclude-dir=.next \
        --exclude-dir=.git \
        --exclude-dir=.npm \
        --exclude-dir=dist \
        --exclude-dir=build \
        --exclude="*.log" \
        --exclude="package-lock.json" \
        --exclude="yarn.lock" \
        2>/dev/null || true)
    
    if [ -z "\$FILES_WITH_OLD_URL" ]; then
        echo "    ⚠️  Не найден"
        echo ""
        continue
    fi
    
    FILE_COUNT=\$(echo "\$FILES_WITH_OLD_URL" | wc -l)
    echo "    ✅ Найден в \$FILE_COUNT файле(ах)"
    
    PAIR_REPLACED=0
    for file in \$FILES_WITH_OLD_URL; do
        if [ -f "\$file" ]; then
            # Точная замена
            awk -v old="\$OLD_URL" -v new="\$NEW_URL" '
            {
                result = \$0
                while (index(result, old) > 0) {
                    pos = index(result, old)
                    result = substr(result, 1, pos-1) new substr(result, pos+length(old))
                }
                print result
            }' "\$file" > "\$file.tmp"
            
            if grep -qF "\$NEW_URL" "\$file.tmp"; then
                mv "\$file.tmp" "\$file"
                echo "      ✓ \$file"
                PAIR_REPLACED=\$((PAIR_REPLACED + 1))
                TOTAL_REPLACED=\$((TOTAL_REPLACED + 1))
            else
                rm "\$file.tmp"
            fi
        fi
    done
    
    echo "    📊 Обновлено: \$PAIR_REPLACED файл(ов)"
    echo ""
done < /tmp/url_replacements.txt

rm -f /tmp/url_replacements.txt

echo "✅ Замена завершена!"
echo "📊 Всего пар URL: \$TOTAL_PAIRS"
echo "📊 Всего обновлено файлов: \$TOTAL_REPLACED"

echo ""
echo "📦 Установка зависимостей..."
npm install --force

echo ""
echo "🔨 Сборка проекта..."
npm run build

echo ""
echo "🔄 Перезапуск PM2..."
pm2 restart "\$APP_NAME"

echo ""
echo "✅ Все готово!"
pm2 status "\$APP_NAME"
ENDSSH
}

# Главная функция замены URL
replace_urls() {
    local proj_name="$1"
    
    if [ -z "$proj_name" ]; then
        echo -e "${RED}❌ Укажите название проекта${NC}"
        echo "Использование: nextdeploy <project> replace-url"
        return 1
    fi
    
    # Загружаем конфигурацию
    if [ ! -f "$PROJECTS_DIR/$proj_name.conf" ]; then
        echo -e "${RED}❌ Проект '$proj_name' не найден${NC}"
        return 1
    fi
    
    source "$PROJECTS_DIR/$proj_name.conf"
    
    echo -e "${BLUE}🔄 Замена URL в проекте '$PROJECT_NAME'${NC}"
    echo ""
    echo -e "${YELLOW}Выберите режим замены:${NC}"
    echo "1) Простая замена (один старый URL → один новый URL)"
    echo "2) Массовая замена (список старых URL → список новых URL)"
    echo ""
    read -p "Введите 1 или 2: " REPLACE_MODE
    
    if [[ "$REPLACE_MODE" == "1" ]]; then
        # Простая замена
        read -p "Старый URL: " OLD_URL
        read -p "Новый URL: " NEW_URL
        
        replace_single_url "$OLD_URL" "$NEW_URL"
        
    elif [[ "$REPLACE_MODE" == "2" ]]; then
        # Массовая замена
        echo ""
        echo -e "${YELLOW}Введите старые URL (каждый с новой строки, пустая строка для завершения):${NC}"
        OLD_URLS=()
        while IFS= read -r line; do
            [[ -z "$line" ]] && break
            OLD_URLS+=("$line")
        done
        
        echo ""
        echo -e "${YELLOW}Введите новые URL (в том же порядке, каждый с новой строки):${NC}"
        NEW_URLS=()
        while IFS= read -r line; do
            [[ -z "$line" ]] && break
            NEW_URLS+=("$line")
        done
        
        # Проверки
        if [ ${#OLD_URLS[@]} -ne ${#NEW_URLS[@]} ]; then
            echo -e "${RED}❌ Количество старых и новых URL не совпадает!${NC}"
            echo "Старых URL: ${#OLD_URLS[@]}"
            echo "Новых URL: ${#NEW_URLS[@]}"
            return 1
        fi
        
        if [ ${#OLD_URLS[@]} -eq 0 ]; then
            echo -e "${RED}❌ Не введено ни одного URL!${NC}"
            return 1
        fi
        
        replace_multiple_urls OLD_URLS NEW_URLS
        
    else
        echo -e "${RED}❌ Неверный выбор${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${GREEN}✅ Замена URL завершена и проект перезапущен!${NC}"
}