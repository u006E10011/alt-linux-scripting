#!/bin/bash

HOSTNAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--hostname)
            HOSTNAME="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

init()
{
    local packages=("frr" "sed")
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
    if [ -z "$HOSTNAME" ]; then
        read -p "Enter hostname (hq or br): " HOSTNAME
    fi
    
    local conf="frr version 9.0.2
frr defaults traditional
hostname $HOSTNAME
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

    case $HOSTNAME in
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
            echo "Unknown hostname: $HOSTNAME"
            return 1
            ;;
    esac

    conf="$conf
exit
!"

    sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons
    echo "$conf" > /etc/frr/frr.conf
    echo "$conf" > /etc/frr/frr.conf.sav
    echo "FRR configured for host: $HOSTNAME"
}

main()
{
    init
    setup_config
    history -c
}

main "$@"
