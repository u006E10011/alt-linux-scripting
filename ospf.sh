#!/bin/bash

init()
{
    local packages=("frr")
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

setup_config()
{
    read -p "Enter hostname (hq or br): " hostname
    
    local conf="frr version 9.0.2
frr defaults traditional
hostname $hostname
log file /var/log/frr/frr.log
no ipv6 forwarding
!
interface enp7s2
 no ip ospf passive
exit
!
interface gre1
 ip ospf authentication
 ip ospf authentication-key P@ssw0rd
 no ip ospf passive
exit
!
router ospf
 log-adjacency-changes
 passive-interface default"

    case $hostname in
        *hq*)
            conf="$conf
 network 10.10.10.0/30 area 0
 network 192.168.100.0/27 area 0
 network 192.168.200.0/28 area 0"
            ;;
        *br*)
            conf="$conf
 network 10.10.10.0/30 area 0
 network 172.20.10.0/28 area 0"
            ;;
        *)
            echo "Unknown hostname: $hostname"
            return 1
            ;;
    esac

    conf="$conf
exit
!"

    sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons
    echo "$conf" > /etc/frr/frr.conf
    echo "$conf" > /etc/frr/frr.conf.sav
}

main()
{
    init
    setup_config
}

main
