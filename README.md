# ��� Быстрая установка NextJS Deploy Tool

## Установка одной командой:

```bash
$ curl -o install.sh https://raw.githubusercontent.com/abroranvarov01/nextjs-deploy-tool/main/install.sh
```

## Или локальная установка:

### 1. Скачайте install.sh и запустите:

```bash
chmod +x install.sh
./install.sh
```

### 2. Перезагрузите терминал или выполните:

```bash
source ~/.bashrc
```

## ��� Использование:

### Первая настройка (один раз):
```bash
nextdeploy setup
```

### Настройка Git для приватного репозитория (если нужно):
```bash
nextdeploy git-setup
```

### Деплой приложения:
```bash
nextdeploy
```
или
```bash
nextdeploy deploy
```

## ��� Все доступные команды:

```bash
nextdeploy              # Деплой приложения
nextdeploy setup        # Настройка сервера
nextdeploy git-setup    # Настройка Git
nextdeploy logs         # Логи приложения
nextdeploy status       # Статус приложения
nextdeploy restart      # Перезапуск
nextdeploy stop         # Остановка
nextdeploy start        # Запуск
nextdeploy ssh          # Подключение к серверу
nextdeploy config       # Показать конфигурацию
```

## ��� Примеры использования:

```bash
# Быстрый деплой
nextdeploy

# Посмотреть логи
nextdeploy logs

# Перезапустить приложение
nextdeploy restart

# Подключиться к серверу
nextdeploy ssh
```

## ��� Изменить конфигурацию:

```bash
nano ~/.nextjs-deploy/config
```

или запустите установку заново:
```bash
./install.sh
```

## ✅ Преимущества:

- ⚡ **Одна команда** для деплоя: `nextdeploy`
- ��� **Работает из любой папки** - не нужно быть в проекте
- ��� **Сохраняет настройки** - вводите данные только один раз
- ��� **Быстрые команды** для логов, рестарта, статуса
- ��� **SSH подключение** одной командой
