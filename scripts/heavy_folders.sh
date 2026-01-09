#!/bin/bash

# Скрипт для детального анализа размера папок

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Параметры по умолчанию
SCAN_PATH="/"
LIMIT=15
SHOW_HIDDEN=false
OUTPUT_FILE=""
EXCLUDE_PATHS="/proc /sys /run /dev"

# Функция помощи
show_help() {
    echo "Использование: $0 [опции]"
    echo ""
    echo "Опции:"
    echo "  -p PATH    Путь для сканирования (по умолчанию: /)"
    echo "  -n NUM     Количество выводимых папок (по умолчанию: 15)"
    echo "  -h         Показать эту справку"
    echo "  -a         Показать скрытые папки"
    echo "  -o FILE    Сохранить результат в файл"
    echo "  -e         Исключить системные пути (/proc, /sys, /run, /dev)"
    echo ""
    echo "Примеры:"
    echo "  $0 -p /home -n 10"
    echo "  $0 -p /var -a -o report.txt"
}

# Обработка аргументов
while getopts "p:n:hao:e" opt; do
    case $opt in
        p) SCAN_PATH="$OPTARG" ;;
        n) LIMIT="$OPTARG" ;;
        h) show_help; exit 0 ;;
        a) SHOW_HIDDEN=true ;;
        o) OUTPUT_FILE="$OPTARG" ;;
        e) EXCLUDE_PATHS="$SCAN_PATH/proc $SCAN_PATH/sys $SCAN_PATH/run $SCAN_PATH/dev" ;;
        *) show_help; exit 1 ;;
    esac
done

# Проверка существования пути
if [ ! -d "$SCAN_PATH" ]; then
    echo -e "${RED}Ошибка: Путь '$SCAN_PATH' не существует${NC}"
    exit 1
fi

echo -e "${GREEN}=== Анализ использования диска ===${NC}"
echo "Путь сканирования: $SCAN_PATH"
echo "Выводим топ $LIMIT папок"
echo "Дата: $(date)"
echo ""

# Проверка доступного места
echo -e "${YELLOW}Общая информация о диске:${NC}"
df -h "$SCAN_PATH" | head -2
echo ""

# Создание команды для du
DU_CMD="du -h --max-depth=1"

# Добавление исключений
if [ ! -z "$EXCLUDE_PATHS" ]; then
    for exclude in $EXCLUDE_PATHS; do
        if [ -d "$exclude" ]; then
            DU_CMD="$DU_CMD --exclude=\"$exclude\""
        fi
    done
fi

# Добавление пути сканирования
DU_CMD="$DU_CMD \"$SCAN_PATH\" 2>/dev/null"

# Выполнение команды и сортировка
if [ -n "$OUTPUT_FILE" ]; then
    echo -e "${YELLOW}Результаты сохраняются в: $OUTPUT_FILE${NC}"
    echo "=== Результаты анализа диска ===" > "$OUTPUT_FILE"
    echo "Путь: $SCAN_PATH" >> "$OUTPUT_FILE"
    echo "Дата: $(date)" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    eval $DU_CMD | sort -hr | head -n $((LIMIT + 1)) | tee -a "$OUTPUT_FILE"
else
    echo -e "${YELLOW}Топ $LIMIT самых больших папок:${NC}"
    eval $DU_CMD | sort -hr | head -n $((LIMIT + 1))
fi

# Дополнительная информация о домашних директориях (если сканируем корень)
if [ "$SCAN_PATH" = "/" ]; then
    echo ""
    echo -e "${YELLOW}Размер домашних директорий:${NC}"
    if [ -d "/home" ]; then
        du -h /home --max-depth=1 2>/dev/null | sort -hr | head -10
    fi
fi

echo ""
echo -e "${GREEN}Анализ завершен!${NC}"