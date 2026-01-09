#!/bin/bash

# Скрипт для проверки Nginx и его конфигураций
# nginx_check.sh

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Функция для вывода секции
print_section() {
    echo ""
    echo -e "${YELLOW}=== $1 ===${NC}"
    echo ""
}

# Функция для проверки наличия команды
command_exists() {
    command -v "$1" &> /dev/null
}

# Функция для поиска конфигурационной директории nginx
find_nginx_config_dir() {
    local config_dir=""
    
    # Проверяем стандартные пути
    local nginx_paths=(
        "/etc/nginx"
        "/usr/local/nginx/conf"
        "/opt/nginx/conf"
        "/usr/local/etc/nginx"
    )
    
    for path in "${nginx_paths[@]}"; do
        if [ -d "$path" ]; then
            config_dir="$path"
            echo -e "${CYAN}Найдена конфигурационная директория: $config_dir${NC}"
            break
        fi
    done
    
    # Если не нашли, пытаемся найти через nginx -t
    if [ -z "$config_dir" ]; then
        if command_exists nginx; then
            echo "Поиск конфигурации через nginx -t..."
            nginx_output=$(nginx -t 2>&1)
            config_file=$(echo "$nginx_output" | grep -oP "configuration file \K[^ ]+" | head -1)
            
            if [ -n "$config_file" ] && [ -f "$config_file" ]; then
                config_dir=$(dirname "$config_file")
                echo -e "${CYAN}Определена директория из конфига: $config_dir${NC}"
            fi
        fi
    fi
    
    echo "$config_dir"
}

# Основная функция проверки Nginx
check_nginx() {
    print_section "ПРОВЕРКА NGINX"
    
    # Проверяем установлен ли nginx
    if command_exists nginx; then
        echo -e "${GREEN}✓ Nginx установлен${NC}"
        
        # Версия nginx
        echo -n "Версия: "
        nginx -v 2>&1 | sed 's/nginx version: //'
        
        # Статус службы
        print_section "СТАТУС СЛУЖБЫ"
        if systemctl is-active nginx &> /dev/null; then
            echo -e "${GREEN}● Служба запущена${NC}"
            systemctl status nginx --no-pager | grep -A 2 "Loaded\|Active"
        elif systemctl is-enabled nginx &> /dev/null; then
            echo -e "${YELLOW}○ Служба остановлена, но включена в автозагрузку${NC}"
        else
            echo "Служба не управляется systemctl"
        fi
        
        # Проверка конфигурации
        print_section "ПРОВЕРКА КОНФИГУРАЦИИ"
        echo "Проверка синтаксиса конфигурации:"
        nginx -t 2>&1
        
        # Поиск конфигурационной директории
        local config_dir=$(find_nginx_config_dir)
        
        if [ -n "$config_dir" ]; then
            # Доступные конфигурации (sites-available)
            if [ -d "$config_dir/sites-available" ]; then
                print_section "ДОСТУПНЫЕ КОНФИГУРАЦИИ (sites-available)"
                local available_count=$(ls -1 "$config_dir/sites-available/" 2>/dev/null | wc -l)
                echo "Количество конфигураций: $available_count"
                
                if [ "$available_count" -gt 0 ]; then
                    echo ""
                    echo "Список конфигураций:"
                    ls -la "$config_dir/sites-available/" | tail -n +4
                    
                    # Показываем содержимое каждой конфигурации (первые строки)
                    echo ""
                    echo "Краткое содержимое конфигураций:"
                    for conf in $(ls "$config_dir/sites-available/" 2>/dev/null); do
                        conf_file="$config_dir/sites-available/$conf"
                        if [ -f "$conf_file" ]; then
                            echo -e "${CYAN}--- $conf ---${NC}"
                            # Выводим основные настройки
                            grep -E "^server|listen\s+|server_name|root\s+|index\s+" "$conf_file" 2>/dev/null | head -3
                            echo ""
                        fi
                    done
                fi
            else
                echo -e "${YELLOW}Директория sites-available не найдена${NC}"
            fi
            
            # Активные конфигурации (sites-enabled)
            if [ -d "$config_dir/sites-enabled" ]; then
                print_section "АКТИВНЫЕ КОНФИГУРАЦИИ (sites-enabled)"
                local enabled_count=$(ls -1 "$config_dir/sites-enabled/" 2>/dev/null | wc -l)
                echo "Количество активных конфигураций: $enabled_count"
                
                if [ "$enabled_count" -gt 0 ]; then
                    echo ""
                    echo "Список активных конфигураций:"
                    ls -la "$config_dir/sites-enabled/" | tail -n +4
                    
                    # Показываем симлинки
                    echo ""
                    echo "Симлинки:"
                    for enabled_conf in $(ls -l "$config_dir/sites-enabled/" 2>/dev/null | grep "->" | awk '{print $9}'); do
                        target=$(readlink -f "$config_dir/sites-enabled/$enabled_conf")
                        echo -e "${GREEN}$enabled_conf -> $target${NC}"
                    done
                fi
            else
                echo -e "${YELLOW}Директория sites-enabled не найдена${NC}"
            fi
            
            # Основной конфиг nginx.conf
            if [ -f "$config_dir/nginx.conf" ]; then
                print_section "ОСНОВНОЙ КОНФИГ (nginx.conf)"
                echo "Основные параметры:"
                grep -E "^worker_processes|^worker_connections|^http\s*{|^events\s*{|^include\s+" "$config_dir/nginx.conf" 2>/dev/null | head -10
            fi
        fi
        
        # Процессы nginx
        print_section "ПРОЦЕССЫ NGINX"
        local nginx_processes=$(ps aux | grep -E "nginx:\s+(master|worker)" | grep -v grep)
        if [ -n "$nginx_processes" ]; then
            echo "Запущенные процессы:"
            echo "$nginx_processes" | while read line; do
                user=$(echo "$line" | awk '{print $1}')
                pid=$(echo "$line" | awk '{print $2}')
                command=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf $i" "; print ""}')
                echo -e "  ${GREEN}PID $pid${NC} ($user): $command"
            done
        else
            echo -e "${YELLOW}Процессы Nginx не найдены${NC}"
        fi
        
        # Открытые порты
        print_section "ОТКРЫТЫЕ ПОРТЫ NGINX"
        if command_exists ss; then
            ss -tulpn | grep nginx || echo "Порты Nginx не найдены (через ss)"
        elif command_exists netstat; then
            netstat -tulpn | grep nginx || echo "Порты Nginx не найдены (через netstat)"
        else
            echo "Утилиты для проверки портов не найдены"
        fi
        
        # Логи nginx (если доступны)
        print_section "ЛОГИ NGINX"
        local log_paths=(
            "/var/log/nginx"
            "/usr/local/nginx/logs"
            "/opt/nginx/logs"
        )
        
        for log_path in "${log_paths[@]}"; do
            if [ -d "$log_path" ]; then
                echo "Логи в: $log_path"
                ls -la "$log_path/" 2>/dev/null | head -10
                break
            fi
        done
        
    else
        echo -e "${RED}✗ Nginx не установлен${NC}"
        
        # Проверка альтернативных методов установки
        print_section "ПОИСК АЛЬТЕРНАТИВНЫХ УСТАНОВОК"
        
        # Snap
        if command_exists snap; then
            if snap list | grep -q nginx; then
                echo -e "${GREEN}✓ Nginx найден в Snap${NC}"
                snap list | grep nginx
            fi
        fi
        
        # Docker
        if command_exists docker; then
            echo "Поиск контейнеров Nginx:"
            docker ps --filter "name=nginx" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null
            if [ $? -ne 0 ]; then
                echo "Контейнеры Nginx не найдены"
            fi
        fi
        
        # Проверка установленных пакетов
        print_section "ПРОВЕРКА ПАКЕТОВ"
        if command_exists dpkg; then
            dpkg -l | grep -i nginx || echo "Пакеты nginx не найдены (dpkg)"
        elif command_exists rpm; then
            rpm -qa | grep -i nginx || echo "Пакеты nginx не найдены (rpm)"
        elif command_exists pacman; then
            pacman -Q | grep -i nginx || echo "Пакеты nginx не найдены (pacman)"
        fi
    fi
}

# Запуск проверки
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}        ПРОВЕРКА NGINX                  ${NC}"
echo -e "${BLUE}==========================================${NC}"

check_nginx

echo ""
echo -e "${BLUE}==========================================${NC}"
echo -e "${GREEN}Проверка завершена!${NC}"
echo -e "${BLUE}==========================================${NC}"