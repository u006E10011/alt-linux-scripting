#!/bin/bash

# Скрипт для настройки пользователей и SSH на ALT Linux 10.4
# Проверяем, выполняется ли скрипт с правами root
if [[ $EUID -ne 0 ]]; then
   echo "Этот скрипт должен быть запущен с правами root" 
   exit 1
fi

# Функция установки sudo
install_sudo() {
    if ! command -v sudo &> /dev/null; then
        echo "Установка sudo..."
        apt-get update
        apt-get install -y sudo
        if [[ $? -ne 0 ]]; then
            echo "Ошибка при установке sudo"
            return 1
        fi
    fi
    
    # Проверяем наличие директории sudoers.d
    if [[ ! -d /etc/sudoers.d ]]; then
        mkdir -p /etc/sudoers.d
    fi
    return 0
}

# Функция для определения типа устройства
detect_device_type() {
    # Проверяем hostname для определения типа устройства
    local hostname=$(hostname | tr '[:upper:]' '[:lower:]')
    
    case $hostname in
        *srv*)
            echo "server"
            ;;
        *rtr*)
            echo "router"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Функция создания пользователя sshuser (для серверов)
setup_sshuser() {
    echo "Настройка пользователя sshuser..."
    
    # Создаем пользователя с указанным UID и добавляем в группу wheel
    useradd -m -u 2026 -s /bin/bash -G wheel sshuser
    if [[ $? -eq 0 ]]; then
        echo "Пользователь sshuser создан и добавлен в группу wheel"
    else
        # Если группа wheel не существует, создаем ее
        groupadd wheel
        useradd -m -u 2026 -s /bin/bash -G wheel sshuser
        if [[ $? -eq 0 ]]; then
            echo "Пользователь sshuser создан и добавлен в группу wheel"
        else
            echo "Ошибка при создании пользователя sshuser"
            return 1
        fi
    fi
    
    # Устанавливаем пароль
    echo "sshuser:P@ssw0rd" | chpasswd
    if [[ $? -eq 0 ]]; then
        echo "Пароль для sshuser установлен"
    else
        echo "Ошибка при установке пароля для sshuser"
        return 1
    fi
    
    # Устанавливаем sudo если нужно
    install_sudo
    
    # Настраиваем sudo без пароля для группы wheel
    if ! grep -q "^%wheel" /etc/sudoers; then
        echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    fi
    
    # Также создаем отдельный файл для надежности
    echo "sshuser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sshuser
    chmod 440 /etc/sudoers.d/sshuser
    
    echo "Настройки sudo для sshuser применены"
}

# Функция создания пользователя net_admin (для маршрутизаторов)
setup_net_admin() {
    echo "Настройка пользователя net_admin..."
    
    # Создаем пользователя и добавляем в группу wheel
    useradd -m -s /bin/bash -G wheel net_admin
    if [[ $? -eq 0 ]]; then
        echo "Пользователь net_admin создан и добавлен в группу wheel"
    else
        # Если группа wheel не существует, создаем ее
        groupadd wheel
        useradd -m -s /bin/bash -G wheel net_admin
        if [[ $? -eq 0 ]]; then
            echo "Пользователь net_admin создан и добавлен в группу wheel"
        else
            echo "Ошибка при создании пользователя net_admin"
            return 1
        fi
    fi
    
    # Устанавливаем пароль
    echo "net_admin:P@ssw0rd" | chpasswd
    if [[ $? -eq 0 ]]; then
        echo "Пароль для net_admin установлен"
    else
        echo "Ошибка при установке пароля для net_admin"
        return 1
    fi
    
    # Устанавливаем sudo если нужно
    install_sudo
    
    # Настраиваем sudo без пароля для группы wheel
    if ! grep -q "^%wheel" /etc/sudoers; then
        echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    fi
    
    # Также создаем отдельный файл для надежности
    echo "net_admin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/net_admin
    chmod 440 /etc/sudoers.d/net_admin
    
    echo "Настройки sudo для net_admin применены"
}

# Функция настройки SSH для серверов
setup_ssh_server() {
    echo "Настройка SSH для сервера..."
    
    # Создаем бэкап оригинального конфига
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null || true
    
    # Настраиваем SSH с баннером
    cat > /etc/ssh/sshd_config << 'EOF'
# Базовые настройки
Port 2026
Protocol 2
PermitRootLogin no
MaxAuthTries 2
ClientAliveInterval 300
ClientAliveCountMax 2

# Аутентификация
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication yes
PermitEmptyPasswords no

# Безопасность
AllowUsers sshuser
Banner /etc/ssh/banner
EOF

    # Создаем баннер только для серверов
    echo "Authorized access only" > /etc/ssh/banner
    chmod 644 /etc/ssh/banner
    echo "Баннер 'Authorized access only' установлен"
    
    # Перезапускаем SSH службу
    if systemctl restart sshd 2>/dev/null; then
        echo "SSH служба перезапущена (sshd)"
    elif systemctl restart ssh 2>/dev/null; then
        echo "SSH служба перезапущена (ssh)"
    else
        echo "Предупреждение: не удалось перезапустить SSH службу автоматически"
        echo "Пожалуйста, перезапустите SSH службу вручную"
    fi
    
    echo "Настройка SSH для сервера завершена"
}

# Функция настройки SSH для маршрутизаторов (без баннера)
setup_ssh_router() {
    echo "Настройка SSH для маршрутизатора..."
    
    # Создаем бэкап оригинального конфига
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null || true
    
    # Настраиваем SSH без баннера
    cat > /etc/ssh/sshd_config << 'EOF'
# Базовые настройки
Port 22
Protocol 2
PermitRootLogin no
MaxAuthTries 2
ClientAliveInterval 300
ClientAliveCountMax 2

# Аутентификация
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication yes
PermitEmptyPasswords no

# Безопасность
AllowUsers net_admin
EOF

    # Удаляем баннер если он существует
    if [[ -f /etc/ssh/banner ]]; then
        rm -f /etc/ssh/banner
        echo "Баннер удален"
    fi
    
    # Перезапускаем SSH службу
    if systemctl restart sshd 2>/dev/null; then
        echo "SSH служба перезапущена (sshd)"
    elif systemctl restart ssh 2>/dev/null; then
        echo "SSH служба перезапущена (ssh)"
    else
        echo "Предупреждение: не удалось перезапустить SSH службу автоматически"
        echo "Пожалуйста, перезапустите SSH службу вручную"
    fi
    
    echo "Настройка SSH для маршрутизатора завершена"
}

# Основная логика скрипта
main() {
    echo "Определение типа устройства..."
    local device_type=$(detect_device_type)
    
    case $device_type in
        "server")
            echo "Обнаружен сервер. Настраиваю sshuser и SSH..."
            setup_sshuser
            setup_ssh_server
            ;;
        "router")
            echo "Обнаружен маршрутизатор. Настраиваю net_admin..."
            setup_net_admin
            setup_ssh_router
            ;;
        "unknown")
            echo "Тип устройства не определен. Запрос у пользователя..."
            read -p "Введите тип устройства (server/router): " user_input
            case $(echo "$user_input" | tr '[:upper:]' '[:lower:]') in
                "server")
                    setup_sshuser
                    setup_ssh_server
                    ;;
                "router")
                    setup_net_admin
                    setup_ssh_router
                    ;;
                *)
                    echo "Неверный тип устройства. Используйте 'server' или 'router'"
                    exit 1
                    ;;
            esac
            ;;
    esac
    
    echo "Настройка завершена!"
    
    # Выводим информацию о настройках
    echo ""
    echo "=== ИТОГИ НАСТРОЙКИ ==="
    if [[ $device_type == "server" ]] || [[ $(echo "$user_input" | tr '[:upper:]' '[:lower:]') == "server" ]]; then
        echo "Сервер настроен:"
        echo "- Пользователь: sshuser (UID: 2026)"
        echo "- Группа: wheel"
        echo "- Пароль: P@ssw0rd"
        echo "- SSH порт: 2026"
        echo "- Sudo без пароля: разрешено"
        echo "- Root login: запрещен"
        echo "- Баннер: 'Authorized access only'"
    elif [[ $device_type == "router" ]] || [[ $(echo "$user_input" | tr '[:upper:]' '[:lower:]') == "router" ]]; then
        echo "Маршрутизатор настроен:"
        echo "- Пользователь: net_admin"
        echo "- Группа: wheel"
        echo "- Пароль: P@ssw0rd" 
        echo "- SSH порт: 22 (стандартный)"
        echo "- Sudo без пароля: разрешено"
        echo "- Баннер: отсутствует"
    fi
    echo "======================"
}

# Запуск основной функции
main
