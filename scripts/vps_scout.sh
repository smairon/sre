#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Заголовок
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}    СБОР ИНФОРМАЦИИ О СИСТЕМЕ            ${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Функция для вывода секции
print_section() {
    echo ""
    echo -e "${YELLOW}=== $1 ===${NC}"
    echo ""
}

# 1. Общая информация о системе
print_section "ОБЩАЯ ИНФОРМАЦИЯ"
echo -n "Хост: "
hostname
echo -n "Пользователь: "
whoami
echo -n "Дата и время: "
date
echo -n "Время работы: "
uptime -p
echo -n "Полное время работы: "
uptime

# 2. Информация о RAM
print_section "ПАМЯТЬ (RAM)"
free -h

# 3. Информация о CPU
print_section "ПРОЦЕССОР (CPU)"
echo -n "Модель процессора: "
lscpu | grep "Model name" | sed 's/^.*:\s*//'
echo -n "Количество ядер: "
nproc
echo -n "Архитектура: "
arch

# 4. Текущая нагрузка
print_section "ТЕКУЩАЯ НАГРУЗКА"
echo "Load average:"
cat /proc/loadavg
echo ""
echo "Использование CPU по ядрам:"
mpstat -P ALL 1 1 | tail -n +4

# 5. Дисковое пространство
print_section "ДИСКОВОЕ ПРОСТРАНСТВО"
df -h

# 6. Топ процессов
print_section "ТОП-10 ПРОЦЕССОВ ПО ПАМЯТИ"
ps aux --sort=-%mem | head -11

print_section "ТОП-10 ПРОЦЕССОВ ПО CPU"
ps aux --sort=-%cpu | head -11

# 7. Проверка Docker
print_section "ПРОВЕРКА DOCKER"
if command -v docker &> /dev/null; then
    echo -e "${GREEN}Docker установлен ✓${NC}"
    echo -n "Версия Docker: "
    docker --version
    echo ""
    echo "Состояние Docker:"
    systemctl is-active docker 2>/dev/null || echo "Сервис не управляется systemctl"
    echo ""
    echo "Запущенные контейнеры:"
    docker ps 2>/dev/null || echo "Не удалось получить список контейнеров"
else
    echo -e "${RED}Docker не установлен ✗${NC}"
fi

# 8. Открытые порты
print_section "ОТКРЫТЫЕ ПОРТЫ"
echo "Порты, прослушиваемые локально:"
ss -tulpn 2>/dev/null | head -20
if [ $? -ne 0 ]; then
    netstat -tulpn 2>/dev/null | head -20 || echo "Не удалось получить информацию о портах"
fi

# 9. Сетевые интерфейсы
print_section "СЕТЕВЫЕ ИНТЕРФЕЙСЫ"
ip addr show | grep -E "inet|^[0-9]+:" | head -20

# 10. Информация о версии ОС
print_section "ИНФОРМАЦИЯ ОБ ОС"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "Дистрибутив: $PRETTY_NAME"
    echo "Версия: $VERSION_ID"
fi
echo -n "Ядро: "
uname -r

# 11. Температура (если доступно)
print_section "ТЕМПЕРАТУРА (ЕСЛИ ДОСТУПНО)"
if command -v sensors &> /dev/null; then
    sensors 2>/dev/null | head -10
elif [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    temp=$(cat /sys/class/thermal/thermal_zone0/temp)
    echo "CPU Температура: $((temp/1000))°C"
else
    echo "Информация о температуре недоступна"
fi

# 12. Логи (последние ошибки)
print_section "ПОСЛЕДНИЕ ОШИБКИ В ЛОГАХ"
if [ -f /var/log/syslog ]; then
    grep -i error /var/log/syslog | tail -5
elif [ -f /var/log/messages ]; then
    grep -i error /var/log/messages | tail -5
else
    echo "Логи не найдены"
fi

echo ""
echo -e "${BLUE}==========================================${NC}"
echo -e "${GREEN}Сбор информации завершен!${NC}"
echo -e "${BLUE}==========================================${NC}"