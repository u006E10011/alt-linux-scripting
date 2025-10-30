#!/bin/bash

auto="true"

init(){
    read -p "is auto [true]: " input
    auto=${input:-true}
    
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

    mkdir config
    cd config
    curl -O "$link"+"options.conf"
    curl -O "$link"+"local.conf"
    curl -O "$link"+"zone/100.db"
    curl -O "$link"+"zone/200.db"
    curl -O "$link"+"zone/10.db"
    curl -O "$link"+"zone/au-team.irpo"
}

replace_confing()
{
    cd config
    rm -rf /var/lib/bind/etc/options.conf /var/lib/bind/etc/local.conf
    mv *.conf /var/lib/bind/etc/
    mv *.db /var/lib/bind/etc/zone/
    mv au-team.irpo /var/lib/bind/etc/zone/

    systemctl enable --now bind
    systemctl status bind
}

main()
{
    init
    import_config
    replace_confing
}

main
