#!/bin/bash

init(){
    local packages=("bind" "bind-utils")
    local missing_packages=()
    
    for package in "${packages[@]}"; do
        if ! rpm -q "$package" &>/dev/null; then
            missing_packages+=("$package")
        fi
    done
    
    if [ ${#missing_packages[@]} -ne 0 ]; then
        echo "Installing missing packages: ${missing_packages[*]}"
        apt-get install -y "${missing_packages[@]}"
        if [ $? -ne 0 ]; then
            echo "Error installing packages"
            exit 1
        fi
    else
        echo "All required packages are already installed"
    fi
}

import_config()
{
    link="https://raw.githubusercontent.com/u006E10011/alt-linux-scripting/main/bind/"
    local temp_dir="bind_config_temp"
    
    if [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
    fi
    
    mkdir -p "$temp_dir"
    cd "$temp_dir" || { echo "Cannot enter directory $temp_dir"; exit 1; }
    
    curl -O "${link}options.conf"
    curl -O "${link}local.conf"
    curl -O "${link}zone/100.db"
    curl -O "${link}zone/200.db"
    curl -O "${link}zone/10.db"
    curl -O "${link}zone/au-team.irpo"
}

replace_config()
{
    if [ ! -f "options.conf" ]; then
        echo "Error: config files not found. Current directory: $(pwd)"
        exit 1
    fi
    
    cp -f *.conf /var/lib/bind/etc/
    cp -f *.db /var/lib/bind/etc/zone/
    cp -f au-team.irpo /var/lib/bind/etc/zone/ 2>/dev/null || true
    
    if systemctl list-unit-files | grep -q bind.service; then
        systemctl enable --now bind
        sleep 2
        systemctl status bind --no-pager
    else
        echo "Warning: bind service not found"
        echo "You may need to configure bind manually"
    fi
    
    chown -R named:named /var/lib/bind/etc/
    chmod 644 /var/lib/bind/etc/*.conf 
    chmod 644 /var/lib/bind/etc/zone/*.db      
    chmod 644 /var/lib/bind/etc/zone/au-team.irpo    
    chmod 755 /var/lib/bind/etc/
    chmod 755 /var/lib/bind/etc/zone/

    cd ..
    rm -rf "$temp_dir"
}

main()
{
    init
    import_config
    replace_config
    history -c
}

main
